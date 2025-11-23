import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class TeacherReceptionService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL STATUS PENGIRIMAN SEKOLAH HARI INI
  // Wali Kelas perlu tahu: "Barang udah sampe gerbang belum?"
  Future<Map<String, dynamic>?> getSchoolDeliveryStatus() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // A. Cari Profile Wali Kelas (untuk tau school_id)
      final profile = await _supabase
          .from('profiles')
          .select('school_id, class_name')
          .eq('id', userId)
          .single();
      
      final String? mySchoolId = profile['school_id'];
      if (mySchoolId == null) throw Exception("Akun tidak terhubung sekolah.");

      // B. Cari Pengiriman Hari Ini ke sekolah itu
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final response = await _supabase
          .from('delivery_stops')
          .select('*, delivery_routes!inner(date)')
          .eq('school_id', mySchoolId)
          .eq('delivery_routes.date', today)
          .maybeSingle();

      // C. Cek apakah kelas ini SUDAH pernah konfirmasi sebelumnya?
      bool alreadyReceived = false;
      if (response != null) {
        final stopId = response['id'];
        final receptionCheck = await _supabase
            .from('class_receptions')
            .select('id')
            .eq('stop_id', stopId)
            .eq('teacher_id', userId)
            .maybeSingle();
        
        if (receptionCheck != null) alreadyReceived = true;
      }

      // Gabungkan data
      if (response != null) {
        response['already_received'] = alreadyReceived;
        response['my_class_name'] = profile['class_name'];
      }

      return response;

    } catch (e) {
      throw Exception("Gagal cek status: $e");
    }
  }

  // 2. SIMPAN KONFIRMASI KELAS
  Future<void> submitClassReception({
    required String stopId,
    required String className,
    required int qty,
    required String notes,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      await _supabase.from('class_receptions').insert({
        'stop_id': stopId,
        'teacher_id': userId,
        'class_name': className,
        'qty_received': qty,
        'notes': notes,
      });
    } catch (e) {
      throw Exception("Gagal simpan data: $e");
    }
  }
}