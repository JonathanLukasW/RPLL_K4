import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart'; 
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Import Models
import '../../../models/route_model.dart';
import '../../../models/school_model.dart';

class RouteService {
  final _supabase = Supabase.instance.client;

  // ===========================================================================
  // BAGIAN 1: LOGIKA PEMBUATAN & PERHITUNGAN RUTE (CORE LOGIC)
  // ===========================================================================

  // --- 1. CREATE BATCH RUTE (MULTI MOBIL) ---
  Future<void> createBatchRoutes({
    required List<String> vehicleIds,
    required String courierId, // FALLBACK Kurir ID
    required List<String> menuIds, 
    required DateTime date,
    required List<School> selectedSchools,
    required int cookingDuration, // Durasi terlama (Bottleneck)
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      // A. LOGIKA UTAMA
      if (vehicleIds.isEmpty || menuIds.isEmpty) return;

      // Mengambil data courier_profile_id dari vehicle yang dipilih
      final vehiclesData = await _supabase
          .from('vehicles')
          .select('id, courier_profile_id')
          .filter('id', 'in', vehicleIds); 

      final Map<String, String?> vehicleCourierMap = {
        for (var v in vehiclesData) v['id']: v['courier_profile_id']
      };

      int schoolsPerVehicle = (selectedSchools.length / vehicleIds.length).ceil();

      for (int i = 0; i < vehicleIds.length; i++) {
        // Ambil potongan list sekolah untuk mobil ke-i
        int start = i * schoolsPerVehicle;
        int end = (start + schoolsPerVehicle < selectedSchools.length) ? start + schoolsPerVehicle : selectedSchools.length;
        
        if (start >= selectedSchools.length) break; 
        
        List<School> assignedSchools = selectedSchools.sublist(start, end);
        String currentVehicleId = vehicleIds[i];

        final String finalCourierId = vehicleCourierMap[currentVehicleId] ?? courierId;

        // B. HITUNG & INSERT RUTE TUNGGAL
        await _createSingleRouteCalculation(
          sppgId: mySppgId,
          vehicleId: currentVehicleId,
          courierId: finalCourierId, 
          menuIds: menuIds, 
          date: date,
          schools: assignedSchools,
          cookingDuration: cookingDuration
        );
      }
    } catch (e) {
      throw Exception("Gagal bagi rute: $e");
    }
  }

