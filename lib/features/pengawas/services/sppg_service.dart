import 'dart:convert'; 
import 'package:http/http.dart' as http; 
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/sppg_model.dart'; 

class SppgService {
  final _supabase = Supabase.instance.client;

  // --- A. DATABASE CRUD ---
  
  Future<void> createSppg(Map<String, dynamic> data) async {
    try {
      await _supabase.from('sppgs').insert(data);
    } catch (e) {
      throw Exception('Gagal simpan ke DB: $e');
    }
  }

  Future<List<Sppg>> getAllSppgs() async {
    try {
      final response = await _supabase
          .from('sppgs')
          .select()
          .order('created_at', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => Sppg.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal ambil data: $e');
    }
  }
  
  Future<void> updateSppg(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('sppgs').update(data).eq('id', id);
    } catch (e) {
      throw Exception('Gagal update SPPG: $e');
    }
  }

  // [SUDAH ADA - PASTIKAN SAJA] 4. HAPUS SPPG
  Future<void> deleteSppg(String sppgId) async {
    try {
      // Hapus SPPG (Cascade delete di database akan menghapus data terkait jika disetting)
      await _supabase.from('sppgs').delete().eq('id', sppgId);
    } catch (e) {
      throw Exception('Gagal hapus SPPG: $e');
    }
  }

  // --- B. AUTH (SIMPLIFIED - UC04) ---
  // Kembali ke versi simpel: Cuma Nama, Email, Password
  Future<void> createSppgUser({
    required String email,
    required String password,
    required String sppgId,
    required String sppgName,
    required String fullName, // Nama Admin
  }) async {
    const String projectUrl = 'https://mqyfrqgfpqwlrloqtpvi.supabase.co';
    const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWZycWdmcHF3bHJsb3F0cHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTMxMDMsImV4cCI6MjA3OTAyOTEwM30.KoXKouhFN0H7Iz9MSnRhFQuBIePVMwWyXmrzSv3rEeQ';

    final url = Uri.parse('$projectUrl/auth/v1/signup');
    
    try {
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
        
        String? newUserId;
        if (responseData['id'] != null) {
          newUserId = responseData['id'].toString();
        } else if (responseData['user'] != null && responseData['user']['id'] != null) {
          newUserId = responseData['user']['id'].toString();
        }

        if (newUserId == null) throw Exception("Gagal dapat ID User.");

        // Simpan ke Profiles (Versi Ringkas)
        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': fullName,
          'role': 'admin_sppg',
          'sppg_id': sppgId,
          'email': email.trim(),
        });

      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['msg'] ?? 'Gagal mendaftar');
      }
    } catch (e) {
      if (e.toString().contains("User already registered")) {
        throw Exception("Email ini sudah terdaftar!");
      }
      throw Exception('Error Create User: $e');
    }
  }


}