import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/sppg_model.dart';

class SppgService {
  final _supabase = Supabase.instance.client;

  // 1. Ambil Semua Daftar SPPG
  Future<List<Sppg>> getAllSppgs() async {
    final response = await _supabase
        .from('sppgs')
        .select()
        .order('created_at'); // Urutkan dari yang terlama

    // Konversi data mentah list -> List<Sppg>
    return (response as List).map((e) => Sppg.fromJson(e)).toList();
  }

  // 2. Tambah SPPG Baru
  Future<void> createSppg(String name, String address) async {
    await _supabase.from('sppgs').insert({
      'name': name,
      'address': address,
      // Lat long bisa null dulu kalau belum ada peta
      'gps_lat': 0.0, 
      'gps_long': 0.0,
    });
  }
}