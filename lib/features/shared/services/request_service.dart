import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import '../../admin_sppg/services/schedule_service.dart';
// [BARU] Import service Menu untuk akses Menu Sets
import '../../admin_sppg/services/menu_service.dart';

// [FIX KRITIS 1]: Import Menu Model yang Hilang
import '../../../models/menu_model.dart'; // <--- HARUS ADA
import '../../admin_sppg/services/menu_service.dart'; // <-- Tipe AdminMenuSetModel ada di sini, tapi kita harus pastikan MenuModel juga ada

import 'package:collection/collection.dart';

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
  final MenuService _menuService = MenuService(); // <-- BARU
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

  // [BARU] 0B. Ambil List Menu Set (Dipanggil Koordinator)
  Future<List<AdminMenuSetModel>> getMyMenuSets() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    final String mySppgId = profile['sppg_id'];

    // Query sama seperti di MenuService.getMyMenuSets
    final response = await _supabase
        .from('menu_sets')
        .select(
          '*, karbo_menus:karbo_id(name), protein_menus:protein_id(name), sayur_menus:sayur_id(name), buah_menus:buah_id(name), nabati_menus:nabati_id(name), pelengkap_menus:pelengkap_id(name), total_energy, total_protein, total_fat, total_carbs',
        )
        .eq('sppg_id', mySppgId)
        .order('set_name', ascending: true);

    return (response as List)
        .map((json) => AdminMenuSetModel.fromJson(json))
        .toList();
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
        final String notes = requestData.oldNotes;
        // --- C. PERUBAHAN MENU: Ganti Set Menu (Bisa Set Lama atau Set Baru) ---
        if (requestData.type == 'Perubahan Menu') {
          // a) LOGIC UNTUK MENU SET BARU (CUSTOM)
          if (notes.contains("REQ_MENU_SET_CUSTOM:")) {
            // 1. Ekstrak data
            final rawMenuIdsPart = notes
                .split('|')[0]
                .replaceAll("REQ_MENU_SET_CUSTOM:", "")
                .trim();
            final newNamePart = notes
                .split('|')[1]
                .replaceAll("NEW_NAME:", "")
                .trim();
            final Map<String, dynamic> customIds = jsonDecode(rawMenuIdsPart);

            // 2. Hitung Total Gizi dari Menu Item ID yang dipilih
            final Map<String, double> totals = {
              'total_energy': 0,
              'total_protein': 0.0,
              'total_fat': 0.0,
              'total_carbs': 0.0,
            };
            final List<Menu> allMenus = await _menuService.getMyMenus();

            for (var id in customIds.values) {
              if (id != null) {
                final menu = allMenus.firstWhereOrNull((m) => m.id == id);
                if (menu != null) {
                  totals['total_energy'] =
                      totals['total_energy']! + menu.energy.toDouble();
                  totals['total_protein'] =
                      totals['total_protein']! + menu.protein;
                  totals['total_fat'] = totals['total_fat']! + menu.fat;
                  totals['total_carbs'] = totals['total_carbs']! + menu.carbs;
                }
              }
            }

            // 3. Buat Menu Set Baru di DB
            final Map<String, dynamic> newSetData = {
              'set_name': newNamePart,
              'karbo_id': customIds['Karbo'],
              'protein_id': customIds['Lauk Protein'],
              'sayur_id': customIds['Sayur'],
              'buah_id': customIds['Buah'],
              'nabati_id': customIds['Lauk Nabati'],
              'pelengkap_id': customIds['Pelengkap'],
              'total_energy': totals['total_energy']!.toInt(),
              'total_protein': totals['total_protein'],
              'total_fat': totals['total_fat'],
              'total_carbs': totals['total_carbs'],
            };
            await _menuService.createMenuSet(newSetData); // <-- Buat set baru

            // 4. Update Sekolah menggunakan Nama Set Baru
            await _supabase
                .from('schools')
                .update({
                  'menu_default': newNamePart, // <-- Gunakan nama set baru
                })
                .eq('id', schoolId);
          }
          // b) LOGIC UNTUK PILIH SET LAMA
          else if (notes.contains("REQ_MENU_SET_ID:")) {
            // Ambil nama set baru yang dipilih Koordinator
            final newNamePart = notes
                .split('|')[2]
                .replaceAll("NEW_NAME:", "")
                .trim();

            // Update Sekolah menggunakan Nama Set yang sudah ada
            await _supabase
                .from('schools')
                .update({'menu_default': newNamePart})
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
