import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart'; 

class RouteService {
  final _supabase = Supabase.instance.client;

  // --- 1. BUAT RUTE BARU (OLEH ADMIN SPPG) ---
  Future<void> createRoute({
    required String vehicleId,
    required String courierId,
    required DateTime date,
    required List<School> selectedSchools,
  }) async {
    try {
      // A. Ambil SPPG ID Admin yang sedang login
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // B. Insert Header (delivery_routes)
      final routeResponse = await _supabase.from('delivery_routes').insert({
        'date': date.toIso8601String().split('T')[0], // YYYY-MM-DD
        'sppg_id': mySppgId,
        'vehicle_id': vehicleId,
        'courier_id': courierId,
        'status': 'pending', 
      }).select().single();

      final String newRouteId = routeResponse['id'];

      // C. Siapkan & Insert Detail Perhentian (delivery_stops)
      List<Map<String, dynamic>> stopsData = [];
      
      for (int i = 0; i < selectedSchools.length; i++) {
        stopsData.add({
          'route_id': newRouteId,
          'school_id': selectedSchools[i].id,
          'sequence_order': i + 1, // Urutan default (tanpa optimasi VRP)
          'status': 'pending',
        });
      }

      await _supabase.from('delivery_stops').insert(stopsData);

    } catch (e) {
      throw Exception("Gagal membuat rute: $e");
    }
  }

  // --- 2. AMBIL DAFTAR RUTE (UNTUK ADMIN SPPG - HISTORY) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      // Ambil SPPG ID Admin
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      // Ambil semua rute milik SPPG ini, gabung dengan data plat & nama kurir
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception("Gagal mengambil data rute Admin: $e");
    }
  }

  // --- 3. AMBIL DAFTAR RUTE (UNTUK KURIR YANG SEDANG LOGIN) ---
  Future<List<DeliveryRoute>> getRoutesByCourier() async {
    try {
      // Ambil ID Kurir yang sedang login
      final currentCourierId = _supabase.auth.currentUser!.id;

      // Query ke delivery_routes, filter berdasarkan ID Kurir
      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('courier_id', currentCourierId) // FILTER PENTING
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
      
    } catch (e) {
      throw Exception("Gagal mengambil rute kurir: $e");
    }
  }
}