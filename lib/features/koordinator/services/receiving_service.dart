import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReceivingService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL INFO PENGIRIMAN HARI INI (Untuk Sekolah si Koordinator)
  Future<Map<String, dynamic>?> getTodayDelivery() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // A. Cari School ID milik Koordinator
      final profile = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .single();
      
      final String? mySchoolId = profile['school_id'];
      if (mySchoolId == null) throw Exception("Akun ini tidak terhubung ke sekolah manapun.");

      // B. Cari Pengiriman hari ini ke sekolah tersebut
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Join: delivery_stops -> delivery_routes (filter tanggal) -> vehicles
      final response = await _supabase
          .from('delivery_stops')
          .select('*, delivery_routes!inner(date, vehicles(plate_number, driver_name))')
          .eq('school_id', mySchoolId)
          .eq('delivery_routes.date', today)
          .maybeSingle(); // Ambil 1 aja

      return response; // Bisa null kalau belum ada jadwal
    } catch (e) {
      throw Exception("Gagal ambil data pengiriman: $e");
    }
  }

  // 2. KONFIRMASI PENERIMAAN
  Future<void> confirmReception({
    required String stopId,
    required int receivedQty,
    required String notes,
    required String recipientName,
    // Nanti kita tambah parameter foto kalau upload sudah siap
  }) async {
    try {
      await _supabase.from('delivery_stops').update({
        'status': 'received', // Status baru: DITERIMA
        'received_qty': receivedQty,
        'reception_notes': notes,
        'recipient_name': recipientName,
        'completion_time': DateTime.now().toIso8601String(), // Waktu TTD
      }).eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal konfirmasi: $e");
    }
  }
}