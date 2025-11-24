import 'package:supabase_flutter/supabase_flutter.dart';

class StatsService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
    return profile['sppg_id'];
  }

  // Hitung status pengiriman (Sukses vs Masalah vs Pending)
  Future<Map<String, int>> getDeliveryStats() async {
    try {
      final mySppgId = await _getMySppgId();

      // Ambil semua data stops yang terkait dengan SPPG ini
      // Join: delivery_routes -> filter SPPG
      final response = await _supabase
          .from('delivery_stops')
          .select('status, delivery_routes!inner(sppg_id)')
          .eq('delivery_routes.sppg_id', mySppgId);

      final List<dynamic> data = response;

      int received = 0; // Sukses
      int issues = 0;   // Masalah
      int pending = 0;  // Belum selesai

      for (var item in data) {
        final status = item['status'];
        if (status == 'received') {
          received++;
        } else if (status == 'issue_reported') {
          issues++;
        } else {
          pending++; // pending, active, completed (belum confirm)
        }
      }

      return {
        'received': received,
        'issues': issues,
        'pending': pending,
        'total': data.length,
      };

    } catch (e) {
      throw Exception("Gagal hitung statistik: $e");
    }
  }
}