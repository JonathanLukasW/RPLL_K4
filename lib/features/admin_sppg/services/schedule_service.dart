import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Import for groupBy/firstWhereOrNull/minBy
import '../../../models/production_schedule_model.dart';
import '../../../models/school_model.dart';
import 'dart:convert'; // Pastikan ini ada untuk jsonDecode

// Model sementara untuk menampung Menu + Total Porsi yang dibutuhkan
class MenuProductionDetail {
  final String menuId;
  final String menuName;
  final int totalPortions;
  final int cookingDurationMinutes;
  final int maxConsumeMinutes;

  // Waktu Konsumsi Paling Awal (dari semua sekolah yang minta menu ini)
  final TimeOfDay earliestDeadline;

  MenuProductionDetail({
    required this.menuId,
    required this.menuName,
    required this.totalPortions,
    required this.cookingDurationMinutes,
    required this.maxConsumeMinutes,
    required this.earliestDeadline,
  });
}

class ScheduleService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    return profile['sppg_id'];
  }

  // --- LOGIKA HITUNG MUNDUR (BACKWARD SCHEDULING) ---
  String calculateStartTime(TimeOfDay deliverTime, int cookingDurationMinutes) {
    int deliverMinutes = deliverTime.hour * 60 + deliverTime.minute;
    // 30 min preparation/packing/loading buffer
    int startMinutes = deliverMinutes - cookingDurationMinutes - 30;

    if (startMinutes < 0) startMinutes = 0;

    final int startHour = startMinutes ~/ 60;
    final int startMinute = startMinutes % 60;

    return "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}:00";
  }

  // [BARU] 5. LOGIKA UTAMA: KALKULASI JADWAL PRODUKSI
  Future<List<MenuProductionDetail>> calculateProductionSchedule(
    DateTime date,
  ) async {
    final mySppgId = await _getMySppgId();
    final dayName = DateFormat('EEEE', 'id_ID').format(date);

    // 1. Ambil semua Sekolah SPPG ini
    final schoolsResponse = await _supabase
        .from('schools')
        .select('*')
        .eq('sppg_id', mySppgId)
        .not('menu_default', 'is', null) // Pastikan ada menu default
        .not('deadline_time', 'is', null); // Pastikan ada jadwal rutin

    final List<School> allSchools = (schoolsResponse as List)
        .map((json) => School.fromJson(json))
        .toList();

    // 2. Filter Sekolah yang ada jadwal di hari ini & Tentukan Deadline
    List<Map<String, dynamic>> todaySchools = [];
    for (var school in allSchools) {
      try {
        final Map<String, dynamic> scheduleMap = jsonDecode(
          school.deadlineTime!,
        );
        if (scheduleMap.containsKey(dayName)) {
          final deadlineTimeStr =
              scheduleMap[dayName] as String; // e.g., "10:00:00"
          final parts = deadlineTimeStr.split(':');

          todaySchools.add({
            'school': school,
            'deadline_minutes': int.parse(parts[0]) * 60 + int.parse(parts[1]),
          });
        }
      } catch (_) {
        /* ignore invalid schedule */
      }
    }

    if (todaySchools.isEmpty) return [];

    // 3. Kumpulkan Kebutuhan Menu, Hitung Total Porsi, dan Cari Earliest Deadline per Menu

    // Map<String MenuName, List<dynamic>>: List of (School, DeadlineMinutes) pairs
    Map<String, List<Map<String, dynamic>>> menuNeeds = {};

    for (var schoolData in todaySchools) {
      final School school = schoolData['school'];
      final int deadlineMinutes = schoolData['deadline_minutes'];

      if (school.menuDefault != null) {
        final menuNames = school.menuDefault!
            .split(',')
            .map((e) => e.trim())
            .toList();

        for (var menuName in menuNames) {
          if (!menuNeeds.containsKey(menuName)) {
            menuNeeds[menuName] = [];
          }
          menuNeeds[menuName]!.add({
            'portions': school.studentCount,
            'deadline_minutes': deadlineMinutes,
          });
        }
      }
    }

    // 4. Ambil Detail Menu (Durasi Masak, Max Consume Minutes)
    final menuNamesToFetch = menuNeeds.keys.toList();
    final menuDetailsRaw = await _supabase
        .from('menus')
        .select('id, name, cooking_duration_minutes, max_consume_minutes')
        .filter(
          'name',
          'in',
          menuNamesToFetch,
        ) // <--- FIX: Menggunakan .filter() instead of in_()
        .eq('sppg_id', mySppgId);

    Map<String, MenuProductionDetail> finalScheduleMap = {};

    for (var menuName in menuNamesToFetch) {
      final details = menuDetailsRaw.firstWhereOrNull(
        (m) => m['name'] == menuName,
      );
      if (details == null) continue; // Skip menu not found

      final needs = menuNeeds[menuName]!;
      final totalPortions = needs.fold<int>(
        0,
        (sum, need) => sum + (need['portions'] as int),
      );

      // Cari Earliest Deadline (Waktu konsumsi paling ketat)
      final earliestDeadlineMinutes = needs
          .map((n) => n['deadline_minutes'] as int)
          .min;
      final earliestDeadline = TimeOfDay(
        hour: earliestDeadlineMinutes ~/ 60,
        minute: earliestDeadlineMinutes % 60,
      );

      finalScheduleMap[menuName] = MenuProductionDetail(
        menuId: details['id'],
        menuName: menuName,
        totalPortions: totalPortions,
        cookingDurationMinutes: details['cooking_duration_minutes'] as int,
        maxConsumeMinutes: details['max_consume_minutes'] as int,
        earliestDeadline: earliestDeadline,
      );
    }

    // 5. SORTING FINAL: Berdasarkan Max Consume Minutes (Terlama ke Tercepat)
    // Logika: Menu yang tahan lama dimasak duluan, menu yang cepat basi dimasak belakangan.
    List<MenuProductionDetail> finalScheduleList = finalScheduleMap.values
        .toList();
    finalScheduleList.sort(
      (a, b) => b.maxConsumeMinutes.compareTo(a.maxConsumeMinutes),
    );

    // Note: Kita tidak melakukan calculation start/finish time di sini,
    // karena itu biasanya dilakukan saat user mengklik "Generate Production".
    // Kita hanya mengembalikan daftar terurut kebutuhan hari itu.

    // Ini adalah menu dan total porsi yang perlu diproduksi, diurutkan.
    return finalScheduleList;
  }

  // [BARU] 6. SIMPAN JADWAL PRODUKSI DARI HASIL KALKULASI
  Future<void> saveCalculatedSchedule(
    List<MenuProductionDetail> scheduleList,
    DateTime date,
  ) async {
    final mySppgId = await _getMySppgId();

    // 1. Hitung Target Waktu Selesai (Start time = earliest deadline - 30 min buffer)

    // Hitung mundur waktu selesai untuk menu pertama (yang paling cepat basi/paling akhir dimasak)
    // Menu pertama di list adalah yang paling tahan lama, menu terakhir adalah yang paling cepat basi.

    // Start cooking untuk batch adalah waktu TERAKHIR mulai masak (menu yang paling cepat basi)

    // Temukan menu yang PALING KRITIS (Paling cepat basi, yaitu maxConsumeMinutes terpendek)
    // [FIX KRITIS: MENGGANTI minBy]
    MenuProductionDetail? criticalMenu;
    if (scheduleList.isNotEmpty) {
      criticalMenu = scheduleList.reduce(
        (a, b) => a.maxConsumeMinutes < b.maxConsumeMinutes ? a : b,
      );
    }

    if (criticalMenu == null)
      throw Exception("Tidak ada menu untuk dijadwalkan.");

    // A. Cari waktu paling awal harus selesai masak (Earliest Deadline)
    // Kita anggap waktu beres masak = waktu keberangkatan rute paling awal (karena belum ada rute!)

    // Workaround: Asumsi Production FINISH TIME = Departure Time.
    // Karena belum ada rute, kita ambil Earliest Deadline (target konsumsi paling awal)

    // Cari Deadlines dari semua sekolah hari itu
    final schools = await _supabase
        .from('schools')
        .select('deadline_time')
        .eq('sppg_id', mySppgId);
    final dayName = DateFormat('EEEE', 'id_ID').format(date);

    int minDeadlineMinutes = 24 * 60; // Max minutes in a day

    for (var school in schools) {
      try {
        final Map<String, dynamic> scheduleMap = jsonDecode(
          school['deadline_time']!,
        );
        if (scheduleMap.containsKey(dayName)) {
          final parts = (scheduleMap[dayName] as String).split(':');
          final currentMinutes = int.parse(parts[0]) * 60 + int.parse(parts[1]);
          if (currentMinutes < minDeadlineMinutes) {
            minDeadlineMinutes = currentMinutes;
          }
        }
      } catch (_) {
        /* ignore */
      }
    }

    // Waktu paling awal rute harus BERANGKAT (Departure Time) = Min Deadline - Min Tolerance - Travel Time (Assume 0 for now)
    // Karena kita tidak tahu travel time di sini, kita pakai logik backward scheduling dari waktu terawal harus selesai.

    // Waktu harus SELESAI masak (Target Finish Time) = Waktu Departure (sebelum kirim)

    // Asumsi: Waktu Target Selesai Produksi = Earliest Deadline - 45 min (buffer loading/packing)

    final targetFinishMinutes = minDeadlineMinutes - 45;

    final targetFinishTime = TimeOfDay(
      hour: targetFinishMinutes ~/ 60,
      minute: targetFinishMinutes % 60,
    );

    // Cek konflik: apakah sudah ada jadwal produksi?
    final existingSchedules = await _supabase
        .from('production_schedules')
        .select('id')
        .eq('sppg_id', mySppgId)
        .eq('date', DateFormat('yyyy-MM-dd').format(date));

    if (existingSchedules.isNotEmpty) {
      throw Exception(
        "Jadwal produksi untuk tanggal ini sudah ada. Hapus dulu jika ingin membuat jadwal otomatis baru.",
      );
    }

    // 2. Hapus Jadwal Sebelumnya (opsional, tapi diasumsikan tidak ada karena cek di atas)

    // 3. Tentukan Jadwal per Menu (Sequencing)

    // Waktu Masak BERURUTAN ke belakang berdasarkan Durasi Masak (COOKING DURATION)

    // Total Durasi Produksi (semua menu): Sum(cookingDuration)
    final totalCookingDuration = scheduleList.fold<int>(
      0,
      (sum, m) => sum + m.cookingDurationMinutes,
    );

    int currentFinishMinutes = targetFinishMinutes;
    List<Map<String, dynamic>> insertData = [];

    // Iterasi dari menu yang paling penting (paling akhir dimasak/paling tahan lama)
    // Karena list sudah diurutkan (max_consume_minutes terlama duluan),
    // kita perlu balikin urutan list untuk scheduling yang benar (menu paling cepat basi dimasak terakhir)

    final reversedScheduleList = scheduleList.reversed
        .toList(); // Menu paling cepat basi di awal

    for (var menuDetail in reversedScheduleList) {
      final start = currentFinishMinutes - menuDetail.cookingDurationMinutes;

      final fmtStart =
          "${(start ~/ 60).toString().padLeft(2, '0')}:${(start % 60).toString().padLeft(2, '0')}:00";
      final fmtFinish =
          "${(currentFinishMinutes ~/ 60).toString().padLeft(2, '0')}:${(currentFinishMinutes % 60).toString().padLeft(2, '0')}:00";

      insertData.add({
        'sppg_id': mySppgId,
        'date': DateFormat('yyyy-MM-dd').format(date),
        'menu_id': menuDetail.menuId,
        'total_portions': menuDetail.totalPortions,
        'start_cooking_time': fmtStart,
        'target_finish_time': fmtFinish,
        'notes': 'Auto Schedule (Urutan Masak)',
      });

      // Update finish time untuk menu berikutnya (gap 0 menit)
      currentFinishMinutes = start;
    }

    // 4. Insert ke DB (Batch Insert)
    if (insertData.isNotEmpty) {
      await _supabase.from('production_schedules').insert(insertData);
    }
  }

  // [BARU] UTILITY: Mendapatkan Menu ID Pertama (Placeholder for Override)
  Future<String> _getFirstMenuId() async {
    try {
      final mySppgId = await _getMySppgId();
      final menu = await _supabase
          .from('menus')
          .select('id')
          .eq('sppg_id', mySppgId)
          .limit(1)
          .single();
      if (menu == null) {
        throw Exception(
          "Tidak ada menu terdaftar untuk membuat jadwal khusus.",
        );
      }
      return menu['id'];
    } catch (e) {
      rethrow;
    }
  }

  // --- 1. READ: AMBIL JADWAL BULANAN (This was missing or incomplete) ---
  Future<List<ProductionSchedule>> getSchedulesByMonth(DateTime month) async {
    try {
      // Re-use logic to get SPPG ID
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // Tentukan awal & akhir bulan
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // Fetch schedules, joining with menus to get the name
      final response = await _supabase
          .from('production_schedules')
          .select('*, menus(name, cooking_duration_minutes)')
          .eq('sppg_id', mySppgId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String());

      final List<dynamic> data = response;
      return data.map((json) => ProductionSchedule.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal mengambil jadwal bulanan: $e");
    }
  }

  // --- 2. CREATE: TAMBAH JADWAL (Jadwal Khusus / Override) ---
  Future<void> addScheduleForRequest({
    required DateTime date,
    required String schoolId,
    required int portions,
    required TimeOfDay deliverTime,
    required int cookingDuration,
    required int toleranceMinutes,
    String? notes,
  }) async {
    try {
      final mySppgId = await _getMySppgId();
      final menuId = await _getFirstMenuId(); // Placeholder menu ID

      final String targetFinish =
          "${deliverTime.hour.toString().padLeft(2, '0')}:${deliverTime.minute.toString().padLeft(2, '0')}:00";
      final String startCooking = calculateStartTime(
        deliverTime,
        cookingDuration,
      );

      await _supabase.from('production_schedules').insert({
        'sppg_id': mySppgId,
        'date': date.toIso8601String().split('T')[0],
        'menu_id': menuId,
        'total_portions': portions,
        'start_cooking_time': startCooking,
        'target_finish_time': targetFinish,
        'notes':
            'Jadwal Khusus | Sekolah: $schoolId | ${notes ?? 'Dibuat dari Pengajuan'}',
      });
    } catch (e) {
      throw Exception("Gagal tambah jadwal khusus: $e");
    }
  }

  // --- 2. CREATE: TAMBAH JADWAL ---
  Future<void> addSchedule({
    required DateTime date,
    required String menuId,
    required int portions,
    required TimeOfDay deliverTime, // Target Jam Kirim (Deadline)
    required int cookingDuration, // Dari Menu
    String? notes,
  }) async {
    try {
      final mySppgId = await _getMySppgId();

      final String targetFinish =
          "${deliverTime.hour.toString().padLeft(2, '0')}:${deliverTime.minute.toString().padLeft(2, '0')}:00";
      final String startCooking = calculateStartTime(
        deliverTime,
        cookingDuration,
      );

      await _supabase.from('production_schedules').insert({
        'sppg_id': mySppgId,
        'date': date.toIso8601String().split('T')[0],
        'menu_id': menuId,
        'total_portions': portions,
        'start_cooking_time': startCooking,
        'target_finish_time': targetFinish,
        'notes': notes,
      });
    } catch (e) {
      throw Exception("Gagal tambah jadwal: $e");
    }
  }

  // --- 3. UPDATE: UBAH JADWAL (JADWAL DADAKAN) ---
  Future<void> updateSchedule({
    required String id,
    required String menuId,
    required int portions,
    required TimeOfDay deliverTime,
    required int cookingDuration,
    String? notes,
  }) async {
    try {
      final String targetFinish =
          "${deliverTime.hour.toString().padLeft(2, '0')}:${deliverTime.minute.toString().padLeft(2, '0')}:00";
      final String startCooking = calculateStartTime(
        deliverTime,
        cookingDuration,
      );

      await _supabase
          .from('production_schedules')
          .update({
            'menu_id': menuId,
            'total_portions': portions,
            'start_cooking_time': startCooking, // Hitung ulang waktu masak
            'target_finish_time': targetFinish,
            'notes': notes,
          })
          .eq('id', id);
    } catch (e) {
      throw Exception("Gagal update jadwal: $e");
    }
  }

  // --- 4. DELETE: HAPUS JADWAL ---
  Future<void> deleteSchedule(String id) async {
    try {
      await _supabase.from('production_schedules').delete().eq('id', id);
    } catch (e) {
      throw Exception("Gagal hapus jadwal: $e");
    }
  }
}
