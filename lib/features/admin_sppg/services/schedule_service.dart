import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart'; 
import '../../../models/production_schedule_model.dart';

class ScheduleService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
    return profile['sppg_id'];
  }

  // --- 1. READ: AMBIL JADWAL BULANAN ---
  Future<List<ProductionSchedule>> getSchedulesByMonth(DateTime month) async {
    try {
      final mySppgId = await _getMySppgId();
      
      // Tentukan awal & akhir bulan
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      final response = await _supabase
          .from('production_schedules')
          .select('*, menus(name, cooking_duration_minutes)') 
          .eq('sppg_id', mySppgId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String());

      final List<dynamic> data = response;
      return data.map((json) => ProductionSchedule.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil jadwal: $e");
    }
  }

  // --- LOGIKA HITUNG MUNDUR (BACKWARD SCHEDULING) ---
  String calculateStartTime(TimeOfDay deliverTime, int cookingDurationMinutes) {
    // Konversi ke menit dari jam 00:00
    int deliverMinutes = deliverTime.hour * 60 + deliverTime.minute;
    
    // Rumus: Jam Kirim - (Durasi Masak + 30 Menit Packing/Loading)
    int startMinutes = deliverMinutes - cookingDurationMinutes - 30; 

    if (startMinutes < 0) startMinutes = 0; 

    final int startHour = startMinutes ~/ 60;
    final int startMinute = startMinutes % 60;

    return "${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}:00";
  }

  // --- 2. CREATE: TAMBAH JADWAL ---
  Future<void> addSchedule({
    required DateTime date,
    required String menuId,
    required int portions,
    required TimeOfDay deliverTime, // Target Jam Kirim (Deadline)
    required int cookingDuration,   // Dari Menu
    String? notes,
  }) async {
    try {
      final mySppgId = await _getMySppgId();
      
      final String targetFinish = "${deliverTime.hour.toString().padLeft(2,'0')}:${deliverTime.minute.toString().padLeft(2,'0')}:00";
      final String startCooking = calculateStartTime(deliverTime, cookingDuration);

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
      final String targetFinish = "${deliverTime.hour.toString().padLeft(2,'0')}:${deliverTime.minute.toString().padLeft(2,'0')}:00";
      final String startCooking = calculateStartTime(deliverTime, cookingDuration);

      await _supabase.from('production_schedules').update({
        'menu_id': menuId,
        'total_portions': portions,
        'start_cooking_time': startCooking, // Hitung ulang waktu masak
        'target_finish_time': targetFinish,
        'notes': notes,
      }).eq('id', id);
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