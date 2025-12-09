import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/courier_model.dart';

class CourierService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    return profile['sppg_id'];
  }

  Future<List<CourierModel>> getMyCouriers() async {
    try {
      final mySppgId = await _getMySppgId();
      // [UPDATE SELECT] Tambahkan phone_number
      final response = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, sppg_id, phone_number',
          ) // <-- Tambah phone_number
          .eq('sppg_id', mySppgId)
          .eq('role', 'kurir');

      final List<dynamic> data = response;
      return data.map((json) => CourierModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal ambil data kurir: $e');
    }
  }

  Future<void> createCourierAccount({
    required String email,
    required String password,
    required String fullName,
    required String phoneNumber,
  }) async {
    const String projectUrl = 'https://mqyfrqgfpqwlrloqtpvi.supabase.co';
    const String anonKey =
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWZycWdmcHF3bHJsb3F0cHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTMxMDMsImV4cCI6MjA3OTAyOTEwM30.KoXKouhFN0H7Iz9MSnRhFQuBIePVMwWyXmrzSv3rEeQ';

    try {
      final myUserId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', myUserId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // A. Request Signup (Signup Supabase Auth)
      // NOTE: Kita tidak bisa langsung pass phone_number via sign up method API anon key
      // Kita akan update profiles setelah user dibuat.

      final url = Uri.parse('$projectUrl/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'apikey': anonKey},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': {'full_name': fullName},
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        String? newUserId = responseData['id'] ?? responseData['user']['id'];
        if (newUserId == null) throw Exception("Gagal dapat ID User Kurir.");

        // B. Simpan ke Profiles (Role: kurir, sppg_id, phone_number)
        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': fullName,
          'email': email.trim(),
          'role': 'kurir',
          'sppg_id': mySppgId,
          'school_id': null,
          'phone_number': phoneNumber, // [BARU] Simpan nomor telepon
        });
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['msg'] ?? 'Gagal mendaftar');
      }
    } catch (e) {
      if (e.toString().contains("User already registered")) {
        throw Exception("Email kurir sudah terdaftar!");
      }
      throw Exception('Gagal buat akun kurir: $e');
    }
  }

  // [BARU] 3. HAPUS AKUN KURIR (Delete Auth User)
  Future<void> deleteCourierAccount(String userId) async {
    try {
      // Hapus akun dari Auth.users. Ini akan otomatis menghapus dari profiles.
      await _supabase.rpc(
        'delete_user_and_profile',
        params: {'user_id_input': userId},
      );
    } catch (e) {
      throw Exception('Gagal hapus akun kurir: $e');
    }
  }

  // [BARU] 4. UPDATE AKUN KURIR
  Future<void> updateCourierAccount(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Tambahkan update email di auth.users jika email berubah (meskipun kita utamakan profiles)
      final profileUpdateData = data..remove('email');

      // Update data di tabel profiles
      await _supabase
          .from('profiles')
          .update(profileUpdateData)
          .eq('id', userId);
    } catch (e) {
      throw Exception('Gagal update akun kurir: $e');
    }
  }
}
