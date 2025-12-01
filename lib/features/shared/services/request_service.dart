import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

// Model untuk Detail Request
class RequestDetail {
  final String menuId;
  final String menuName;
  final int newQuantity;
  final TimeOfDay? newTime;
  final DateTime? newDate;
  final String? proposedMenuNames; // Untuk Change Menu Set

  RequestDetail({
    required this.menuId,
    required this.menuName,
    this.newQuantity = 0,
    this.newTime,
    this.newDate,
    this.proposedMenuNames,
  });
}

class ChangeRequestModel {
  final String id;
  final String
  type; // 'Perubahan Jadwal', 'Perubahan Menu', 'Tambah/Kurang Porsi'
  final String oldNotes; // Kita pakai ini untuk deskripsi singkat / JSON string
  final String status; // pending, approved, rejected
  final String? adminResponse;
  final String requestDate;
  final String schoolName;
  final String schoolId; // Butuh ini buat update data sekolah pas approve

  // Data detail (parsed)
  final int? newQuantity;
  final String? newDateStr;

  ChangeRequestModel({
    required this.id,
    required this.type,
    required this.oldNotes,
    required this.status,
    this.adminResponse,
    required this.requestDate,
    required this.schoolName,
    required this.schoolId,
    this.newQuantity,
    this.newDateStr,
  });

  factory ChangeRequestModel.fromJson(Map<String, dynamic> json) {
    // Coba ambil detail dari relasi (jika ada)
    // Supabase join response structure might vary, simplified here:
    int? qty;
    String? dateStr;

    // Logic extraction kasar karena keterbatasan schema
    // Idealnya ambil dari tabel detail, tapi untuk list view kita bisa taruh di notes/metadata

    return ChangeRequestModel(
      id: json['id'].toString(),
      type: json['request_type'] ?? '-',
      oldNotes: json['old_notes'] ?? '-',
      status: json['status'] ?? 'pending',
      adminResponse: json['admin_response'],
      requestDate: DateFormat(
        'dd MMM HH:mm',
      ).format(DateTime.parse(json['created_at'])),
      schoolName: json['schools'] != null ? json['schools']['name'] : 'Sekolah',
      schoolId: json['school_id'].toString(),
    );
  }
}

class RequestService {
  final _supabase = Supabase.instance.client;

  // 0. AMBIL MENU SPPG (Untuk Dropdown)
  Future<List<Map<String, dynamic>>> getSppgMenus() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      // Get SPPG ID from profile (Coordinator)
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
    } catch (e) {
      throw Exception("Gagal ambil menu: $e");
    }
  }

  // [BARU] AMBIL DATA SEKOLAH SENDIRI (Untuk Default Values)
  Future<Map<String, dynamic>> getMySchoolDetails() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('school_id')
          .eq('id', userId)
          .single();
      final String? schoolId = profile['school_id'];

      if (schoolId == null) throw Exception("Akun tidak terhubung sekolah.");

      final school = await _supabase
          .from('schools')
          .select()
          .eq('id', schoolId)
          .single();
      return school; // Berisi student_count, deadline_time, tolerance_minutes, menu_default
    } catch (e) {
      throw Exception("Gagal load data sekolah: $e");
    }
  }

  // --- 1. KOORDINATOR: KIRIM REQUEST ---
  Future<void> submitStructuredRequest({
    required String type,
    String? notes, // Catatan User
    required List<RequestDetail> details, // Detail Perubahan
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('school_id, sppg_id')
          .eq('id', userId)
          .single();

      // Kita simpan summary perubahan di kolom 'old_notes' agar Admin bisa baca langsung
      // tanpa join ribet ke tabel detail (Hack cepat)
      String summaryData = notes ?? "";

      // Persiapkan data detail untuk tabel relasi
      // ... (Implementation optional dependent on your DB schema rigour)

      if (type == 'Perubahan Menu') {
        summaryData =
            "REQ_MENU: ${details.first.proposedMenuNames} | Note: $notes";
      } else if (type == 'Tambah/Kurang Porsi') {
        summaryData = "REQ_PORSI: ${details.first.newQuantity} | Note: $notes";
      } else if (type == 'Perubahan Jadwal') {
        // Format: REQ_JADWAL: YYYY-MM-DD HH:mm:ss
        String datePart = details.first.newDate!.toIso8601String().split(
          'T',
        )[0];
        String timePart =
            "${details.first.newTime!.hour}:${details.first.newTime!.minute}";
        summaryData = "REQ_JADWAL: $datePart $timePart | Note: $notes";
      }

      await _supabase.from('change_requests').insert({
        'requester_id': userId,
        'school_id': profile['school_id'],
        'sppg_id': profile['sppg_id'],
        'request_type': type,
        'old_notes': summaryData, // Simpan data inti di sini string-serialized
        'status': 'pending',
      });
    } catch (e) {
      throw Exception("Gagal kirim request: $e");
    }
  }

  // --- 2. GET HISTORY (User & Admin) ---
  Future<List<ChangeRequestModel>> getMyRequests() async {
    final userId = _supabase.auth.currentUser!.id;
    final response = await _supabase
        .from('change_requests')
        .select('*, schools(name)')
        .eq('requester_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => ChangeRequestModel.fromJson(json))
        .toList();
  }

  Future<List<ChangeRequestModel>> getIncomingRequests() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final response = await _supabase
        .from('change_requests')
        .select('*, schools(name)')
        .eq('sppg_id', profile['sppg_id'])
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => ChangeRequestModel.fromJson(json))
        .toList();
  }

  // --- 3. ADMIN: RESPON & APPLY CHANGES ---
  Future<void> respondRequest({
    required String requestId,
    required String status,
    required String adminNote,
    required ChangeRequestModel
    requestData, // Butuh data ini untuk tau apa yang diupdate
  }) async {
    try {
      // 1. Update Status Request
      await _supabase
          .from('change_requests')
          .update({
            'status': status,
            'admin_response': adminNote,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', requestId);

      // 2. JIKA APPROVED -> UPDATE DATA SEKOLAH (MASTER DATA)
      if (status == 'approved') {
        if (requestData.type == 'Perubahan Menu') {
          // Parse "REQ_MENU: Nasi, Ayam, Tahu..."
          if (requestData.oldNotes.contains("REQ_MENU:")) {
            final raw = requestData.oldNotes
                .split('|')[0]
                .replaceAll("REQ_MENU:", "")
                .trim();
            await _supabase
                .from('schools')
                .update({'menu_default': raw})
                .eq('id', requestData.schoolId);
          }
        } else if (requestData.type == 'Tambah/Kurang Porsi') {
          // Parse "REQ_PORSI: 500"
          if (requestData.oldNotes.contains("REQ_PORSI:")) {
            final raw = requestData.oldNotes
                .split('|')[0]
                .replaceAll("REQ_PORSI:", "")
                .trim();
            final int newQty = int.tryParse(raw) ?? 0;
            if (newQty > 0) {
              await _supabase
                  .from('schools')
                  .update({'student_count': newQty})
                  .eq('id', requestData.schoolId);
            }
          }
        }
        // Perubahan Jadwal biasanya bersifat One-Time (Jadwal Khusus) atau update Deadline.
        // Di sini kita asumsikan update Deadline jika formatnya pas, atau biarkan hanya sebagai notifikasi approved.
      }
    } catch (e) {
      throw Exception("Gagal respon request: $e");
    }
  }
}
