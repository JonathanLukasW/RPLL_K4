import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherReceptionService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL JADWAL BULANAN (Untuk Kalender)
  Future<List<Map<String, dynamic>>> getMonthlyDeliveries(DateTime month) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // A. Cari Profile Wali Kelas
      final profile = await _supabase
          .from('profiles')
          .select('school_id, class_name')
          .eq('id', userId)
          .single();
      
      final String? mySchoolId = profile['school_id'];
      final String myClassName = profile['class_name'] ?? '-';
      
      if (mySchoolId == null) throw Exception("Akun tidak terhubung sekolah.");

      // B. Hitung Range Tanggal
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // C. Ambil Jadwal Pengiriman ke Sekolah
      final response = await _supabase
          .from('delivery_stops')
          .select('*, delivery_routes!inner(date)')
          .eq('school_id', mySchoolId)
          .gte('delivery_routes.date', startDate.toIso8601String())
          .lte('delivery_routes.date', endDate.toIso8601String())
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> deliveries = List<Map<String, dynamic>>.from(response);

      // D. Cek History Penerimaan Guru ini (Batch Check biar hemat query)
      final myReceptions = await _supabase
          .from('class_receptions')
          .select('stop_id')
          .eq('teacher_id', userId);
      
      final Set<String> receivedStopIds = myReceptions.map((e) => e['stop_id'].toString()).toSet();

      // E. Gabungkan Status
      for (var item in deliveries) {
        item['already_received'] = receivedStopIds.contains(item['id']);
        item['my_class_name'] = myClassName;
      }

      return deliveries;

    } catch (e) {
      throw Exception("Gagal ambil jadwal wali kelas: $e");
    }
  }

  // 2. SIMPAN KONFIRMASI KELAS
  Future<void> submitClassReception({
    required String stopId,
    required String className,
    required int qty,
    required String notes,
    String? issueType, 
    String? proofUrl, 
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      await _supabase.from('class_receptions').insert({
        'stop_id': stopId,
        'teacher_id': userId,
        'class_name': className,
        'qty_received': qty,
        'notes': notes,
        'issue_type': issueType, 
        'proof_photo_url': proofUrl, 
      });
    } catch (e) {
      throw Exception("Gagal simpan data: $e");
    }
  }
}