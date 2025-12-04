import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../shared/services/notification_service.dart'; // <--- FIX 2: MISSING IMPORT

class ComplaintService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL KELUHAN (BARU) - Menggunakan RPC
  Future<List<Map<String, dynamic>>> getSppgComplaints() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      final response = await _supabase.rpc(
        'get_sppg_all_complaints',
        params: {'sppg_id_input': mySppgId},
      );

      // Map the result from the RPC call
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil semua keluhan: $e");
    }
  }

  // [BARU] 2. MENDAPATKAN ID USER PELAPOR (untuk Notifikasi)
  Future<String> getReporterIdForNotification(
    String complaintId,
    String reporterRole,
  ) async {
    if (reporterRole == 'walikelas') {
      // Jika dari Wali Kelas (Class Receptions), ID user ada di kolom teacher_id
      final response = await _supabase
          .from('class_receptions')
          .select('teacher_id')
          .eq('id', complaintId)
          .single();
      return response['teacher_id'] as String;
    } else if (reporterRole == 'koordinator') {
      // Jika dari Koordinator (Delivery Stops), ID user adalah ID Koordinator Sekolah itu

      // A. Ambil school_id dari delivery_stops
      final stop = await _supabase
          .from('delivery_stops')
          .select('school_id')
          .eq('id', complaintId)
          .single();
      final String schoolId = stop['school_id'];

      // B. Cari ID profiles yang role=koordinator dan school_id=school_id
      final koordinator = await _supabase
          .from('profiles')
          .select('id')
          .eq('role', 'koordinator')
          .eq('school_id', schoolId)
          .limit(1) // Ambil yang pertama
          .single();

      return koordinator['id'] as String;
    }

    throw Exception("Gagal identifikasi pelapor untuk notifikasi.");
  }

  // 3. KIRIM INSTRUKSI (TINDAK LANJUT) + NOTIFIKASI
  Future<void> respondToComplaint({
    required String id,
    required String response,
    required String
    reporterId, // ID Wali/Koordinator yang lapor (user profiles ID)
    required String reporterRole, // 'koordinator' atau 'walikelas'
    required String
    targetTableId, // ID dari tabel yg mau diupdate (id CR atau id DS)
    required String targetTableName, // 'class_receptions' atau 'delivery_stops'
  }) async {
    try {
      // A. Update Status dan Respon di tabel yang benar
      await _supabase
          .from(targetTableName)
          .update({
            'admin_response': response,
            'resolved_at': DateTime.now().toIso8601String(),
          })
          .eq('id', targetTableId);

      // B. KIRIM NOTIFIKASI
      final notificationService = NotificationService();

      // C. Tentukan Tipe Notifikasi dan Body
      String title, body;

      if (reporterRole == 'walikelas') {
        title = "Keluhan Kualitas Ditindaklanjuti";
        body = "Admin SPPG merespon keluhan Anda: $response";
      } else {
        // koordinator
        title = "Laporan Penerimaan Ditindaklanjuti";
        body = "Admin SPPG merespon laporan Anda: $response";
      }

      await notificationService.sendNotification(
        recipientId: reporterId, // ID user yang akan menerima notif
        title: title,
        body: body,
        type: 'success', // atau 'warning'
      );
    } catch (e) {
      throw Exception("Gagal kirim respon/notifikasi: $e");
    }
  }
}
