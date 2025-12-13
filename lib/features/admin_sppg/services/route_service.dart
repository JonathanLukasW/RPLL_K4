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

  Future<Map<String, dynamic>> getBottleneckMenuSetInfo(
    List<School> schools,
  ) async {
    if (schools.isEmpty)
      return {'duration': 0, 'menuIds': [], 'menuSetNames': []};

    final mySppgId = await _getMySppgId();
    Set<String> uniqueMenuSetNames = schools
        .where((s) => s.menuDefault != null)
        .map((s) => s.menuDefault!)
        .toSet();

    if (uniqueMenuSetNames.isEmpty)
      return {'duration': 0, 'menuIds': [], 'menuSetNames': []};

    // 1. Ambil Menu Set yang terlibat
    final menuSetsRaw = await _supabase
        .from('menu_sets')
        .select(
          '*, karbo_menus:karbo_id(max_consume_minutes, cooking_duration_minutes), protein_menus:protein_id(max_consume_minutes, cooking_duration_minutes), sayur_menus:sayur_id(max_consume_minutes, cooking_duration_minutes), buah_menus:buah_id(max_consume_minutes, cooking_duration_minutes), nabati_menus:nabati_id(max_consume_minutes, cooking_duration_minutes), pelengkap_menus:pelengkap_id(max_consume_minutes, cooking_duration_minutes)',
        )
        .eq('sppg_id', mySppgId)
        .filter('set_name', 'in', uniqueMenuSetNames.toList());

    // 2. Cari Menu dengan MaxConsumeMinutes terpendek (Kritis Mutu) dan Durasi Masak terlama (Bottleneck)
    int minMaxConsume = 9999;
    int maxCookingDuration = 0;
    Set<String> allRequiredMenuIds = {};

    for (var set in menuSetsRaw) {
      final menuFields = [
        'karbo_menus',
        'protein_menus',
        'sayur_menus',
        'buah_menus',
        'nabati_menus',
        'pelengkap_menus',
      ];

      for (var field in menuFields) {
        final menu = set[field];
        if (menu != null) {
          final maxConsume = menu['max_consume_minutes'] as int? ?? 120;
          final duration = menu['cooking_duration_minutes'] as int? ?? 0;

          // Kritis Mutu: Cari Batas Konsumsi Terpendek (Prioritas Urutan Kirim)
          if (maxConsume < minMaxConsume) {
            minMaxConsume = maxConsume;
          }

          // Bottleneck Produksi: Cari Durasi Masak Terlama (Untuk Hitungan Mundur Produksi)
          if (duration > maxCookingDuration) {
            maxCookingDuration = duration;
          }
        }
      }

      // Kumpulkan SEMUA Menu ID dari SEMUA Set yang terlibat (untuk dicatat di route_menus)
      final idFields = [
        'karbo_id',
        'protein_id',
        'sayur_id',
        'buah_id',
        'nabati_id',
        'pelengkap_id',
      ];
      for (var idField in idFields) {
        if (set[idField] != null) {
          allRequiredMenuIds.add(set[idField].toString());
        }
      }
    }

    // ASUMSI KRITIS: Kita hanya menggunakan maxCookingDuration untuk backward scheduling.
    // Dan minMaxConsume AKAN DIGUNAKAN UNTUK SORTING SEKOLAH (Nanti di step G)

    return {
      'duration': maxCookingDuration,
      'menuIds': allRequiredMenuIds.toList(),
      'menuSetNames': uniqueMenuSetNames.toList(),
      'minMaxConsume':
          minMaxConsume, // <--- BARU: Kirim Batas Konsumsi Terpendek
    };
  }

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    // Karena user profile harus selalu punya sppg_id (kecuali BGN), kita asumsikan tidak null.
    if (profile['sppg_id'] == null) {
      throw Exception("User profile missing SPPG ID.");
    }
    return profile['sppg_id'] as String; // Mengembalikan tipe String
  }

  // [BARU CORE LOGIC]: Fungsi untuk menghasilkan urutan sekolah berdasarkan prioritas
  Future<List<School>> _getPrioritizedSchools(
    List<School> schools,
    DateTime date,
  ) async {
    // <--- TAMBAH PARAMETER DATE
    // 1. Ambil Menu Set Details
    // bottleneckData tidak bergantung pada hari, jadi tetap sama.
    final bottleneckData = await getBottleneckMenuSetInfo(schools);

    final currentDayName = DateFormat(
      'EEEE',
      'id_ID',
    ).format(date); // <--- GUNAKAN DATE

    // 2. Hitung Priority Score untuk setiap sekolah (Deadline + Menu Criticality)
    List<Map<String, dynamic>> prioritizedSchools = [];

    for (var school in schools) {
      int deadlineMinutes = 9999;
      int schoolMenuMaxConsume = 9999;

      // A. Cari Deadline Sekolah (Waktu harus SELESAI konsumsi)
      try {
        final Map<String, dynamic> scheduleMap = jsonDecode(
          school.deadlineTime!,
        );
        if (scheduleMap.containsKey(currentDayName)) {
          final deadlineString =
              scheduleMap[currentDayName] as String; // e.g., "10:00:00"
          final parts = deadlineString.split(':');
          deadlineMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
        }
      } catch (_) {
        /* ignore */
      }
      // B. Cari Batas Konsumsi Menu Set Sekolah (Waktu kritis menu)

      // >>> START PERBAIKAN DI SINI: Terapkan null check untuk menuDefault <<<
      if (school.menuDefault == null || school.menuDefault!.isEmpty) {
        // Jika tidak ada menu default, lewati atau berikan prioritas terendah
        // Untuk saat ini, kita anggap dia non-kritis agar tidak mengganggu scheduling lain.
        // Kita langsung set sort key tertinggi (prioritas terendah) dan lanjutkan loop.
        prioritizedSchools.add({'school': school, 'priorityKey': 9999999});
        continue; // Lanjut ke sekolah berikutnya
      }

      final menuSet = await _supabase
          .from('menu_sets')
          .select(
            '*, karbo_menus:karbo_id(max_consume_minutes)',
          ) // Hanya perlu satu field untuk trigger join
          .eq(
            'set_name',
            school.menuDefault as Object,
          ) // <--- FIX ERROR: Casting String? ke Object yang aman
          .limit(1)
          .single();
      // >>> END PERBAIKAN <<<

      // Cari min MaxConsumeMinutes di Menu Set ini
      final menuFields = [
        'karbo_menus',
        'protein_menus',
        'sayur_menus',
        'buah_menus',
        'nabati_menus',
        'pelengkap_menus',
      ];
      int tempMinConsume = 9999;
      for (var field in menuFields) {
        if (menuSet.containsKey(field) && menuSet[field] != null) {
          final maxConsume =
              menuSet[field]['max_consume_minutes'] as int? ?? 120;
          if (maxConsume < tempMinConsume) {
            tempMinConsume = maxConsume;
          }
        }
      }
      schoolMenuMaxConsume = tempMinConsume;

      // PRIORITY SCORE: Jarak waktu dari sekarang ke (Deadline - MaxConsumeMenu)
      // Semakin kecil score, semakin kritis (harus dikirim duluan).
      // Kritis Waktu Tiba = Deadline - Tolerance
      int criticalDeliveryTime = deadlineMinutes - school.toleranceMinutes;

      // Priority Score = (Critical Delivery Time) - (Paling cepat basi)
      // ASUMSI: Sekolah yang menunya cepat basi DAN deadline-nya cepat, harus didahulukan.
      int priorityScore = (criticalDeliveryTime - schoolMenuMaxConsume);

      // Sort Key: Urutan: (Waktu Tiba Kritis) + (Menu Max Consume)
      int finalSortKey =
          criticalDeliveryTime * 1000 +
          schoolMenuMaxConsume; // Semakin kecil, semakin prioritas

      prioritizedSchools.add({'school': school, 'priorityKey': finalSortKey});
    }

    // Sort schools: Smallest key first (highest priority)
    prioritizedSchools.sort(
      (a, b) => (a['priorityKey'] as int).compareTo(b['priorityKey'] as int),
    );

    return prioritizedSchools.map((e) => e['school'] as School).toList();
  }

  Future<String> getFirstCourierId() async {
    return await _getFirstCourierId();
  }

  // [FIX DAN UPDATE MULTI-TRIP]: createBatchRoutes
  Future<void> createBatchRoutes({
    required List<String> vehicleIds,
    required String courierId,
    required List<String> menuIds,
    required DateTime date, // <--- Gunakan 'date' ini
    required List<School> selectedSchools,
    required int cookingDuration,
  }) async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];

    if (vehicleIds.isEmpty || menuIds.isEmpty) return;

    // >>> KRITIS: Logic Multi-Trip (Hanya untuk 1 kendaraan di mode manual) <<<
    if (vehicleIds.length != 1) {
      throw Exception(
        "Hanya mendukung 1 kendaraan untuk Rute Manual saat ini.",
      );
    }

    final vehicleId = vehicleIds.first;
    final vehicleRaw = await _supabase
        .from('vehicles')
        .select('capacity_limit')
        .eq('id', vehicleId)
        .single();
    final vehicleCapacity = vehicleRaw['capacity_limit'] as int;

    // [BARU] Helper untuk CreateRouteScreen, mengambil rute hari tertentu
    Future<List<Map<String, dynamic>>> getRoutesByDate(DateTime date) async {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id']; // <--- sudah pasti String

      final response = await _supabase
          .from('delivery_routes')
          .select('vehicle_id')
          .eq(
            'sppg_id',
            mySppgId,
          ) // <--- ERROR HILANG KARENA mySppgId sudah String
          .eq('date', DateFormat('yyyy-MM-dd').format(date));

      return List<Map<String, dynamic>>.from(response);
    }

    // 1. PRIORITASISASI SEKOLAH BERDASARKAN KRITIS WAKTU/MENU
    // Perubahan KRITIS: Meskipun ini manual, kita harus menggunakan sorting yang sama
    // agar rute yang dihasilkan optimal sesuai constraint menu.
    List<School> sortedSchools = await _getPrioritizedSchools(
      selectedSchools,
      date,
    ); // <--- FIX: KIRIM ARGUMEN DATE

    List<School> remainingSchools = List.from(sortedSchools);
    int routeIndex = 1;
    int routesCreated = 0;

    // Lakukan Loop sampai semua sekolah terlayani (Multi-Trip Logic)
    while (remainingSchools.isNotEmpty) {
      List<School> currentTripSchools = [];
      int currentLoad = 0;

      // 2. PEMBAGIAN TRIP: Ambil sekolah sebanyak mungkin sesuai kapasitas
      int i = 0;
      while (i < remainingSchools.length) {
        final school = remainingSchools[i];

        if (school.studentCount > vehicleCapacity) {
          throw Exception(
            "Sekolah ${school.name} porsi (${school.studentCount}) melebihi kapasitas mobil (${vehicleCapacity}).",
          );
        }

        if (currentLoad + school.studentCount <= vehicleCapacity) {
          currentLoad += school.studentCount;
          currentTripSchools.add(school);
          i++;
        } else {
          break; // Kapasitas penuh
        }
      }

      if (currentTripSchools.isEmpty) {
        break; // Tidak ada lagi sekolah yang muat
      }

      // 3. BUAT RUTE UNTUK TRIP INI
      await _createSingleRouteCalculation(
        sppgId: mySppgId,
        vehicleId: vehicleId,
        courierId: courierId,
        menuIds: menuIds,
        date: date,
        schools: currentTripSchools, // Hanya sekolah untuk trip ini
        cookingDuration: cookingDuration,
        isDailyBatch: false, // Ini tetap manual
        notesPrefix: "Manual Trip $routeIndex",
      );

      routesCreated++;
      routeIndex++;

      // Hapus sekolah yang sudah ditambahkan di trip ini dari remainingSchools
      remainingSchools.removeRange(0, currentTripSchools.length);
    }

    // Mengganti return/throw error lama
    if (routesCreated == 0) {
      throw Exception(
        "Gagal membuat rute. Mungkin kapasitas mobil terlalu kecil atau tidak ada sekolah yang muat.",
      );
    }
  }

  // Ubah signature function
  Future<List<School>> _getScheduledSchoolsForDay(
    String mySppgId,
    DateTime date,
  ) async {
    // Gunakan target date untuk mendapatkan nama hari
    final currentDayName = DateFormat(
      'EEEE',
      'id_ID',
    ).format(date); // <--- GUNAKAN DATE

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
          if (scheduleMap.containsKey(
                currentDayName,
              ) && // <--- GUNAKAN currentDayName
              school.menuDefault != null) {
            scheduledSchools.add(school);
          }
        } catch (_) {}
      }
    }

    // Sorting tetap menggunakan deadline hari itu
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

  // Ubah signature function
  Future<int> generateDailyRoutes({required DateTime date}) async {
    // <--- TAMBAH PARAMETER DATE
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];

    // Gunakan tanggal yang dimasukkan, bukan DateTime.now()
    final DateTime targetDate = DateTime(date.year, date.month, date.day);

    // Cek konflik: apakah sudah ada rute hari ini?
    final existingRoutes = await _supabase
        .from('delivery_routes')
        .select('id')
        .eq('sppg_id', mySppgId)
        .eq(
          'date',
          DateFormat('yyyy-MM-dd').format(targetDate),
        ); // <--- GUNAKAN targetDate

    if (existingRoutes.isNotEmpty) {
      throw Exception(
        "Rute untuk tanggal ini (${DateFormat('dd MMM').format(targetDate)}) sudah ada. Hapus rute lama untuk generate yang baru.",
      );
    }

    // 1. Ambil Semua Sekolah yang Terjadwal Hari Ini
    // PERLU MEMODIFIKASI _getScheduledSchoolsForToday agar menerima date
    List<School> scheduledSchools = await _getScheduledSchoolsForDay(
      mySppgId,
      targetDate,
    ); // <--- KIRIM targetDate

    if (scheduledSchools.isEmpty) {
      throw Exception(
        "Tidak ada sekolah yang memiliki jadwal rutin, menu default, atau koordinat yang lengkap untuk tanggal ini.",
      );
    }

    // 2. Prioritasisasi Sekolah (berdasarkan Deadline Kritis & Menu Max Consume)
    // PERLU MEMODIFIKASI _getPrioritizedSchools agar menerima date
    List<School> sortedSchools = await _getPrioritizedSchools(
      scheduledSchools,
      targetDate,
    ); // <--- KIRIM targetDate

    if (sortedSchools.isEmpty) {
      throw Exception(
        "Tidak ada sekolah yang memiliki jadwal rutin, menu default, atau koordinat yang lengkap untuk hari ini.",
      );
    }

    // 2. Prioritasisasi Sekolah (berdasarkan Deadline Kritis & Menu Max Consume)
    // NOTE: Fungsi ini juga melakukan filter jika menu_default sekolah null

    if (sortedSchools.isEmpty) {
      throw Exception(
        "Sekolah tersedia, namun tidak ada yang memiliki Menu Set dan GPS yang valid.",
      );
    }

    // 3. Ambil Kendaraan Aktif dan Kapasitasnya
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

    // 4. Hitung Bottleneck Produksi (Durasi Masak Terlama)
    final bottleneckData = await getBottleneckMenuSetInfo(sortedSchools);
    final int bottleneckDuration = bottleneckData['duration'] as int;
    final List<String> requiredMenuIds =
        bottleneckData['menuIds'] as List<String>;

    if (requiredMenuIds.isEmpty || bottleneckDuration == 0) {
      throw Exception(
        "Menu set default sekolah tidak terdaftar atau durasi masak nol.",
      );
    }

    // 5. PENUGASAN & PEMBAGIAN RUTE DENGAN MULTI-TRIP (Core Logic Perbaikan)

    // Kita akan menggunakan semua mobil yang tersedia secara berulang (round-robin)
    // sambil memecah beban setiap sekolah ke trip yang muat kapasitas.

    List<School> remainingSchools = List.from(sortedSchools);
    int routesCreated = 0;
    int vehicleIndex = 0;

    final String fallbackCourierId = await _getFirstCourierId();

    // Loop ini akan terus berjalan sampai semua sekolah terlayani
    while (remainingSchools.isNotEmpty) {
      // Tentukan mobil yang bertugas di trip ini (Round-Robin vehicle assignment)
      final vehicle = activeVehicles[vehicleIndex % activeVehicles.length];
      final String vehicleId = vehicle['id'].toString();
      final int capacity = vehicle['capacity_limit'] as int;
      final String courierId =
          vehicle['courier_profile_id'] ?? fallbackCourierId;

      List<School> currentTripSchools = [];
      int currentLoad = 0;

      // Ambil sekolah dari awal list (prioritas tertinggi) yang muat di kapasitas mobil
      int i = 0;
      while (i < remainingSchools.length) {
        final school = remainingSchools[i];

        // Cek apakah porsi sekolah ini melebihi kapasitas total mobil.
        // Jika ya, kita harus menghentikan proses, karena asumsi kita adalah porsi < capacity.
        if (school.studentCount > capacity) {
          throw Exception(
            "Sekolah ${school.name} memiliki porsi (${school.studentCount}) melebihi kapasitas mobil (${capacity}). Mohon alokasikan mobil dengan kapasitas lebih besar atau perbarui data.",
          );
        }

        if (currentLoad + school.studentCount <= capacity) {
          currentLoad += school.studentCount;
          currentTripSchools.add(school);
          i++; // Lanjut ke sekolah berikutnya di remainingSchools
        } else {
          // Kapasitas mobil untuk trip ini sudah penuh.
          break;
        }
      }

      if (currentTripSchools.isEmpty) {
        // Ini seharusnya hanya terjadi jika remainingSchools sudah kosong,
        // atau jika semua mobil sudah dicoba dan tidak ada yang bisa melayani.
        break;
      }

      await _createSingleRouteCalculation(
        sppgId: mySppgId,
        vehicleId: vehicleId,
        courierId: courierId,
        menuIds: requiredMenuIds,
        date: targetDate, // <--- KIRIM targetDate
        schools: currentTripSchools,
        cookingDuration: bottleneckDuration,
        isDailyBatch: true,
        notesPrefix: "AUTO Batch ${DateFormat('HH:mm').format(DateTime.now())}",
      );
      routesCreated++;

      // Hapus sekolah yang sudah dialokasikan dari remainingSchools
      remainingSchools.removeRange(0, currentTripSchools.length);

      // Pindah ke mobil berikutnya untuk trip selanjutnya
      vehicleIndex++;
    }

    if (routesCreated == 0) {
      throw Exception(
        "Gagal membuat rute. Tidak ada mobil yang muat atau tidak ada sekolah yang tersisa untuk dikirim.",
      );
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
    String? notesPrefix, // <--- BARU TAMBAHKAN INI
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

    String notes = notesPrefix != null
        ? '$notesPrefix | Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt'
        : (isDailyBatch
              ? 'Auto-Daily Batch (Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt)'
              : 'Auto-Schedule (Rute #$newRouteId, Bottleneck: ${cookingDuration} mnt)'); // <--- LOGIKA NOTES BARU

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

  // --- 8. AMBIL NEXT STOP YANG BELUM SELESAI ---
  Future<Map<String, dynamic>?> getNextPendingStop(String routeId) async {
    try {
      // Ambil stop dengan sequence order terendah (LIMIT 1)
      // yang statusnya BUKAN 'received', 'issue_reported', atau 'completed'
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name)') // Hanya butuh nama sekolah
          .eq('route_id', routeId)
          .not('status', 'in', '("received", "issue_reported", "completed")')
          .order('sequence_order', ascending: true)
          .limit(1)
          .single();

      return response;
    } on PostgrestException catch (e) {
      // Jika tidak ada stop pending/active (semua sudah selesai), Supabase throw PGRST116.
      if (e.code == 'PGRST116') {
        return null;
      }
      throw Exception("Gagal ambil next stop: ${e.message}");
    } catch (e) {
      // Error umum lainnya
      return null;
    }
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
  Future<List<DeliveryRoute>> getMyRoutes({
    DateTime? date, // <--- TAMBAH FILTER
    String? vehicleId, // <--- TAMBAH FILTER
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      var query = _supabase
          .from('delivery_routes')
          .select(
            '*, vehicles(plate_number), profiles!courier_id(full_name), route_menus(menu_id, menus(name))',
          )
          .eq('sppg_id', mySppgId);

      // Terapkan filter tanggal jika ada
      if (date != null) {
        query = query.eq('date', DateFormat('yyyy-MM-dd').format(date));
      }

      // Terapkan filter mobil jika ada (kecuali 'all')
      if (vehicleId != null && vehicleId != 'all') {
        query = query.eq('vehicle_id', vehicleId);
      }

      final response = await query
          .order('date', ascending: false)
          .order('departure_time', ascending: false);

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
