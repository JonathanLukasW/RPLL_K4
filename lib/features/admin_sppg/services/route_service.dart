import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart'; 
import 'dart:convert'; // Buat decode JSON dari OSRM
import 'package:http/http.dart' as http; // Buat request ke OSRM
import 'package:latlong2/latlong.dart'; // Buat tipe data LatLng

class RouteService {
  final _supabase = Supabase.instance.client;

  // --- 1. BUAT RUTE BARU ---
  Future<void> createRoute({
    required String vehicleId,
    required String courierId,
    required DateTime date,
    required List<School> selectedSchools,
  }) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      final routeResponse = await _supabase.from('delivery_routes').insert({
        'date': date.toIso8601String().split('T')[0], 
        'sppg_id': mySppgId,
        'vehicle_id': vehicleId,
        'courier_id': courierId,
        'status': 'pending', 
      }).select().single();

      final String newRouteId = routeResponse['id'];

      List<Map<String, dynamic>> stopsData = [];
      for (int i = 0; i < selectedSchools.length; i++) {
        stopsData.add({
          'route_id': newRouteId,
          'school_id': selectedSchools[i].id,
          'sequence_order': i + 1, 
          'status': 'pending',
        });
      }

      await _supabase.from('delivery_stops').insert(stopsData);

    } catch (e) {
      throw Exception("Gagal membuat rute: $e");
    }
  }

  // --- 2. AMBIL DAFTAR RUTE (ADMIN) ---
  Future<List<DeliveryRoute>> getMyRoutes() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
      final String mySppgId = profile['sppg_id'];

      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('sppg_id', mySppgId)
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil rute admin: $e");
    }
  }

  // --- 3. AMBIL DAFTAR RUTE (KURIR) ---
  Future<List<DeliveryRoute>> getRoutesByCourier() async {
    try {
      final currentCourierId = _supabase.auth.currentUser!.id;

      final response = await _supabase
          .from('delivery_routes')
          .select('*, vehicles(plate_number), profiles(full_name)') 
          .eq('courier_id', currentCourierId) 
          .order('date', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => DeliveryRoute.fromJson(json)).toList();
    } catch (e) {
      throw Exception("Gagal ambil rute kurir: $e");
    }
  }

  // --- 4. AMBIL DETAIL PERHENTIAN (STOPS) ---
  Future<List<Map<String, dynamic>>> getRouteStops(String routeId) async {
    try {
      final response = await _supabase
          .from('delivery_stops')
          .select('*, schools(name, address, gps_lat, gps_long, student_count, menu_default)')
          .eq('route_id', routeId)
          .order('sequence_order', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception("Gagal ambil detail stop: $e");
    }
  }

  // --- 5. UPDATE STATUS RUTE ---
  Future<void> updateRouteStatus(String routeId, String newStatus) async {
    try {
      await _supabase.from('delivery_routes').update({'status': newStatus}).eq('id', routeId);
    } catch (e) {
      throw Exception("Gagal update status rute: $e");
    }
  }

  // --- 6. UPDATE STATUS PERHENTIAN ---
  Future<void> updateStopStatus(String stopId, String newStatus) async {
    try {
      await _supabase.from('delivery_stops').update({
        'status': newStatus,
        'arrival_time': newStatus == 'completed' ? DateTime.now().toIso8601String() : null,
      }).eq('id', stopId);
    } catch (e) {
      throw Exception("Gagal update status stop: $e");
    }
  }

  // --- 7. AMBIL GARIS RUTE (POLYLINE) DARI OSRM ---
  Future<List<LatLng>> getRoutePolyline(List<LatLng> coordinates) async {
    print("OSRM Request: Mencoba hitung rute untuk ${coordinates.length} titik.");
    if (coordinates.length < 2) {
       return []; 
    }

    String coordString = coordinates
        .map((p) => "${p.longitude},${p.latitude}")
        .join(';');

    final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordString?overview=full&geometries=geojson');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['code'] != 'Ok') return [];

        final List<dynamic> coords = 
            data['routes'][0]['geometry']['coordinates'];
        
        return coords
            .map((c) => LatLng(c[1].toDouble(), c[0].toDouble()))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      print("OSRM Exception: $e");
      return [];
    }
  }

  // --- 8. AMBIL LOKASI DAPUR (SPPG) ---
  // Fungsi ini mencari koordinat SPPG milik user yang sedang login
  Future<LatLng?> getSppgLocation() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // 1. Cari SPPG ID dari Profile Kurir
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
          
      final String sppgId = profile['sppg_id'];

      // 2. Ambil Koordinat dari Tabel SPPG
      final sppgData = await _supabase
          .from('sppgs')
          .select('gps_lat, gps_long')
          .eq('id', sppgId)
          .single();

      if (sppgData['gps_lat'] != null && sppgData['gps_long'] != null) {
        return LatLng(
          double.parse(sppgData['gps_lat'].toString()),
          double.parse(sppgData['gps_long'].toString()),
        );
      }
      return null; 
    } catch (e) {
      print("Gagal ambil lokasi SPPG: $e");
      return null;
    }
  }
}