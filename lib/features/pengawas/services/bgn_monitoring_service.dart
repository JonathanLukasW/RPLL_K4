import 'package:supabase_flutter/supabase_flutter.dart';

class BgnMonitoringService {
  final _supabase = Supabase.instance.client;

  // ===========================================================================
  // BAGIAN 1: UNTUK SCREEN LAPORAN (BgnReportScreen)
  // ===========================================================================

  // 1. DATA HISTORY & BUKTI DIGITAL
  Future<List<Map<String, dynamic>>> getDeliveryHistory() async {
    try {
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name), delivery_routes!inner(date, sppgs(name))')
          // [FIX ERROR _in]: Kita pakai .filter() manual biar aman dari error syntax
          .filter('status', 'in', '("received","completed","issue_reported")') 
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil history: $e");
    }
  }

  // 2. JADWAL PENGIRIMAN SETIAP SPPG
  Future<List<Map<String, dynamic>>> getAllSchedules() async {
    try {
      final response = await _supabase
          .from('delivery_routes')
          .select('*, sppgs(name), vehicles(plate_number)')
          .gte('date', DateTime.now().toIso8601String().split('T')[0]) // Hari ini ke depan
          .order('date', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil jadwal: $e");
    }
  }

  // 3. LAPORAN KELUHAN SEMUA SPPG
  Future<List<Map<String, dynamic>>> getAllComplaints() async {
    try {
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name), delivery_routes!inner(sppgs(name))')
          .eq('status', 'issue_reported')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil keluhan: $e");
    }
  }

  // ===========================================================================
  // BAGIAN 2: UNTUK SCREEN STATISTIK (BgnStatisticsScreen)
  // ===========================================================================

  // 4. AMBIL LIST SEMUA SPPG (Untuk Dropdown)
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

  // 5. AMBIL STATISTIK SPESIFIK PER SPPG
  Future<Map<String, int>> getSppgStats(String sppgId) async {
    try {
      // Ambil data stops berdasarkan SPPG ID
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

  // ===========================================================================
  // BAGIAN 3: UNTUK SCREEN TRACKING PETA (BgnTrackingScreen)
  // ===========================================================================

  // 6. AMBIL LOKASI SEMUA SPPG
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
}