import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/user_profile.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fungsi Login
  Future<UserProfile?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // 1. Login ke Auth Supabase (Cek Email & Password)
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        throw 'Login gagal: User tidak ditemukan';
      }

      final userId = response.user!.id;
      final userEmail = response.user!.email;

      // 2. Ambil Data Profil & Role dari Tabel 'profiles'
      // Kita select data berdasarkan ID user yang barusan login
      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      // 3. Kembalikan sebagai objek UserProfile
      return UserProfile.fromJson(data, userEmail);

    } on AuthException catch (e) {
      // Error khusus Supabase (misal: password salah)
      throw e.message;
    } catch (e) {
      // Error umum lainnya
      throw 'Terjadi kesalahan: $e';
    }
  }

  // Fungsi Logout
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  // Cek apakah ada user yang sedang login (untuk auto-login)
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }
}