import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class RequestDetail {
  final String menuId;
  final String menuName;
  final int newQuantity;
  final TimeOfDay? newTime;
  final DateTime? newDate;

  RequestDetail({
    required this.menuId,
    required this.menuName,
    this.newQuantity = 0,
    this.newTime,
    this.newDate,
  });

  // Method untuk konversi TimeOfDay ke String HH:mm:ss
  String? formatTime() {
    if (newTime == null) return null;
    return "${newTime!.hour.toString().padLeft(2, '0')}:${newTime!.minute.toString().padLeft(2, '0')}:00";
  }
}

class ChangeRequestModel {
  final String id;
  final String type; // schedule, menu, portion
  final String oldNotes; // [UBAH] Ganti dari 'details' ke 'oldNotes'
  final String status; // pending, approved, rejected
  final String? adminResponse;
  final String requestDate;
  final String schoolName; // Nama Sekolah pengirim

  ChangeRequestModel({
    required this.id,
    required this.type,
    required this.oldNotes,
    required this.status,
    this.adminResponse,
    required this.requestDate,
    required this.schoolName,
  });

  factory ChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return ChangeRequestModel(
      id: json['id'].toString(),
      type: json['request_type'] ?? '-',
      oldNotes: json['old_notes'] ?? '-', // [UBAH] Ambil dari kolom baru
      status: json['status'] ?? 'pending',
      adminResponse: json['admin_response'],
      requestDate: DateFormat(
        'dd MMM yyyy',
      ).format(DateTime.parse(json['created_at'])),
      schoolName: json['schools'] != null ? json['schools']['name'] : 'Sekolah',
    );
  }
}

class RequestService {
  final _supabase = Supabase.instance.client;

  // [BARU] FUNGSI 0: Ambil Menu yang terdaftar di SPPG Koordinator
  Future<List<Map<String, dynamic>>> getSppgMenus() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];

    final response = await _supabase
        .from('menus')
        .select()
        .eq('sppg_id', mySppgId)
        .order('category', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  // --- 1. KOORDINATOR: KIRIM REQUEST (DENGAN DETAIL TERSTRUKTUR) ---
  Future<void> submitStructuredRequest({
    required String type,
    String? notes,
    required List<RequestDetail> details, // [BARU] List detail menu/jadwal
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Cari Info Sekolah & SPPG Koordinator
      final profile = await _supabase
          .from('profiles')
          .select('school_id, sppg_id')
          .eq('id', userId)
          .single();

      // A. Masukkan Request Utama
      final response = await _supabase
          .from('change_requests')
          .insert({
            'requester_id': userId,
            'school_id': profile['school_id'],
            'sppg_id': profile['sppg_id'],
            'request_type': type,
            'old_notes': notes, // [UBAH] Gunakan notes sebagai catatan umum
            'status': 'pending',
          })
          .select()
          .single(); // Wajib select() untuk ambil ID request yang baru

      final String newRequestId = response['id'];

      // B. Masukkan Detail ke Tabel change_request_details
      List<Map<String, dynamic>> detailData = [];
      for (var item in details) {
        detailData.add({
          'request_id': newRequestId,
          'menu_id': item.menuId,
          // Isi kolom berdasarkan tipe request yang dikirim
          if (type == 'Perubahan Jadwal') ...{
            'new_schedule_date': item.newDate!.toIso8601String().split('T')[0],
            'new_schedule_time': item.formatTime(),
          },
          if (type == 'Tambah/Kurang Porsi') 'new_quantity': item.newQuantity,

          // Kita asumsikan Perubahan Menu hanya dicatat di detail (tidak ada kolom spesifik di DB untuk "kombinasi")
          // Jika Perubahan Menu, kita kirim saja menuId yang baru dipilih
        });
      }

      if (detailData.isNotEmpty) {
        await _supabase.from('change_request_details').insert(detailData);
      }
    } catch (e) {
      throw Exception("Gagal kirim request terstruktur: $e");
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
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
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
  Future<void> respondRequest(
    String id,
    String status,
    String responseText,
  ) async {
    await _supabase
        .from('change_requests')
        .update({
          'status': status,
          'admin_response': responseText,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id);
  }
}
