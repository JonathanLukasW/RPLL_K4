import 'package:supabase_flutter/supabase_flutter.dart';

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
            '*, delivery_routes!inner(date, vehicles(plate_number, driver_name))',
          )
          .eq('school_id', mySchoolId)
          .gte('delivery_routes.date', startDate.toIso8601String())
          .lte('delivery_routes.date', endDate.toIso8601String())
          .neq('status', 'cancelled') // Jangan ambil yang batal.
          // FIX KRITIS: Menghapus order by created_at yang crash karena column ambiguity.
          // Menggunakan order by estimated_arrival_time (kolom di delivery_stops)
          .order('estimated_arrival_time', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil jadwal koordinator: $e");
    }
  }

  // 2. KONFIRMASI PENERIMAAN
  Future<void> confirmReception({
    required String stopId,
    required int receivedQty,
    required String notes,
    required String recipientName,
    String? issueType,
    String? proofUrl,
  }) async {
    try {
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
            'proof_photo_url': proofUrl,
          })
          .eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal konfirmasi: $e");
    }
  }
}
