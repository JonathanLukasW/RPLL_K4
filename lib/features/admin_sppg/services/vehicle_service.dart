import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/vehicle_model.dart';

class VehicleService {
  final _supabase = Supabase.instance.client;
  // 1. AMBIL LIST TRANSPORTASI
  Future<List<Vehicle>> getMyVehicles() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();
      final String mySppgId = profile['sppg_id'];

      // [FIX KRITIS ALIAS PROFILES]:
      // Menggunakan nama relasi yang unik (courier_id_fk & assistant_id_fk)
      // yang mengarah ke kolom profiles. Kita beri nama baru untuk kolom yang kembali (profiles_main, profiles_assist)
      final response = await _supabase
          .from('vehicles')
          .select(
            '*, profiles!courier_profile_id(id, full_name), profiles_assist:profiles!assistant_courier_id(id, full_name)', // <-- FIX: Gunakan ALIAS profiles_assist
          )
          .eq('sppg_id', mySppgId)
          .order('is_active', ascending: false);

      final List<dynamic> data = response;
      return data.map((json) => Vehicle.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal ambil data transportasi: $e');
    }
  }

  // 2. TAMBAH TRANSPORTASI BARU
  Future<void> createVehicle(Map<String, dynamic> data) async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('sppg_id')
          .eq('id', userId)
          .single();

      // Inject ID SPPG otomatis
      data['sppg_id'] = profile['sppg_id'];
      await _supabase.from('vehicles').insert(data);
    } catch (e) {
      throw Exception('Gagal menambah transportasi: $e');
    }
  }

  // 3. UPDATE STATUS (Aktif/Nonaktif)
  Future<void> toggleStatus(String vehicleId, bool currentStatus) async {
    try {
      await _supabase
          .from('vehicles')
          .update({'is_active': !currentStatus})
          .eq('id', vehicleId);
    } catch (e) {
      throw Exception('Gagal update status: $e');
    }
  }

  Future<void> updateVehicle(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('vehicles').update(data).eq('id', id);
    } catch (e) {
      throw Exception('Gagal update kendaraan: $e');
    }
  }

  Future<void> deleteVehicle(String id) async {
    try {
      // Hapus kendaraan
      await _supabase.from('vehicles').delete().eq('id', id);
    } catch (e) {
      throw Exception('Gagal menghapus kendaraan: $e');
    }
  }
}
