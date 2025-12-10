import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert'; // Import untuk jsonEncode

class ReceivingService {
  final _supabase = Supabase.instance.client;

  // Helper: Ambil School ID user
  Future<String> _getMySchoolId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('school_id')
        .eq('id', userId)
        .single();

    final String? mySchoolId = profile['school_id'];
    if (mySchoolId == null)
      throw Exception("Akun ini tidak terhubung ke sekolah manapun.");
    return mySchoolId;
  }

  // 1. AMBIL JADWAL PENGIRIMAN BULANAN (Untuk Kalender)
  Future<List<Map<String, dynamic>>> getMonthlyDeliveries(
    DateTime month,
  ) async {
    try {
      final mySchoolId = await _getMySchoolId();

      // Tentukan awal & akhir bulan
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // Join: delivery_stops -> delivery_routes (filter tanggal) -> vehicles
      final response = await _supabase
          .from('delivery_stops')
          .select(
            // KRITIS: TAMBAHKAN JOIN KE TABEL SCHOOLS
            '*, delivery_routes!inner(date, vehicles(plate_number, driver_name)), schools(name, student_count)',
          )
          .eq('school_id', mySchoolId);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil jadwal koordinator: $e");
    }
  }

  // 2. KONFIRMASI PENERIMAAN (Diperbarui untuk Multi-Problem Reporting)
  Future<void> confirmReception({
    required String stopId,
    required int receivedQty,
    required String recipientName,
    required List<Map<String, dynamic>> issues, // BARU: List of issues
    String? proofUrl,
  }) async {
    try {
      // Tentukan status akhir: 'received' jika tidak ada masalah, 'issue_reported' jika ada
      final String status = issues.isEmpty ? 'received' : 'issue_reported';

      // Simpan issues array sebagai JSON string/object
      final issuesJson = issues.isEmpty ? null : jsonEncode(issues);

      // Ambil ID Koordinator yang sedang login
      final userId = _supabase.auth.currentUser!.id;

      await _supabase
          .from('delivery_stops')
          .update({
            'status': status,
            'received_qty': receivedQty,
            'recipient_name': recipientName,
            'completion_time': DateTime.now().toIso8601String(),
            'proof_photo_url': proofUrl, // Bukti foto penerimaan
            'issue_details':
                issuesJson, // BARU: Detail masalah dalam bentuk JSONB
            'koordinator_id':
                userId, // BARU: Simpan ID Koordinator yang melaporkan
          })
          .eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal konfirmasi: $e");
    }
  }
}
