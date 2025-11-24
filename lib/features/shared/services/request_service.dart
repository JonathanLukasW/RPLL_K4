import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ChangeRequestModel {
  final String id;
  final String type; // schedule, menu, portion
  final String details;
  final String status; // pending, approved, rejected
  final String? adminResponse;
  final String requestDate;
  final String schoolName; // Nama Sekolah pengirim

  ChangeRequestModel({
    required this.id,
    required this.type,
    required this.details,
    required this.status,
    this.adminResponse,
    required this.requestDate,
    required this.schoolName,
  });

  factory ChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return ChangeRequestModel(
      id: json['id'].toString(),
      type: json['request_type'] ?? '-',
      details: json['details'] ?? '-',
      status: json['status'] ?? 'pending',
      adminResponse: json['admin_response'],
      requestDate: DateFormat('dd MMM yyyy').format(DateTime.parse(json['created_at'])),
      schoolName: json['schools'] != null ? json['schools']['name'] : 'Sekolah',
    );
  }
}

class RequestService {
  final _supabase = Supabase.instance.client;

  // --- 1. KOORDINATOR: KIRIM REQUEST ---
  Future<void> submitRequest({
    required String type,
    required String details,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Cari Info Sekolah & SPPG Koordinator
      final profile = await _supabase.from('profiles')
          .select('school_id, sppg_id')
          .eq('id', userId)
          .single();
      
      await _supabase.from('change_requests').insert({
        'requester_id': userId,
        'school_id': profile['school_id'],
        'sppg_id': profile['sppg_id'],
        'request_type': type,
        'details': details,
        'status': 'pending',
      });
    } catch (e) {
      throw Exception("Gagal kirim request: $e");
    }
  }

  // --- 2. KOORDINATOR: LIHAT HISTORY REQUEST SAYA ---
  Future<List<ChangeRequestModel>> getMyRequests() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('change_requests')
        .select('*, schools(name)')
        .eq('requester_id', userId)
        .order('created_at', ascending: false);
        
    final List<dynamic> data = response;
    return data.map((json) => ChangeRequestModel.fromJson(json)).toList();
  }

  // --- 3. ADMIN: LIHAT SEMUA REQUEST MASUK (INBOX) ---
  Future<List<ChangeRequestModel>> getIncomingRequests() async {
    final userId = _supabase.auth.currentUser!.id;
    // Cari SPPG ID Admin
    final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
    final mySppgId = profile['sppg_id'];

    final response = await _supabase
        .from('change_requests')
        .select('*, schools(name)')
        .eq('sppg_id', mySppgId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response;
    return data.map((json) => ChangeRequestModel.fromJson(json)).toList();
  }

  // --- 4. ADMIN: RESPON REQUEST (TERIMA/TOLAK) ---
  Future<void> respondRequest(String id, String status, String responseText) async {
    await _supabase.from('change_requests').update({
      'status': status,
      'admin_response': responseText,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}