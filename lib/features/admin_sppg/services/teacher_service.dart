import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherModel {
  final String id;
  final String name;
  final String email;
  final String schoolName;
  final String className;
  final String? schoolId; // <--- ADD THIS FUCKING FIELD
  final String? phoneNumber; // [BARU]

  TeacherModel({
    required this.id,
    required this.name,
    required this.email,
    required this.schoolName,
    required this.className,
    this.schoolId, // <--- ADD TO CONSTRUCTOR
    this.phoneNumber, // <--- ADD TO CONSTRUCTOR
  });

  factory TeacherModel.fromJson(Map<String, dynamic> json) {
    final school = json['schools'] != null
        ? json['schools']['name']
        : 'Belum ditentukan';
    return TeacherModel(
      id: json['id'].toString(),
      name: json['full_name'] ?? 'Tanpa Nama',
      email: json['email'] ?? '-',
      schoolName: school,
      className: json['class_name'] ?? '-',
      schoolId: json['school_id']?.toString(), // <--- PASTI INI ADA
      phoneNumber: json['phone_number'] ?? json['phone'],
    );
  }
}

class TeacherService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL LIST WALI KELAS
  Future<List<TeacherModel>> getMyTeachers() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];
      final response = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, class_name, school_id, schools(name), phone_number', // <--- PASTIKAN 'school_id' ADA DI SINI
          )
          .eq('sppg_id', mySppgId)
          .eq('role', 'walikelas');

      final List<dynamic> data = response;
      return data.map((json) => TeacherModel.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal ambil data wali kelas: $e');
    }
  }

  // 2. BUAT AKUN WALI KELAS
  Future<void> createTeacherAccount({
    required String email,
    required String password,
    required String fullName,
    required String schoolId,
    required String className, // Input Baru
    required String phoneNumber, // [BARU] Terima nomor telepon
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

      // A. Request Signup
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
        if (newUserId == null) throw Exception("Gagal dapat ID User.");

        // B. Simpan ke Profiles
        await _supabase.from('profiles').insert({
          'id': newUserId,
          'full_name': fullName,
          'email': email.trim(),
          'role': 'walikelas',
          'sppg_id': mySppgId,
          'school_id': schoolId,
          'class_name': className,
          'phone_number': phoneNumber, // [BARU] Simpan nomor telepon
        });
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['msg'] ?? 'Gagal mendaftar');
      }
    } catch (e) {
      if (e.toString().contains("User already registered")) {
        throw Exception("Email sudah terdaftar!");
      }
      throw Exception('Gagal buat akun: $e');
    }
  }

  // [BARU] 3. UPDATE AKUN WALI KELAS
  Future<void> updateTeacherAccount(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Update data di tabel profiles
      await _supabase.from('profiles').update(data).eq('id', userId);
    } catch (e) {
      throw Exception('Gagal update akun wali kelas: $e');
    }
  }

  // [BARU] 4. HAPUS AKUN WALI KELAS (Delete Auth User)
  Future<void> deleteTeacherAccount(String userId) async {
    try {
      // Hapus akun dari Auth.users. Ini akan otomatis menghapus dari profiles.
      await _supabase.rpc(
        'delete_user_and_profile',
        params: {'user_id_input': userId},
      );
    } catch (e) {
      throw Exception('Gagal hapus akun wali kelas: $e');
    }
  }
}
