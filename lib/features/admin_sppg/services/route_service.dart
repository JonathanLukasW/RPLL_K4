import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:collection/collection.dart';

import '../../../models/route_model.dart';
import '../../../models/school_model.dart';

class RouteService {
  final _supabase = Supabase.instance.client;

  // ===========================================================================
  // BAGIAN 1: LOGIKA PEMBUATAN & PERHITUNGAN RUTE (CORE LOGIC)
  // ===========================================================================

  Future<Map<String, dynamic>> _getBottleneckMenu(List<School> schools) async {
    // ... (logic sama, tidak perlu diulang)
    if (schools.isEmpty) return {'duration': 0, 'menuIds': [], 'menusData': []};

    Set<String> uniqueMenuNames = {};
    for (var school in schools) {
      if (school.menuDefault != null) {
        school.menuDefault!.split(',').forEach((name) {
          uniqueMenuNames.add(name.trim());
        });
      }
    }

    if (uniqueMenuNames.isEmpty)
      return {'duration': 0, 'menuIds': [], 'menusData': []};

    final menus = await _supabase
        .from('menus')
        .select('id, name, cooking_duration_minutes, max_consume_minutes');

    int maxDuration = 0;
    List<String> requiredMenuIds = [];
    List<Map<String, dynamic>> relatedMenus = [];

    for (var name in uniqueMenuNames) {
      final menuData = menus.firstWhereOrNull((m) => m['name'] == name);
      if (menuData != null) {
        final duration = menuData['cooking_duration_minutes'] as int;
        final id = menuData['id'] as String;

        if (duration > maxDuration) {
          maxDuration = duration;
        }
        requiredMenuIds.add(id);
        relatedMenus.add(menuData as Map<String, dynamic>);
      }
    }

    return {
      'duration': maxDuration, // Durasi terlama (bottleneck)
      'menuIds': requiredMenuIds
          .toSet()
          .toList(), // Semua menu ID unik yang terlibat
      'menusData': relatedMenus.toSet().toList(), // Data mentah semua menu
    };
  }

  Future<String> getFirstCourierId() async {
    return await _getFirstCourierId();
  }

  Future<Map<String, dynamic>> getBottleneckMenuPublic(
    List<School> schools,
  ) async {
    return await _getBottleneckMenu(schools);
  }

