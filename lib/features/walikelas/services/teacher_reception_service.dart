// === FILE: lib/features/walikelas/services/teacher_reception_service.dart ===
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';

class TeacherReceptionService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL JADWAL BULANAN (Untuk Kalender)
  // ... (Fungsi ini sama, tapi gue pastikan nama kelas di-inject)
  Future<List<Map<String, dynamic>>> getMonthlyDeliveries(
    DateTime month,
  ) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      // A. Cari Profile Wali Kelas (Wajib select class_name juga)
      final profile = await _supabase
          .from('profiles')
          .select('school_id, class_name')
          .eq('id', userId)
          .single();
      final String? mySchoolId = profile['school_id'];
      // FIX: Pastikan nama kelas diambil dengan benar
      final String myClassName = profile['class_name'] ?? '-';
      if (mySchoolId == null) throw Exception("Akun tidak terhubung sekolah.");

      // B. Hitung Range Tanggal
      final startDate = DateTime(month.year, month.month, 1);
      final endDate = DateTime(month.year, month.month + 1, 0);

      // C. Ambil Jadwal Pengiriman ke Sekolah (delivery_stops)
      final response = await _supabase
          .from('delivery_stops')
          .select(
            '*, delivery_routes!inner(date), schools(menu_default)',
          ) // Ambil menu_default juga.
          .eq('school_id', mySchoolId)
          .gte('delivery_routes.date', startDate.toIso8601String())
          .lte('delivery_routes.date', endDate.toIso8601String())
          // FIX KRITIS: Menghapus order by created_at yang crash karena column ambiguity.
          // Menggunakan order by estimated_arrival_time (kolom di delivery_stops)
          .order('estimated_arrival_time', ascending: true);

      List<Map<String, dynamic>> deliveries = List<Map<String, dynamic>>.from(
        response,
      );

      // D. Cek History Penerimaan Guru ini (Batch Check biar hemat query)
      final myReceptions = await _supabase
          .from('class_receptions')
          .select('stop_id')
          .eq('teacher_id', userId);

      final Set<String> receivedStopIds = myReceptions
          .map((e) => e['stop_id'].toString())
          .toSet();

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

  // [BARU] 2. AMBIL STATUS PENERIMAAN KELAS SPESIFIK
  // Dipakai di buildDayList untuk menampilkan detail status kelas yang sudah konfirmasi
  Future<Map<String, dynamic>?> getClassReceptionForStop(String stopId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      // Ambil data reception untuk stopId dan teacherId ini
      final response = await _supabase
          .from('class_receptions')
          .select('*')
          .eq('stop_id', stopId)
          .eq('teacher_id', userId)
          .single();

      return Map<String, dynamic>.from(response);
    } on PostgrestException catch (e) {
      // Jika data tidak ditemukan, PostgrestException akan ter-throw
      if (e.code == 'PGRST116') return null; // Baris tidak ditemukan
      throw Exception("Gagal load reception data: ${e.message}");
    } catch (e) {
      throw Exception("Gagal load reception data: $e");
    }
  }

  // 3. SIMPAN KONFIRMASI KELAS (Sama dengan sebelumnya)
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
