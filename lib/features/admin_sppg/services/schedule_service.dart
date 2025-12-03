import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../../../models/production_schedule_model.dart';

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
    int startMinutes =
        deliverMinutes - cookingDurationMinutes - 30; // 30 min packing/loading
    if (startMinutes < 0) startMinutes = 0;
    final int startHour = startMinutes ~/ 60;
    final int startMinute = startMinutes % 60;
    return "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}:00";
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