  Future<void> createBatchRoutes({
    required List<String> vehicleIds,
    required String courierId,
    required List<String> menuIds,
    required DateTime date,
    required List<School> selectedSchools,
    required int cookingDuration,
  }) async {
    // ... (logic sama)
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      if (vehicleIds.isEmpty || menuIds.isEmpty) return;

      final vehiclesData = await _supabase
          .from('vehicles')
          .select('id, courier_profile_id')
          .filter('id', 'in', vehicleIds);

      final Map<String, String?> vehicleCourierMap = {
        for (var v in vehiclesData) v['id']: v['courier_profile_id'],
      };

      int schoolsPerVehicle = (selectedSchools.length / vehicleIds.length)
          .ceil();

      for (int i = 0; i < vehicleIds.length; i++) {
        int start = i * schoolsPerVehicle;
        int end = (start + schoolsPerVehicle < selectedSchools.length)
            ? start + schoolsPerVehicle
            : selectedSchools.length;

        if (start >= selectedSchools.length) break;

        List<School> assignedSchools = selectedSchools.sublist(start, end);
        String currentVehicleId = vehicleIds[i];

        final String finalCourierId =
            vehicleCourierMap[currentVehicleId] ?? courierId;

        await _createSingleRouteCalculation(
          sppgId: mySppgId,
          vehicleId: currentVehicleId,
          courierId: finalCourierId,
          menuIds: menuIds,
          date: date,
          schools: assignedSchools,
          cookingDuration: cookingDuration,
          isDailyBatch: false,
        );
      }
    } catch (e) {
      throw Exception("Gagal bagi rute: $e");
    }
  }

  Future<List<School>> _getScheduledSchoolsForToday(String mySppgId) async {
    // ... (logic sama)
    final now = DateTime.now();
    final currentDayName = DateFormat('EEEE', 'id_ID').format(now);

    final response = await _supabase
        .from('schools')
        .select()
        .eq('sppg_id', mySppgId)
        .not('deadline_time', 'is', null);

    final List<School> allSchools = (response as List)
        .map((json) => School.fromJson(json))
        .toList();

    List<School> scheduledSchools = [];

    for (var school in allSchools) {
      if (school.deadlineTime != null &&
          school.latitude != null &&
          school.longitude != null) {
        try {
          final Map<String, dynamic> scheduleMap = jsonDecode(
            school.deadlineTime!,
          );
          if (scheduleMap.containsKey(currentDayName) &&
              school.menuDefault != null) {
            scheduledSchools.add(school);
          }
        } catch (_) {}
      }
    }

    scheduledSchools.sort((a, b) {
      try {
        final Map<String, dynamic> aMap = jsonDecode(a.deadlineTime!);
        final Map<String, dynamic> bMap = jsonDecode(b.deadlineTime!);
        final aTimeStr = aMap[currentDayName] as String;
        final bTimeStr = bMap[currentDayName] as String;
        return aTimeStr.compareTo(bTimeStr);
      } catch (_) {
        return 0;
      }
    });

    return scheduledSchools;
  }

  Future<String> _getFirstCourierId() async {
    // ... (logic sama)
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];
      final courier = await _supabase
          .from('profiles')
          .select('id')
          .eq('sppg_id', mySppgId)
          .eq('role', 'kurir')
          .limit(1)
          .single();
      if (courier == null)
        throw Exception("Tidak ada Kurir yang terdaftar untuk fallback.");
      return courier['id'] as String;
    } catch (e) {
      throw Exception('Gagal mendapatkan ID Kurir Fallback: $e');
    }
  }

  Future<int> generateDailyRoutes() async {
    // ... (logic sama)
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];
    final DateTime today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    final scheduledSchools = await _getScheduledSchoolsForToday(mySppgId);
    if (scheduledSchools.isEmpty) {
      throw Exception(
        "Tidak ada sekolah yang memiliki jadwal rutin, menu default, atau koordinat yang lengkap untuk hari ini.",
      );
    }

    final vehicles = await _supabase
        .from('vehicles')
        .select('id, capacity_limit, courier_profile_id')
        .eq('sppg_id', mySppgId)
        .eq('is_active', true);
    final List<Map<String, dynamic>> activeVehicles =
        List<Map<String, dynamic>>.from(vehicles);

    if (activeVehicles.isEmpty) {
      throw Exception("Tidak ada kendaraan aktif yang bisa ditugaskan.");
    }

    final bottleneckData = await _getBottleneckMenu(scheduledSchools);
    final int bottleneckDuration = bottleneckData['duration'] as int;
    final List<String> requiredMenuIds =
        bottleneckData['menuIds'] as List<String>;
    final List<Map<String, dynamic>> relatedMenus =
        bottleneckData['menusData'] as List<Map<String, dynamic>>;

    if (requiredMenuIds.isEmpty || bottleneckDuration == 0) {
      throw Exception(
        "Menu set default sekolah tidak terdaftar atau durasi masak nol.",
      );
    }

    Map<String, List<School>> vehicleAssignments = {
      for (var v in activeVehicles) v['id'].toString(): [],
    };
    List<String> vehicleIds = activeVehicles
        .map((v) => v['id'].toString())
        .toList();

    final String fallbackCourierId = await _getFirstCourierId();

    int schoolIndex = 0;
    for (var school in scheduledSchools) {
      final vehicleId = vehicleIds[schoolIndex % vehicleIds.length];
      vehicleAssignments[vehicleId]!.add(school);
      schoolIndex++;
    }

    int routesCreated = 0;
    for (var entry in vehicleAssignments.entries) {
      final vehicleId = entry.key;
      final schoolsForVehicle = entry.value;

      if (schoolsForVehicle.isEmpty) continue;

      final vehicle = activeVehicles.firstWhere((v) => v['id'] == vehicleId);
      final String courierId =
          vehicle['courier_profile_id'] ?? fallbackCourierId;

      await _createSingleRouteCalculation(
        sppgId: mySppgId,
        vehicleId: vehicleId,
        courierId: courierId,
        menuIds: requiredMenuIds,
        date: today,
        schools: schoolsForVehicle,
        cookingDuration: bottleneckDuration,
        isDailyBatch: true,
        bottleneckMenusData: relatedMenus,
      );
      routesCreated++;
    }

    return routesCreated;
  }

  Future<void> _createSingleRouteCalculation({
    required String sppgId,
    required String vehicleId,
    required String courierId,
    required List<String> menuIds,
    required DateTime date,
    required List<School> schools,
    required int cookingDuration,
    bool isDailyBatch = false,
    List<Map<String, dynamic>>? bottleneckMenusData,
  }) async {
    // ... (logic sama)
    // A. Ambil Lokasi Dapur (Titik Awal)
    final origin = await getSppgLocation();
    if (origin == null)
      throw Exception("Lokasi Dapur belum diset! Edit SPPG dulu.");

    // B. Susun Koordinat untuk Request OSRM
    String coordString = "${origin.longitude},${origin.latitude}";
    for (var s in schools) {
      if (s.latitude == null || s.longitude == null)
        throw Exception("Sekolah ${s.name} belum punya lokasi GPS!");
      coordString += ";${s.longitude},${s.latitude}";
    }

    // C. Panggil OSRM untuk dapatkan Durasi Per Segmen (Legs)
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$coordString?overview=false',
    );
    final response = await http.get(url);

    if (response.statusCode != 200)
      throw Exception(
        "Gagal hitung durasi jalan (OSRM Error: HTTP ${response.statusCode}).",
      );

    final data = jsonDecode(response.body);

    if (data['code'] != 'Ok' ||
        data['routes'] == null ||
        (data['routes'] as List).isEmpty) {
      throw Exception(
        "OSRM ROUTING FAILED: Tidak dapat menemukan rute yang valid. Cek koordinat GPS sekolah dan dapur. Respon OSRM: ${data['code']}",
      );
    }

    final List<dynamic> legs = data['routes'][0]['legs']; // Segmen perjalanan

    // D. Hitung Total Waktu & Durasi per Segmen
    int totalTravelSeconds = 0;
    List<int> travelSecondsPerLeg = [];

    for (var leg in legs) {
      int duration = (leg['duration'] as num).toInt(); // Detik
      travelSecondsPerLeg.add(duration);
      totalTravelSeconds += duration + (10 * 60);
    }

    // E. Tentukan Deadline Paling Awal (The Bottle Neck)
    TimeOfDay earliestDeadline = const TimeOfDay(hour: 13, minute: 0);
    final String currentDayName = DateFormat('EEEE', 'id_ID').format(date);

    for (var s in schools) {
      if (s.deadlineTime != null) {
        String scheduleJson = s.deadlineTime!;
        try {
          final Map<String, dynamic> scheduleMap = jsonDecode(scheduleJson);
          if (scheduleMap.containsKey(currentDayName)) {
            final deadlineString = scheduleMap[currentDayName];
            final parts = deadlineString.split(':');
            if (parts.length >= 2) {
              final time = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
              if (time.hour < earliestDeadline.hour ||
                  (time.hour == earliestDeadline.hour &&
                      time.minute < earliestDeadline.minute)) {
                earliestDeadline = time;
              }
            }
          }
        } catch (_) {
          /* ignore */
        }
      }
    }

    // F. Hitung Mundur Jam Berangkat (Departure Time)
    int deadlineSeconds =
        earliestDeadline.hour * 3600 + earliestDeadline.minute * 60;
    int departureSeconds = deadlineSeconds - totalTravelSeconds;

    if (departureSeconds < 0) departureSeconds = 0;

    TimeOfDay departureTime = TimeOfDay(
      hour: departureSeconds ~/ 3600,
      minute: (departureSeconds % 3600) ~/ 60,
    );

    // G. Hitung Jam Masak (Start Cooking)
    int startCookingSeconds =
        departureSeconds - (cookingDuration * 60) - (30 * 60); // 30 min loading
    if (startCookingSeconds < 0) startCookingSeconds = 0;

    TimeOfDay startCookingTime = TimeOfDay(
      hour: startCookingSeconds ~/ 3600,
      minute: (startCookingSeconds % 3600) ~/ 60,
    );

    // Format String untuk DB (HH:mm:ss)
    String fmtDep =
        "${departureTime.hour.toString().padLeft(2, '0')}:${departureTime.minute.toString().padLeft(2, '0')}:00";
    String fmtCook =
        "${startCookingTime.hour.toString().padLeft(2, '0')}:${startCookingTime.minute.toString().padLeft(2, '0')}:00";

    // H. INSERT RUTE KE DB
    final routeRes = await _supabase
        .from('delivery_routes')
        .insert({
          'date': date.toIso8601String().split('T')[0],
          'sppg_id': sppgId,
          'vehicle_id': vehicleId,
          'courier_id': courierId,
          'departure_time': fmtDep, // Hasil Hitungan
          'status': 'pending',
        })
        .select()
        .single(); // HATI-HATI DENGAN SINGLE()! Pastikan hanya 1 record terinsert.
    final String newRouteId = routeRes['id'];

    // I. INSERT KE route_menus
    List<Map<String, dynamic>> routeMenuData = menuIds
        .map((id) => {'route_id': newRouteId, 'menu_id': id})
        .toList();
    await _supabase.from('route_menus').insert(routeMenuData);

    // J. INSERT STOPS (DENGAN ESTIMASI WAKTU TIBA / ETA)
    List<Map<String, dynamic>> stopsData = [];
    int currentSeconds = departureSeconds;

    for (int k = 0; k < schools.length; k++) {
      currentSeconds += travelSecondsPerLeg[k];

      int h = currentSeconds ~/ 3600;
      int m = (currentSeconds % 3600) ~/ 60;
      String fmtEta =
          "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:00";

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

    String bottleneckMenuId = menuIds.first;
    if (bottleneckMenusData != null) {
      final menuMatch = bottleneckMenusData.firstWhereOrNull(
        (menu) => (menu['cooking_duration_minutes'] as int) == cookingDuration,
      );
      bottleneckMenuId = menuMatch?['id'] as String? ?? menuIds.first;
    }

    String notes = isDailyBatch
        ? 'Auto-Daily Batch (Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt)'
        : 'Auto-Schedule (Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt)';

    await _supabase.from('production_schedules').insert({
      'sppg_id': sppgId,
      'date': date.toIso8601String().split('T')[0],
      'menu_id': bottleneckMenuId,
      'total_portions': totalPortions,
      'start_cooking_time': fmtCook,
      'target_finish_time': fmtDep,
      'notes': notes,
    });
  }

  Future<void> updateRouteSchools(
    String routeId,
    List<School> newSchoolList,
    int cookingDuration,
  ) async {
    try {
      final routeData = await _supabase
          .from('delivery_routes')
          .select()
          .eq('id', routeId)
          .single();

      final routeMenus = await _supabase
          .from('route_menus')
          .select('menu_id')
          .eq('route_id', routeId);
      final List<String> menuIds = routeMenus
          .map<String>((m) => m['menu_id'] as String)
          .toList();

      final DateTime date = DateTime.parse(routeData['date']);
      final String vehicleId = routeData['vehicle_id'];
      final String courierId = routeData['courier_id'];
      final String sppgId = routeData['sppg_id'];

      // 2. Hapus Rute Lama (stops, route_menus, route)
      await _supabase.from('delivery_stops').delete().eq('route_id', routeId);
      await _supabase.from('route_menus').delete().eq('route_id', routeId);
      await _supabase.from('delivery_routes').delete().eq('id', routeId);

      // 3. Buat Ulang Rute dengan Sekolah Baru & Hitung Ulang
      await _createSingleRouteCalculation(
        sppgId: sppgId,
        vehicleId: vehicleId,
        courierId: courierId,
        menuIds: menuIds,
        date: date,
        schools: newSchoolList,
        cookingDuration: cookingDuration,
        isDailyBatch: true,
      );
    } catch (e) {
      throw Exception("Gagal update rute: $e");
    }
  }

  // [BARU] Helper untuk CreateRouteScreen, mengambil rute hari tertentu
  Future<List<Map<String, dynamic>>> getRoutesByDate(DateTime date) async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];

    final response = await _supabase
        .from('delivery_routes')
        .select('vehicle_id')
        .eq('sppg_id', mySppgId)
        .eq('date', DateFormat('yyyy-MM-dd').format(date));

    return List<Map<String, dynamic>>.from(response);
  }

  // ===========================================================================
  // BAGIAN 2: FUNGSI GET & READ DATA
  // ===========================================================================

  // --- 4. AMBIL RUTE BULANAN (KALENDER) ---
  Future<List<DeliveryRoute>> getRoutesByMonth(DateTime month) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('role, sppg_id')
          .eq('id', userId)
          .single();

      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      var query = _supabase
          .from('delivery_routes')
          .select(
            '*, vehicles(plate_number), profiles!courier_id(full_name), route_menus(menu_id, menus(name))',
          )
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String());

      if (profile['role'] == 'kurir') {
        query = query.eq('courier_id', userId);
      } else {
        query = query.eq('sppg_id', profile['sppg_id']);
      }

      final response = await query;
      return (response as List)
          .map((json) => DeliveryRoute.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception("Gagal ambil jadwal: $e");
    }
  }

  // --- 5. AMBIL SEMUA RUTE (LIST HISTORY ADMIN) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      final response = await _supabase
          .from('delivery_routes')
          .select(
            '*, vehicles(plate_number), profiles!courier_id(full_name), route_menus(menu_id, menus(name))',
          )
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
          .select(
            '*, vehicles(plate_number), profiles!courier_id(full_name), route_menus(menu_id, menus(name))',
          )
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
          .select(
            '*, schools(name, address, gps_lat, gps_long, student_count, menu_default, deadline_time, service_time_minutes, is_high_risk)',
          )
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
      // [FIX] CHANGE STATUS FROM ACTIVE TO COMPLETED (OR VICE VERSA)
      await _supabase
          .from('delivery_routes')
          .update({'status': newStatus})
          .eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal update status rute: $e");
    }
  }

  Future<void> updateStopStatus(String stopId, String newStatus) async {
    try {
      await _supabase
          .from('delivery_stops')
          .update({
            'status': newStatus,
            'arrival_time': newStatus == 'completed'
                ? DateTime.now().toIso8601String()
                : null,
          })
          .eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update status stop: $e");
    }
  }

  Future<void> validateLoadWithPhoto(String routeId, String photoUrl) async {
    try {
      await _supabase
          .from('delivery_routes')
          .update({
            'status': 'active',
            'load_proof_photo_url': photoUrl,
            'start_time': DateTime.now().toIso8601String(),
          })
          .eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal validasi muatan: $e");
    }
  }

  Future<void> completeStopWithPhoto(String stopId, String photoUrl) async {
    try {
      await _supabase
          .from('delivery_stops')
          .update({
            'status': 'completed',
            'courier_proof_photo_url': photoUrl,
            'arrival_time': DateTime.now().toIso8601String(),
          })
          .eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update stop: $e");
    }
  }

  Future<void> deleteRoute(String routeId) async {
    try {
      await _supabase.from('route_menus').delete().eq('route_id', routeId);
      await _supabase.from('delivery_routes').delete().eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal menghapus rute: $e");
    }
  }

  // --- UTILITAS PETA & LOKASI ---

  Future<List<LatLng>> getRoutePolyline(List<LatLng> coordinates) async {
    try {
      if (coordinates.length < 2) return [];

      String coordString = coordinates
          .map((p) => "${p.longitude},${p.latitude}")
          .join(';');

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] != 'Ok') return [];

        final List<dynamic> coords =
            data['routes'][0]['geometry']['coordinates'];
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
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String sppgId = profile['sppg_id'];

      final sppgData = await _supabase
          .from('sppgs')
          .select('gps_lat, gps_long')
          .eq('id', sppgId)
          .single();

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
