import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class CourierModel {
  final String id;
  final String name;
  final String email;
  
  CourierModel({required this.id, required this.name, required this.email});
}

class CourierService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL LIST KURIR (Milik SPPG Ini)
  Future<List<CourierModel>> getMyCouriers() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Cek SPPG ID
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      // Ambil profil dengan role 'kurir' dan sppg_id yang sama
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('sppg_id', mySppgId)
          .eq('role', 'kurir'); // Filter khusus kurir

      final List<dynamic> data = response;
      return data.map((json) => CourierModel(
        id: json['id'],
        name: json['full_name'] ?? 'Tanpa Nama',
        // Email biasanya tidak disimpan di profile (kecuali kita tambah kolom email di profile),
        // tapi untuk sekarang kita tampilkan nama saja cukup.
        email: 'Kurir Terdaftar', 
      )).toList();

    } catch (e) {
      throw Exception('Gagal ambil data kurir: $e');
    }
  }

  // 2. BUAT AKUN KURIR BARU (HTTP Request Aman)
  Future<void> createCourierAccount({
    required String email,
    required String password,
    required String fullName,
  }) async {
    // AMBIL DATA DARI ENV / FILE SEBELUMNYA
    const String projectUrl = 'https://mqyfrqgfpqwlrloqtpvi.supabase.co';
    const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWZycWdmcHF3bHJsb3F0cHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTMxMDMsImV4cCI6MjA3OTAyOTEwM30.KoXKouhFN0H7Iz9MSnRhFQuBIePVMwWyXmrzSv3rEeQ';

    try {
      // A. Dapatkan SPPG ID Admin yang sedang login
      final myUserId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', myUserId).single();
      final String mySppgId = profile['sppg_id'];

      // B. Request Signup ke Supabase
      final url = Uri.parse('$projectUrl/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
        },
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': { 'full_name': fullName }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // Ambil ID User Baru
        String? newUserId;
        if (responseData['id'] != null) {
          newUserId = responseData['id'];
        } else if (responseData['user'] != null) {
          newUserId = responseData['user']['id'];
        }

        if (newUserId == null) throw Exception("Gagal dapat ID User Kurir.");

        // C. Simpan ke Tabel Profiles sebagai 'kurir'
        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': fullName,
          'role': 'kurir',       // PENTING: Role-nya kurir
          'sppg_id': mySppgId,   // Kurir ini milik SPPG kita
          'school_id': null,
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
}