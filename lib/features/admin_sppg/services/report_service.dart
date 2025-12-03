// === FILE: lib/features/admin_sppg/services/report_service.dart ===
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminReportService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    if (profile['sppg_id'] == null)
      throw Exception("User profile missing SPPG ID.");
    return profile['sppg_id'];
  }

  // 1. GET SUMMARY OF ALL PERSONNEL (Kurir, Koord, Wali Kelas)
  Future<List<Map<String, dynamic>>> getPersonnelSummary() async {
    try {
      final mySppgId = await _getMySppgId();

      final response = await _supabase
          .from('profiles')
          .select('id, full_name, email, role, school_id, schools(name)')
          .eq('sppg_id', mySppgId)
          // FIX KRITIS: Ganti .in_() yang gagal di PostgrestFilterBuilder
          // menjadi .filter() yang universal untuk operator 'in'.
          .filter('role', 'in', ['kurir', 'koordinator', 'walikelas'])
          .order('role', ascending: true)
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal ambil data personel: $e');
    }
  }

  // 2. GET ALL ACTIVE & HISTORY ROUTES WITH DETAILS (for Maps & History Tab)
  Future<List<Map<String, dynamic>>> getDetailedRoutes() async {
    try {
      final mySppgId = await _getMySppgId();

      final response = await _supabase
          .from('delivery_routes')
          .select('''
            *,
            vehicles(plate_number, driver_name),
            profiles!courier_id(full_name),
            delivery_stops(*, schools(name, student_count, deadline_time, tolerance_minutes, is_high_risk)),
            route_menus(menus(name))
          ''')
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal ambil detail rute: $e');
    }
  }

  // 3. GET COMPLAINTS (Koordinator & Wali Kelas) - Reuse existing logic
  // (We'll rely on ComplaintService for this part, but ensuring the tab exists)
}
