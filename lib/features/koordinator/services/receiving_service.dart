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
      if (mySchoolId == null)
        throw Exception("Akun ini tidak terhubung ke sekolah manapun.");

      // B. Cari Pengiriman hari ini ke sekolah tersebut
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Join: delivery_stops -> delivery_routes (filter tanggal) -> vehicles
      final response = await _supabase
          .from('delivery_stops')
          .select(
            '*, delivery_routes!inner(date, vehicles(plate_number, driver_name))',
          )
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
    String?
    issueType, // Baru: Jenis Masalah (Misal: 'damaged', 'spoiled', 'less_qty')
    String? proofUrl, // Baru: URL Foto Bukti
  }) async {
    try {
      // Tentukan status: Kalau ada issue -> 'issue_reported', kalau aman -> 'received'
      // Atau tetap 'received' tapi ada flag issue. Kita pakai status khusus biar admin notice.
      final String status = (issueType != null && issueType.isNotEmpty)
          ? 'issue_reported'
          : 'received';

      await _supabase
          .from('delivery_stops')
          .update({
            'status': status,
            'received_qty': receivedQty,
            'reception_notes': notes,
            'recipient_name': recipientName,
            'completion_time': DateTime.now().toIso8601String(),
            // Pastikan kolom ini sudah ada di DB (Langkah SQL di bawah)
            'proof_photo_url': proofUrl,
            // Kita simpan jenis masalah di notes atau kolom baru (sementara di notes dulu gapapa)
            // Idealnya bikin kolom 'issue_type' di DB, tapi notes cukup: "[RUSAK] Catatan..."
          })
          .eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal konfirmasi: $e");
    }
  }
}
