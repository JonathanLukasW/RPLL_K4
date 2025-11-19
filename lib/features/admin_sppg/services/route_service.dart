import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart'; // Kita butuh model sekolah

class RouteService {
  final _supabase = Supabase.instance.client;

  // --- 1. BUAT RUTE BARU (HEADER + DETAIL) ---
  Future<void> createRoute({
    required String vehicleId,
    required String courierId,
    required DateTime date,
    required List<School> selectedSchools, // Daftar sekolah yg dipilih
  }) async {
    try {
      // A. Ambil SPPG ID Admin
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // B. Insert Header (Tabel delivery_routes)
      // .select() di akhir penting biar kita dapet balikan ID-nya
      final routeResponse = await _supabase.from('delivery_routes').insert({
        'date': date.toIso8601String().split('T')[0], // Format YYYY-MM-DD
        'sppg_id': mySppgId,
        'vehicle_id': vehicleId,
        'courier_id': courierId,
        'status': 'pending', // Status awal
      }).select().single();

      final String newRouteId = routeResponse['id'];

      // C. Siapkan Data Stops (Detail Sekolah)
      // Kita urutkan sequence berdasarkan urutan pemilihan dulu (1, 2, 3...)
      // Nanti kalau pake VRP canggih, urutannya dihitung komputer.
      List<Map<String, dynamic>> stopsData = [];
      
      for (int i = 0; i < selectedSchools.length; i++) {
        stopsData.add({
          'route_id': newRouteId,
          'school_id': selectedSchools[i].id,
          'sequence_order': i + 1, // Urutan kunjungan
          'status': 'pending',
        });
      }

      // D. Insert Bulk (Sekaligus Banyak) ke delivery_stops
      await _supabase.from('delivery_stops').insert(stopsData);

    } catch (e) {
      throw Exception("Gagal membuat rute: $e");
    }
  }

  // --- 2. AMBIL DAFTAR RUTE (HISTORY) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      // Kita ambil data rute DAN join ke tabel vehicles & profiles
      // Biar kita tau plat nomor & nama kurir, bukan cuma ID doang.
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception("Gagal ambil data rute: $e");
    }
  }
}