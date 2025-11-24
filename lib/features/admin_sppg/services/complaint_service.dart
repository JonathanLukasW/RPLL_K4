import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ComplaintService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
    return profile['sppg_id'];
  }

  // 1. AMBIL MASALAH DARI KOORDINATOR (Kemasan/Jumlah)
  Future<List<Map<String, dynamic>>> getCoordinatorComplaints() async {
    final mySppgId = await _getMySppgId();
    
    // Ambil delivery_stops yang statusnya 'issue_reported'
    // Dan join ke sekolah untuk tau nama sekolahnya
    final response = await _supabase
        .from('delivery_stops')
        .select('*, schools(name), delivery_routes!inner(sppg_id)')
        .eq('delivery_routes.sppg_id', mySppgId)
        .eq('status', 'issue_reported')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 2. AMBIL MASALAH DARI WALI KELAS (Kualitas Makanan)
  Future<List<Map<String, dynamic>>> getTeacherComplaints() async {
    final mySppgId = await _getMySppgId();

    // Join class_receptions -> delivery_stops -> delivery_routes -> filter SPPG
    final response = await _supabase
        .from('class_receptions')
        .select('*, delivery_stops!inner(schools(name), delivery_routes!inner(sppg_id))')
        .eq('delivery_stops.delivery_routes.sppg_id', mySppgId)
        .not('issue_type', 'is', null) // Ambil yang issue_type nya TIDAK NULL
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  // 3. KIRIM INSTRUKSI (TINDAK LANJUT)
  Future<void> respondToComplaint({
    required String table, // 'delivery_stops' atau 'class_receptions'
    required String id,
    required String response,
  }) async {
    await _supabase.from(table).update({
      'admin_response': response,
      'resolved_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }
}