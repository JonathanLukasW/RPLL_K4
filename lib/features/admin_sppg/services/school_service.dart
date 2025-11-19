import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/school_model.dart'; // Sesuaikan path import ini

class SchoolService {
  final _supabase = Supabase.instance.client;

  // --- 1. AMBIL DATA SEKOLAH (KHUSUS SPPG YG LOGIN) ---
  Future<List<School>> getMySchools() async {
    try {
      // Langkah A: Kita harus tau dulu, siapa User yg lagi login?
      final userId = _supabase.auth.currentUser!.id;

      // Langkah B: Cek di tabel profiles, user ini kerja di SPPG mana?
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();

      final String mySppgId = profile['sppg_id'];

      // Langkah C: Ambil sekolah yang sppg_id nya SAMA dengan punya user
      final response = await _supabase
          .from('schools')
          .select()
          .eq('sppg_id', mySppgId) // Filter penting!
          .order('name', ascending: true); // Urutkan abjad

      final List<dynamic> data = response;
      return data.map((json) => School.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception('Gagal mengambil data sekolah: $e');
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
      
      // Masukkan ID SPPG ke dalam data yang mau dikirim
      schoolData['sppg_id'] = profile['sppg_id'];

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
}