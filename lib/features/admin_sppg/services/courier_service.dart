import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/courier_model.dart';

class CourierService {
  final _supabase = Supabase.instance.client;

  // Helper untuk mendapatkan SPPG ID Admin
  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    return profile['sppg_id'];
  }

  // 1. AMBIL LIST KURIR
  Future<List<CourierModel>> getMyCouriers() async {
    try {
      final mySppgId = await _getMySppgId();
      
      // Ambil data profile kurir (full_name, email) yang sppg_id-nya sama
      // Pastikan kolom 'email' sudah ada di tabel profiles
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, sppg_id') 
          .eq('sppg_id', mySppgId)
          .eq('role', 'kurir');

      final List<dynamic> data = response;
      return data.map((json) => CourierModel.fromJson(json)).toList();
      
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
    const String projectUrl = 'https://mqyfrqgfpqwlrloqtpvi.supabase.co';
    const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWZycWdmcHF3bHJsb3F0cHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTMxMDMsImV4cCI6MjA3OTAyOTEwM30.KoXKouhFN0H7Iz9MSnRhFQuBIePVMwWyXmrzSv3rEeQ';

    try {
      final myUserId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', myUserId).single();
      final String mySppgId = profile['sppg_id'];

      final url = Uri.parse('$projectUrl/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'apikey': anonKey},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': { 'full_name': fullName }
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        String? newUserId = responseData['id'] ?? responseData['user']['id']; 

        if (newUserId == null) throw Exception("Gagal dapat ID User Kurir.");

        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': fullName,
          'email': email.trim(),
          'role': 'kurir',
          'sppg_id': mySppgId,
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