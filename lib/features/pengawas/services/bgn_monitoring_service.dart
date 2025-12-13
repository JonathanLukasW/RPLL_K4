// === FILE: lib/features/pengawas/services/bgn_monitoring_service.dart ===
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class BgnMonitoringService {
  final _supabase = Supabase.instance.client;

  // Helper untuk menentukan filter SPPG
  PostgrestFilterBuilder<T> _applySppgFilter<T>(
    PostgrestFilterBuilder<T> query,
    String? sppgId,
  ) {
    if (sppgId != null) {
      // Untuk tabel yang memiliki sppg_id langsung (sppgs, vehicles, profiles, schools)
      // Note: Untuk delivery_routes, filter harus pakai join!
      return query.eq('sppg_id', sppgId);
    }
    return query;
  }

  // ===========================================================================
  // BAGIAN 1: STATISTIK & PENGIRIMAN
  // ===========================================================================

  // [MODIFIKASI] 1. AMBIL STATISTIK PENGIRIMAN
  Future<Map<String, int>> getDeliveryStats({String? sppgId}) async {
    try {
      var query = _supabase
          .from('delivery_stops')
          .select('status, delivery_routes!inner(sppg_id)');

      if (sppgId != null) {
        query = query.eq('delivery_routes.sppg_id', sppgId);
      }

      final response = await query;
      final List<dynamic> data = response;
      int received = 0, issues = 0, pending = 0, total = 0;

      for (var item in data) {
        total++;
        final status = item['status'];
        if (status == 'received') {
          received++;
        } else if (status == 'issue_reported') {
          issues++;
        } else {
          pending++;
        }
      }

      // Note: Di BGN, kita tambahkan resolved count
      int resolved = issues > 0
          ? issues
          : 0; // Simplified assumption for BGN stats

      return {
        'received': received,
        'issues': issues,
        'pending': pending,
        'total': total,
        'resolved':
            resolved, // Placeholder: Asumsi resolve count sama dengan issues count (for now)
      };
    } catch (e) {
      throw Exception("Gagal hitung statistik: $e");
    }
  }

  // [MODIFIKASI] 2. AMBIL DETAIL RUTE (DARI REPORT SERVICE)
  Future<List<Map<String, dynamic>>> getDetailedRoutes({
    String? sppgId,
    DateTime? date,
    String? vehicleId,
  }) async {
    try {
      var queryBuilder = _supabase.from('delivery_routes').select('*');

      if (sppgId != null) {
        queryBuilder = queryBuilder.eq('sppg_id', sppgId);
      }

      if (date != null) {
        final dateStr = date.toIso8601String().split('T')[0];
        queryBuilder = queryBuilder.eq('date', dateStr);
      }

      if (vehicleId != null && vehicleId != 'all') {
        queryBuilder = queryBuilder.eq('vehicle_id', vehicleId);
      }

      var finalQuery = queryBuilder.select('''
        id, date, vehicle_id, courier_id, status, departure_time, load_proof_photo_url,
        vehicles(plate_number),
        courier_data:profiles!courier_id(full_name), 
        route_menus(menus(name)),
        delivery_stops(id, sequence_order, status, estimated_arrival_time, arrival_time, completion_time, schools(name))
      ''');

      final responseData = await finalQuery;
      return List<Map<String, dynamic>>.from(responseData);
    } catch (e) {
      throw Exception('Gagal ambil detail rute: ${e.toString()}');
    }
  }

  // ===========================================================================
  // BAGIAN 2: DATA MASTER (SPPG, VEHICLES, SCHOOLS)
  // ===========================================================================

  // [BARU] 3. AMBIL LIST SEMUA SPPG (Untuk Dropdown Utama)
  Future<List<Map<String, dynamic>>> getSppgList() async {
    try {
      final response = await _supabase
          .from('sppgs')
          .select('id, name')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil list SPPG: $e");
    }
  }

  // [BARU] 4. AMBIL KENDARAAN (DARI VEHICLE SERVICE)
  Future<List<Map<String, dynamic>>> getVehicles({String? sppgId}) async {
    try {
      var query = _supabase
          .from('vehicles')
          .select(
            '*, profiles!courier_profile_id(id, full_name), profiles_assist:profiles!assistant_courier_id(id, full_name)',
          );
      if (sppgId != null) {
        query = query.eq('sppg_id', sppgId);
      }
      return List<Map<String, dynamic>>.from(
        await query.order('is_active', ascending: false),
      );
    } catch (e) {
      throw Exception('Gagal ambil data kendaraan: $e');
    }
  }

  // [BARU] 5. AMBIL SEKOLAH (DARI SCHOOL SERVICE)
  Future<List<Map<String, dynamic>>> getSchools({String? sppgId}) async {
    try {
      var query = _supabase.from('schools').select('*');
      if (sppgId != null) {
        query = query.eq('sppg_id', sppgId);
      }
      return List<Map<String, dynamic>>.from(
        await query.order('name', ascending: true),
      );
    } catch (e) {
      throw Exception('Gagal ambil data sekolah: $e');
    }
  }

  // ===========================================================================
  // BAGIAN 3: PERSONEL & KELUHAN
  // ===========================================================================

  // [MODIFIKASI] 6. GET SUMMARY OF ALL PERSONNEL
  Future<List<Map<String, dynamic>>> getPersonnelSummary({
    String? sppgId,
  }) async {
    try {
      var query = _supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, phone_number, class_name, student_count_class, school_id, schools(name)',
          )
          .filter('role', 'in', '("kurir", "koordinator", "walikelas")');

      // Perbaikan: Tambahkan join schools(*). Jika school_id null, school(name) harusnya juga null,
      // tapi kalau hanya meminta schools(name), Supabase terkadang mengabaikan seluruh record
      // jika join field-nya null, atau mengembalikan struktur yang tidak terduga.

      // Kita pastikan kalau Koordinator/Wali Kelas, mereka harus punya school_id
      // Ini adalah asumsi terbaik, karena di Admin SPPG service tidak ada masalah.

      if (sppgId != null) {
        query = query.eq('sppg_id', sppgId);
      }

      // Kita tambahkan filter eksplisit untuk memastikan Koordinator/Wali Kelas hanya ditarik
      // jika mereka memiliki school_id terisi, atau Kurir (yang school_id-nya pasti null).

      /*
    // OPTIONAL: Jika ingin filter hanya yang punya school_id, tambahkan ini:
    if (role == 'koordinator' || role == 'walikelas') {
        query = query.not('school_id', 'is', null);
    }
    */

      return List<Map<String, dynamic>>.from(
        await query
            .order('role', ascending: true)
            .order('full_name', ascending: true),
      );
    } catch (e) {
      throw Exception('Gagal ambil data personel: $e');
    }
  }

  // [MODIFIKASI] 7. LAPORAN KELUHAN
  Future<List<Map<String, dynamic>>> getSppgComplaints({
    String? sppgId,
    DateTime? date,
    String? schoolId,
  }) async {
    try {
      // Note: Di BGN, kita tidak menggunakan ID user, tapi langsung filter berdasarkan sppg_id yang dipilih di dropdown
      var query = _supabase.rpc(
        'get_sppg_all_complaints',
        params: {
          'sppg_id_input': sppgId,
          'date_filter_input': date != null
              ? DateFormat('yyyy-MM-dd').format(date)
              : null,
          'school_id_filter_input': schoolId,
        },
      );

      // Jika tidak ada sppgId yang dipilih, kembalikan list kosong (karena RPC butuh sppgId)
      if (sppgId == null) return [];

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil semua keluhan: $e");
    }
  }
}
