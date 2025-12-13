// === FILE: lib/features/admin_sppg/services/report_service.dart ===
import 'package:supabase_flutter/supabase_flutter.dart'; // Perlu pastikan ini diimpor dengan alias
import '../services/teacher_service.dart'; // Import TeacherModel
import '../services/coordinator_service.dart'; // Import CoordinatorModel

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

      // [FIX KRITIS FINAL]: Menggunakan .filter() dengan sintaks string SQL yang eksplisit
      // Ini memaksa PostgREST untuk mencari role yang cocok di dalam array literal.
      const String roleFilterString = '("kurir", "koordinator", "walikelas")';

      final response = await _supabase
          .from('profiles')
          .select(
            'id, full_name, email, role, phone_number, class_name, student_count_class, school_id, schools(name)',
          )
          .eq('sppg_id', mySppgId)
          .filter(
            'role',
            'in',
            roleFilterString,
          ) // <--- FIX AKHIR: Menggunakan filter string yang andal
          .order('role', ascending: true)
          .order('full_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Gagal ambil data personel: $e');
    }
  }

  // 2. GET ALL ACTIVE & HISTORY ROUTES WITH DETAILS (for Maps & History Tab)
  Future<List<Map<String, dynamic>>> getDetailedRoutes({
    DateTime? date,
    String? vehicleId,
    bool includeAllStatuses = false,
  }) async {
    try {
      final mySppgId = await _getMySppgId();

      var queryBuilder = _supabase
          .from('delivery_routes')
          .select('*')
          .eq('sppg_id', mySppgId);

      // Terapkan Filter Tanggal
      if (date != null) {
        final dateStr = date.toIso8601String().split('T')[0];
        queryBuilder = queryBuilder.eq('date', dateStr);
      }

      // Terapkan Filter Mobil
      if (vehicleId != null && vehicleId != 'all') {
        queryBuilder = queryBuilder.eq('vehicle_id', vehicleId);
      }

      // Menggunakan ALIAS BARU yang JELAS (Lebih aman)
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
}
// Tidak ada perubahan di statistics_screen.dart karena logika tampilan sudah benar, 
// hanya data yang hilang dari service.