  // --- 2. HITUNG MUNDUR & INSERT KE DB (PRIVATE HELPER) ---
  Future<void> _createSingleRouteCalculation({
    required String sppgId,
    required String vehicleId,
    required String courierId,
    required List<String> menuIds, 
    required DateTime date,
    required List<School> schools,
    required int cookingDuration,
  }) async {
    // A. Ambil Lokasi Dapur (Titik Awal)
    final origin = await getSppgLocation();
    if (origin == null) throw Exception("Lokasi Dapur belum diset! Edit SPPG dulu.");

    // B. Susun Koordinat untuk Request OSRM
    String coordString = "${origin.longitude},${origin.latitude}";
    for (var s in schools) {
      if (s.latitude == null || s.longitude == null) throw Exception("Sekolah ${s.name} belum punya lokasi GPS!");
      coordString += ";${s.longitude},${s.latitude}";
    }

    // C. Panggil OSRM untuk dapatkan Durasi Per Segmen (Legs)
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordString?overview=false');
    final response = await http.get(url);
    
    if (response.statusCode != 200) throw Exception("Gagal hitung durasi jalan (OSRM Error).");
    
    final data = jsonDecode(response.body);
    
    // [SAFETY CHECK] Pastikan rute valid
    if (data['code'] != 'Ok' || data['routes'] == null || (data['routes'] as List).isEmpty) {
        throw Exception("OSRM ROUTING FAILED: Tidak dapat menemukan rute yang valid.");
    }
    
    final List<dynamic> legs = data['routes'][0]['legs']; // Segmen perjalanan

    // D. Hitung Total Waktu & Durasi per Segmen
    int totalTravelSeconds = 0;
    List<int> travelSecondsPerLeg = []; 

    for (var leg in legs) {
      int duration = (leg['duration'] as num).toInt(); // Detik
      travelSecondsPerLeg.add(duration);
      totalTravelSeconds += duration + (10 * 60); // Tambah 10 menit (600 detik) service time per titik
    }

    // E. Tentukan Deadline Paling Awal (The Bottle Neck)
    TimeOfDay earliestDeadline = const TimeOfDay(hour: 13, minute: 0); // Default limit siang
    
    for (var s in schools) {
      if (s.deadlineTime != null && s.deadlineTime!.contains(':')) {
        String deadlineString = s.deadlineTime!;
        
        // [PERBAIKAN KRITIS] Bypass string JSON lama dan tangani FormatException
        if (deadlineString.startsWith('{')) {
             // Jika masih menyimpan JSON (Weekly Schedule lama), kita abaikan dan pakai default 12:00
             deadlineString = "12:00:00"; 
        }

        final parts = deadlineString.split(':');
        // Pastikan parts memiliki setidaknya 2 elemen
        if (parts.length >= 2) {
             try {
                final time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                // Cari yang paling pagi
                if (time.hour < earliestDeadline.hour || (time.hour == earliestDeadline.hour && time.minute < earliestDeadline.minute)) {
                  earliestDeadline = time;
                }
            } catch (_) {
                 // Jika gagal parse (karena data kotor/non-angka), gunakan default
            }
        }
      }
    }

    // F. Hitung Mundur Jam Berangkat (Departure Time)
    // Konversi Deadline ke Detik dari jam 00:00
    int deadlineSeconds = earliestDeadline.hour * 3600 + earliestDeadline.minute * 60;
    int departureSeconds = deadlineSeconds - totalTravelSeconds;
    
    // Konversi Detik ke TimeOfDay (Jam Berangkat)
    TimeOfDay departureTime = TimeOfDay(
      hour: departureSeconds ~/ 3600,
      minute: (departureSeconds % 3600) ~/ 60,
    );
    
    // G. Hitung Jam Masak (Start Cooking)
    // Jam Berangkat - Durasi Masak (Bottleneck) - 30 Menit Packing
    int startCookingSeconds = departureSeconds - (cookingDuration * 60) - (30 * 60); 
    if (startCookingSeconds < 0) startCookingSeconds = 0;
    
    TimeOfDay startCookingTime = TimeOfDay(
      hour: startCookingSeconds ~/ 3600,
      minute: (startCookingSeconds % 3600) ~/ 60,
    );

    // Format String untuk DB (HH:mm:ss)
    String fmtDep = "${departureTime.hour.toString().padLeft(2,'0')}:${departureTime.minute.toString().padLeft(2,'0')}:00";
    String fmtCook = "${startCookingTime.hour.toString().padLeft(2,'0')}:${startCookingTime.minute.toString().padLeft(2,'0')}:00";

    // H. INSERT RUTE KE DB
    final routeRes = await _supabase.from('delivery_routes').insert({
      'date': date.toIso8601String().split('T')[0],
      'sppg_id': sppgId,
      'vehicle_id': vehicleId,
      'courier_id': courierId,
      // 'menu_id': menuId, // [DIHAPUS DARI TABEL INI]
      'departure_time': fmtDep, // Hasil Hitungan
      'status': 'pending',
    }).select().single();

    final String newRouteId = routeRes['id'];
    
    // [PERUBAHAN UTAMA] I. INSERT KE route_menus (INSERT BANYAK)
    List<Map<String, dynamic>> routeMenuData = menuIds.map((id) => {
        'route_id': newRouteId,
        'menu_id': id,
    }).toList();
    await _supabase.from('route_menus').insert(routeMenuData);

    // J. INSERT STOPS (DENGAN ESTIMASI WAKTU TIBA / ETA)
    List<Map<String, dynamic>> stopsData = [];
    int currentSeconds = departureSeconds;

    for (int k = 0; k < schools.length; k++) {
      currentSeconds += travelSecondsPerLeg[k]; 
      
      // Konversi ke String ETA
      int h = currentSeconds ~/ 3600;
      int m = (currentSeconds % 3600) ~/ 60;
      String fmtEta = "${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:00";

      stopsData.add({
        'route_id': newRouteId,
        'school_id': schools[k].id,
        'sequence_order': k + 1,
        'estimated_arrival_time': fmtEta, // ETA Real berdasarkan jarak
        'status': 'pending',
      });
      
      currentSeconds += (10 * 60); 
    }

    await _supabase.from('delivery_stops').insert(stopsData);

    // K. AUTO-INSERT JADWAL PRODUKSI
    int totalPortions = schools.fold(0, (sum, item) => sum + item.studentCount);
    // Menggunakan menuIds.first sebagai representasi jadwal produksi
    await _supabase.from('production_schedules').insert({
      'sppg_id': sppgId,
      'date': date.toIso8601String().split('T')[0],
      'menu_id': menuIds.first, // Menggunakan menu pertama sebagai penanda batch
      'total_portions': totalPortions,
      'start_cooking_time': fmtCook, 
      'target_finish_time': fmtDep,
      'notes': 'Auto-Schedule (Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt)',
    });
  }

