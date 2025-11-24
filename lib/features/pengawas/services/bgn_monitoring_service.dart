import 'package:supabase_flutter/supabase_flutter.dart';

class BgnMonitoringService {
  final _supabase = Supabase.instance.client;

  // 1. AMBIL SEMUA MASALAH DARI KOORDINATOR (GLOBAL)
  Future<List<Map<String, dynamic>>> getGlobalCoordinatorComplaints() async {
    try {
      // Ambil delivery_stops yang statusnya 'issue_reported'
      // Join: schools (nama sekolah), delivery_routes -> sppgs (nama dapur)
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name), delivery_routes!inner(date, sppgs(name))')
          .eq('status', 'issue_reported') // Ambil yang lapor masalah
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil data BGN (Koordinator): $e");
    }
  }

  // 2. AMBIL SEMUA MASALAH DARI WALI KELAS (GLOBAL)
  Future<List<Map<String, dynamic>>> getGlobalTeacherComplaints() async {
    try {
      // Join: delivery_stops -> delivery_routes -> sppgs
      final response = await _supabase
          .from('class_receptions')
          .select('*, delivery_stops!inner(schools(name), delivery_routes!inner(sppgs(name)))')
          .not('issue_type', 'is', null) // Ambil yang ada isunya
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil data BGN (Wali Kelas): $e");
    }
  }

  // 3. AMBIL DATA STATISTIK NASIONAL
  Future<Map<String, int>> getGlobalStats() async {
    try {
      // Ambil semua status pengiriman
      final response = await _supabase.from('delivery_stops').select('status');
      final List<dynamic> data = response;

      int received = 0;
      int issues = 0;
      int pending = 0;

      for (var item in data) {
        final status = item['status'];
        if (status == 'received') received++;
        else if (status == 'issue_reported') issues++;
        else pending++;
      }

      return {
        'received': received,
        'issues': issues,
        'pending': pending,
        'total': data.length,
      };
    } catch (e) {
      throw Exception("Gagal hitung statistik BGN: $e");
    }
  }

  // 4. AMBIL LOKASI SEMUA SPPG (Untuk Peta Sebaran)
  Future<List<Map<String, dynamic>>> getAllSppgLocations() async {
    try {
      final response = await _supabase
          .from('sppgs')
          .select('id, name, address, gps_lat, gps_long');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil lokasi SPPG: $e");
    }
  }

  Future<Map<String, int>> getSppgStats(String sppgId) async {
    try {
      // Join: delivery_routes -> filter by sppg_id
      final response = await _supabase
          .from('delivery_stops')
          .select('status, delivery_routes!inner(sppg_id)')
          .eq('delivery_routes.sppg_id', sppgId);

      final List<dynamic> data = response;
      int received = 0, issues = 0, pending = 0;

      for (var item in data) {
        final status = item['status'];
        if (status == 'received') received++;
        else if (status == 'issue_reported') issues++;
        else pending++;
      }

      return {
        'received': received,
        'issues': issues,
        'pending': pending,
        'total': data.length,
      };
    } catch (e) {
      throw Exception("Gagal hitung statistik SPPG: $e");
    }
  }
  
  // [BARU] 6. AMBIL LIST SEMUA SPPG (Untuk Dropdown/List Pilihan)
  Future<List<Map<String, dynamic>>> getSppgList() async {
      final response = await _supabase.from('sppgs').select('id, name');
      return List<Map<String, dynamic>>.from(response);
  }
}