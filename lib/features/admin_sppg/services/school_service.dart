import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/school_model.dart'; // Sesuaikan path import ini

class SchoolService {
  final _supabase = Supabase.instance.client;

  // Helper untuk mendapatkan SPPG ID (menangani kasus NULL)
  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();

    final String? mySppgId = profile['sppg_id'];

    // Melempar exception jika SPPG ID null, karena SchoolService hanya untuk Admin SPPG.
    if (mySppgId == null) {
      throw Exception("User profile tidak memiliki ID SPPG. Akses Ditolak!");
    }
    return mySppgId;
  }

  // --- 1. AMBIL DATA SEKOLAH (KHUSUS SPPG YG LOGIN) ---
  Future<List<School>> getMySchools() async {
    try {
      // Langkah A & B: Cek ID SPPG user ini (menggunakan helper baru)
      final String mySppgId = await _getMySppgId();

      // Langkah C: Ambil sekolah yang sppg_id nya SAMA dengan punya user
      final response = await _supabase
          .from('schools')
          .select()
          .eq('sppg_id', mySppgId) // Filter penting!
          .order('name', ascending: true); // Urutkan abjad

      final List<dynamic> data = response;
      return data.map((json) => School.fromJson(json)).toList();
    } catch (e) {
      // Menangkap error dari _getMySppgId atau error Supabase lainnya
      throw Exception('Gagal mengambil data sekolah: ${e.toString()}');
    }
  }

  // --- 2. TAMBAH SEKOLAH BARU ---
  Future<void> createSchool(Map<String, dynamic> schoolData) async {
    try {
      // Kita perlu inject 'sppg_id' otomatis biar admin gak perlu input manual
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();

      // Lakukan null check secara eksplisit di sini atau gunakan helper baru
      final String? mySppgId = profile['sppg_id'];
      if (mySppgId == null) {
        throw Exception("Profil Admin tidak terhubung ke SPPG.");
      }

      // Masukkan ID SPPG ke dalam data yang mau dikirim
      schoolData['sppg_id'] = mySppgId;
      // Kirim ke tabel 'schools'
      await _supabase.from('schools').insert(schoolData);
    } catch (e) {
      throw Exception('Gagal menambah sekolah: $e');
    }
  }

  // --- 3. HAPUS SEKOLAH ---
  Future<void> deleteSchool(String schoolId) async {
    try {
      await _supabase.from('schools').delete().eq('id', schoolId);
    } catch (e) {
      throw Exception('Gagal menghapus sekolah: $e');
    }
  }

  // --- 4. UPDATE DATA SEKOLAH (BARU) ---
  Future<void> updateSchool(
    String schoolId,
    Map<String, dynamic> schoolData,
  ) async {
    try {
      // Kita tidak perlu update sppg_id karena itu tidak berubah
      await _supabase.from('schools').update(schoolData).eq('id', schoolId);
    } catch (e) {
      throw Exception('Gagal mengupdate sekolah: $e');
    }
  }

  Future<List<School>> getSchoolsBySppgId(String sppgId) async {
    try {
      final response = await _supabase
          .from('schools')
          .select()
          .eq('sppg_id', sppgId)
          .order('name', ascending: true);

      final List<dynamic> data = response;
      return data.map((json) => School.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal ambil sekolah: $e');
    }
  }
}