  // --- 3. UPDATE RUTE (EDIT SEKOLAH) ---
  Future<void> updateRouteSchools(String routeId, List<School> newSchoolList, int cookingDuration) async {
    try {
      // 1. Ambil Data Rute Lama (untuk di-clone)
      final routeData = await _supabase.from('delivery_routes').select().eq('id', routeId).single();
      
      // Ambil SEMUA menuId dari tabel route_menus
      final routeMenus = await _supabase.from('route_menus').select('menu_id').eq('route_id', routeId);
      final List<String> menuIds = routeMenus.map<String>((m) => m['menu_id'] as String).toList();
      
      final DateTime date = DateTime.parse(routeData['date']);
      final String vehicleId = routeData['vehicle_id'];
      final String courierId = routeData['courier_id'];
      final String sppgId = routeData['sppg_id'];

      // 2. Hapus Rute Lama (stops, route_menus, route)
      await _supabase.from('delivery_stops').delete().eq('route_id', routeId);
      await _supabase.from('route_menus').delete().eq('route_id', routeId); // HAPUS MENU LAMA
      await _supabase.from('delivery_routes').delete().eq('id', routeId);
      
      // 3. Buat Ulang Rute dengan Sekolah Baru & Hitung Ulang
      await _createSingleRouteCalculation(
        sppgId: sppgId, 
        vehicleId: vehicleId, 
        courierId: courierId, 
        menuIds: menuIds, // <-- Menggunakan List<String>
        date: date, 
        schools: newSchoolList, 
        cookingDuration: cookingDuration
      );

    } catch (e) {
      throw Exception("Gagal update rute: $e");
    }
  }

  // ===========================================================================
  // BAGIAN 2: FUNGSI GET & READ DATA
  // ===========================================================================

  // --- 4. AMBIL RUTE BULANAN (KALENDER) ---
  Future<List<DeliveryRoute>> getRoutesByMonth(DateTime month) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('role, sppg_id').eq('id', userId).single();
      
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      var query = _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name), route_menus(menu_id, menus(name))')
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String());

      if (profile['role'] == 'kurir') {
        query = query.eq('courier_id', userId);
      } else {
        query = query.eq('sppg_id', profile['sppg_id']);
      }

      final response = await query;
      return (response as List).map((json) => DeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil jadwal: $e");
    }
  }

  // --- 5. AMBIL SEMUA RUTE (LIST HISTORY ADMIN) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name), route_menus(menu_id, menus(name))')
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil rute admin: $e");
    }
  }

  // --- 6. AMBIL RUTE KURIR (LIST) ---
  Future<List<DeliveryRoute>> getRoutesByCourier() async {
    try {
      final currentCourierId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name), route_menus(menu_id, menus(name))')
          .eq('courier_id', currentCourierId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil rute kurir: $e");
    }
  }

  // --- 7. AMBIL DETAIL STOPS (DENGAN KOORDINAT GPS) ---
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId) async {
    try {
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name, address, gps_lat, gps_long, student_count, menu_default, deadline_time)')
          .eq('route_id', routeId)
          .order('sequence_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil detail stop: $e");
    }
  }

  // ===========================================================================
  // BAGIAN 3: UPDATE STATUS & UTILITAS
  // ===========================================================================

  Future<void> updateRouteStatus(String routeId, String newStatus) async {
    try {
      await _supabase.from('delivery_routes').update({'status': newStatus}).eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal update status rute: $e");
    }
  }

  Future<void> updateStopStatus(String stopId, String newStatus) async {
    try {
      await _supabase.from('delivery_stops').update({
        'status': newStatus,
        'arrival_time': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
      }).eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update status stop: $e");
    }
  }

  Future<void> validateLoadWithPhoto(String routeId, String photoUrl) async {
    try {
      await _supabase.from('delivery_routes').update({
        'status': 'active',
        'load_proof_photo_url': photoUrl, 
        'start_time': DateTime.now().toIso8601String(), 
      }).eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal validasi muatan: $e");
    }
  }

  Future<void> completeStopWithPhoto(String stopId, String photoUrl) async {
    try {
      await _supabase.from('delivery_stops').update({
        'status': 'completed',
        'courier_proof_photo_url': photoUrl, 
        'arrival_time': DateTime.now().toIso8601String(),
      }).eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update stop: $e");
    }
  }

  Future<void> deleteRoute(String routeId) async {
    try {
      // [PERBAIKAN] Tambahkan penghapusan route_menus
      await _supabase.from('route_menus').delete().eq('route_id', routeId);
      await _supabase.from('delivery_routes').delete().eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal menghapus rute: $e");
    }
  }

  // --- UTILITAS PETA & LOKASI ---

  Future<List<LatLng>> getRoutePolyline(List<LatLng> coordinates) async {
    if (coordinates.length < 2) return [];

    String coordString = coordinates
        .map((p) => "${p.longitude},${p.latitude}")
        .join(';');

    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] != 'Ok') return [];

        final List<dynamic> coords = data['routes'][0]['geometry']['coordinates'];
        return coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  Future<LatLng?> getSppgLocation() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String sppgId = profile['sppg_id'];

      final sppgData = await _supabase.from('sppgs').select('gps_lat, gps_long').eq('id', sppgId).single();

      if (sppgData['gps_lat'] != null && sppgData['gps_long'] != null) {
        return LatLng(
          double.parse(sppgData['gps_lat'].toString()),
          double.parse(sppgData['gps_long'].toString()),
        );
      }
      return null; 
    } catch (e) {
      return null;
    }
  }
}