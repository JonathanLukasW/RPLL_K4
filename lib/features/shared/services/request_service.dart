import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../admin_sppg/services/schedule_service.dart';

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
  final ScheduleService _scheduleService = ScheduleService();

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
    String?
    notes, // Catatan User (sekarang berisi summary REQ_TYPE: VALUE | Note: ...)
    required List<RequestDetail> details, // Detail Perubahan
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('school_id, sppg_id')
          .eq('id', userId)
          .single();

      // Kita anggap 'notes' yang masuk ke sini adalah data yang sudah diolah di screen (REQ_JADWAL:...)
      String summaryData = notes ?? "";

      await _supabase.from('change_requests').insert({
        'requester_id': userId,
        'school_id': profile['school_id'],
        'sppg_id': profile['sppg_id'],
        'request_type': type,
        'old_notes': summaryData, // <-- Data KOTOR/HACK disimpan di sini
        'status': 'pending',
      });

      // NOTE: Logika INSERT ke change_request_details DITIADAKAN untuk mengikuti hack notes
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

  // --- 4. ADMIN: RESPON & APPLY CHANGES (FINAL FIX for Routine Schedule) ---
  Future<void> respondRequest({
    required String requestId,
    required String status,
    required String adminNote,
    required ChangeRequestModel requestData,
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

      // 2. JIKA APPROVED -> APPLY CHANGES
      if (status == 'approved') {
        final String schoolId = requestData.schoolId;
        final String notes = requestData.oldNotes; // <-- Data Hack ada di sini

        // --- A. PERUBAHAN MENU: Update schools.menu_default ---
        if (requestData.type == 'Perubahan Menu') {
          if (notes.contains("REQ_MENU:")) {
            final rawMenuNames = notes
                .split('|')[0]
                .replaceAll("REQ_MENU:", "")
                .trim();
            await _supabase
                .from('schools')
                .update({'menu_default': rawMenuNames})
                .eq('id', schoolId);
          }
        }
        // --- B. TAMBAH/KURANG PORSI: Update schools.student_count ---
        else if (requestData.type == 'Tambah/Kurang Porsi') {
          if (notes.contains("REQ_PORSI:")) {
            final rawQty = notes
                .split('|')[0]
                .replaceAll("REQ_PORSI:", "")
                .trim();
            final int newQty = int.tryParse(rawQty) ?? 0;
            if (newQty > 0) {
              await _supabase
                  .from('schools')
                  .update({'student_count': newQty})
                  .eq('id', schoolId);
            }
          }
        }
        // --- C. PERUBAHAN JADWAL: Update Permanent Routine Schedule & Tolerance ---
        else if (requestData.type == 'Perubahan Jadwal') {
          if (notes.contains("REQ_JADWAL:")) {
            // 1. Ambil JSON Schedule String (sampai ketemu '|')
            final rawSchedulePart = notes
                .split('|')[0]
                .replaceAll("REQ_JADWAL:", "")
                .trim();

            // 2. Ambil Tolerance
            final rawTolerancePart = notes
                .split('|')[1]
                .replaceAll("REQ_TOLERANCE:", "")
                .trim();
            final int newTolerance = int.tryParse(rawTolerancePart) ?? 45;

            // 3. Update DB
            await _supabase
                .from('schools')
                .update({
                  'deadline_time':
                      rawSchedulePart, // <-- Storing the FULL JSON Schedule here
                  'tolerance_minutes': newTolerance,
                })
                .eq('id', schoolId);
          }
        }
      }
    } catch (e) {
      throw Exception("Gagal respon request dan menerapkan perubahan: $e");
    }
  }

  // --- 5. KOORDINATOR: BATALKAN PENGAJUAN ---
  Future<void> cancelRequest(String requestId) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('change_requests')
          .update({
            'status': 'cancelled',
            'admin_response': 'Cancelled by Coordinator/User',
          })
          .eq('id', requestId)
          .eq('requester_id', userId)
          .eq('status', 'pending')
          .select();

      if ((response as List).isEmpty) {
        throw Exception("Pengajuan tidak ditemukan, atau sudah diproses.");
      }
    } catch (e) {
      throw Exception('Gagal membatalkan pengajuan: $e');
    }
  }
}
