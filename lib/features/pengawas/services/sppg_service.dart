import 'dart:convert'; // Wajib ada buat JSON
import 'package:http/http.dart' as http; // Wajib ada buat Request
import 'package:supabase_flutter/supabase_flutter.dart';
// Pastikan path ini benar. Kalau merah, hapus baris ini lalu ketik ulang biar auto-import
import '../../../models/sppg_model.dart'; 

class SppgService {
  // Client utama (Admin BGN)
  final _supabase = Supabase.instance.client;

  // --- FUNGSI A: DATABASE (CRUD DATA KANTOR SPPG) ---
  
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
      
      return data.map((json) {
        return Sppg(
          id: json['id'].toString(),
          name: json['name'] ?? 'Tanpa Nama',
          address: json['address'],
          email: json['email'],
          phone: json['phone'],
          latitude: json['gps_lat'] != null ? double.tryParse(json['gps_lat'].toString()) : null,
          longitude: json['gps_long'] != null ? double.tryParse(json['gps_long'].toString()) : null,
        );
      }).toList();
    } catch (e) {
      throw Exception('Gagal ambil data: $e');
    }
  }

  // --- FUNGSI B: AUTH (VERSI HTTP AMAN) ---
  
  Future<void> createSppgUser({
    required String email,
    required String password,
    required String sppgId,
    required String sppgName,
  }) async {
    // 1. KREDENSIAL SUPABASE (Pastikan tidak ada spasi di url/key)
    const String projectUrl = 'https://mqyfrqgfpqwlrloqtpvi.supabase.co';
    const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1xeWZycWdmcHF3bHJsb3F0cHZpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0NTMxMDMsImV4cCI6MjA3OTAyOTEwM30.KoXKouhFN0H7Iz9MSnRhFQuBIePVMwWyXmrzSv3rEeQ';

    final url = Uri.parse('$projectUrl/auth/v1/signup');
    
    try {
      print("--- Melakukan Request HTTP ke Supabase Auth ---"); // Debugging

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'apikey': anonKey,
        },
        body: jsonEncode({
          'email': email.trim(), // Trim biar ga ada spasi gak sengaja
          'password': password,
          'data': { 
             'full_name': 'Admin $sppgName' 
          }
        }),
      );

      print("Status Code: ${response.statusCode}"); // Debugging
      print("Response: ${response.body}"); // Debugging

      // 2. CEK HASIL
      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        
        // --- [ANTI ERROR NULL] ---
        // Supabase kadang balikin ID di root, kadang di dalam user object
        // Kita cek satu-satu
        String? newUserId;

        if (responseData['id'] != null) {
          newUserId = responseData['id'].toString();
        } else if (responseData['user'] != null && responseData['user']['id'] != null) {
          newUserId = responseData['user']['id'].toString();
        }

        // Kalau masih null juga, kita paksa error biar ga lanjut
        if (newUserId == null) {
          throw Exception("Gagal dapat ID User (Format JSON tidak dikenali).");
        }

        // 3. SIMPAN KE TABEL PROFILES
        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': 'Admin $sppgName',
          'role': 'admin_sppg',
          'sppg_id': sppgId,
          'school_id': null,
        });

      } else {
        // GAGAL DARI SERVER
        final errorData = jsonDecode(response.body);
        String msg = errorData['msg'] ?? errorData['message'] ?? 'Gagal mendaftar';
        throw Exception(msg);
      }
    } catch (e) {
      // Tangkap error spesifik
       if (e.toString().contains("User already registered") || e.toString().contains("already been registered")) {
        throw Exception("Email ini sudah terdaftar! Cek menu Authentication Supabase.");
      }
      throw Exception('Error Create User: $e');
    }
  }
}