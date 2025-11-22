import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart'; 
import 'dart:convert'; // Buat decode JSON dari OSRM
import 'package:http/http.dart' as http; // Buat request ke OSRM
import 'package:latlong2/latlong.dart'; // Buat tipe data LatLng

class RouteService {
  final _supabase = Supabase.instance.client;

  // --- 1. BUAT RUTE BARU (OLEH ADMIN SPPG) ---
  Future<void> createRoute({
    required String vehicleId,
    required String courierId,
    required DateTime date,
    required List<School> selectedSchools,
  }) async {
    try {
      // A. Ambil SPPG ID Admin yang sedang login
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // B. Insert Header (delivery_routes)
      final routeResponse = await _supabase.from('delivery_routes').insert({
        'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
        'sppg_id': mySppgId,
        'vehicle_id': vehicleId,
        'courier_id': courierId,
        'status': 'pending', 
      }).select().single();

      final String newRouteId = routeResponse['id'];

      // C. Siapkan & Insert Detail Perhentian (delivery_stops)
      List<Map<String, dynamic>> stopsData = [];
      
      for (int i = 0; i < selectedSchools.length; i++) {
        stopsData.add({
          'route_id': newRouteId,
          'school_id': selectedSchools[i].id,
          // Urutan saat ini: Masih Manual (Sesuai urutan array)
          // Nanti di sini kita pasang logika VRP
          'sequence_order': i + 1, 
          'status': 'pending',
        });
      }

      await _supabase.from('delivery_stops').insert(stopsData);

    } catch (e) {
      throw Exception("Gagal membuat rute: $e");
    }
  }

  // --- 2. AMBIL DAFTAR RUTE (UNTUK ADMIN SPPG - HISTORY) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      // Ambil SPPG ID Admin
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      // Ambil semua rute milik SPPG ini
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception("Gagal mengambil data rute Admin: $e");
    }
  }

  // --- 3. AMBIL DAFTAR RUTE (UNTUK KURIR YANG SEDANG LOGIN) ---
  Future<List<DeliveryRoute>> getRoutesByCourier() async {
    try {
      // Ambil ID Kurir yang sedang login
      final currentCourierId = _supabase.auth.currentUser!.id;

      // Query filter berdasarkan courier_id
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('courier_id', currentCourierId) 
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception("Gagal mengambil rute kurir: $e");
    }
  }

  // --- 4. AMBIL DETAIL PERHENTIAN (STOPS) UNTUK SUATU RUTE ---
  // Fungsi ini dipakai di halaman Detail Rute Kurir
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId) async {
    try {
      // Ambil data stops DAN join dengan tabel schools untuk dapat nama/alamat
      final response = await _supabase
          .from('delivery_stops')
          // Kita ambil data sekolah terkait (name, address, dll)
          .select('*, schools(name, address, latitude, longitude, student_count, menu_default)')
          .eq('route_id', routeId)
          .order('sequence_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil detail stop: $e");
    }
  }

  // --- 5. UPDATE STATUS RUTE (Start/Finish Route) ---
  Future<void> updateRouteStatus(String routeId, String newStatus) async {
    try {
      await _supabase.from('delivery_routes').update({
        'status': newStatus
      }).eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal update status rute: $e");
    }
  }

  // --- 6. UPDATE STATUS PERHENTIAN (Sekolah Selesai Dikirim) ---
  Future<void> updateStopStatus(String stopId, String newStatus) async {
    try {
      await _supabase.from('delivery_stops').update({
        'status': newStatus,
        // Kalau statusnya 'completed', catat jam sekarang sebagai arrival_time
        'arrival_time': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
      }).eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update status stop: $e");
    }
  }

  // --- 7. AMBIL GARIS RUTE (POLYLINE) DARI OSRM ---
  Future<List<LatLng>> getRoutePolyline(List<LatLng> coordinates) async {
    if (coordinates.length < 2) return []; // Butuh minimal 2 titik buat bikin garis

    // 1. Susun String Koordinat untuk URL OSRM
    // Format: {long},{lat};{long},{lat};...
    String coordString = coordinates
        .map((p) => "${p.longitude},${p.latitude}")
        .join(';');

    // 2. URL OSRM Public (Gratis)
    final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // 3. Ambil geometri (garis) dari JSON
        final List<dynamic> coords = 
            data['routes'][0]['geometry']['coordinates'];

        // 4. Konversi ke List<LatLng> untuk Flutter Map
        // Note: OSRM balikin [Long, Lat], kita butuh [Lat, Long]
        return coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      } else {
        print("Gagal ambil rute OSRM: ${response.body}");
        return []; // Balikin list kosong kalau gagal biar app ga crash
      }
    } catch (e) {
      print("Error OSRM: $e");
      return [];
    }
  }
}