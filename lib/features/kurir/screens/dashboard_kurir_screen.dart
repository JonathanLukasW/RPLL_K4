import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import Service Rute (karena kita akan menampilkan Rute yang ditugaskan)
import '../../admin_sppg/services/route_service.dart';
import '../../autentikasi/screens/login_screen.dart'; 
import '../../../models/route_model.dart';

class DashboardKurirScreen extends StatelessWidget {
  const DashboardKurirScreen({super.key});

  // Fungsi Logout Kurir
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- LOGIKA AMBIL RUTE KURIR ---
  // Kita perlu service baru atau modifikasi service lama. 
  // Untuk sementara, kita pakai logic sederhana dulu.
  Future<List<DeliveryRoute>> _fetchMyRoutes() async {
    // Kurir hanya melihat rute miliknya sendiri (courier_id = auth.uid)
    final userId = Supabase.instance.client.auth.currentUser!.id;

    // Pakai fungsi getMyRoutes yang sudah kita buat, TAPI tambahkan filter
    // Catatan: Ini perlu modifikasi di RouteService agar bisa menerima filter, 
    // tapi untuk sementara kita coba pakai fungsi getMyRoutes yang ada dulu
    // (di mana Admin SPPG dan Kurir bisa melihat semua data milik SPPG mereka).
    // KITA AKAN MODIFIKASI ROUTE SERVICE DI LANGKAH 3.
    
    // Untuk saat ini, kita tampilkan placeholder list dulu
    await Future.delayed(const Duration(milliseconds: 500));
    return []; 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Pengiriman"),
        backgroundColor: Colors.blue[800], // Warna Biru, beda dari Admin
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.motorcycle, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text(
              "Selamat Datang, Kurir!",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Rute pengiriman Anda akan tampil di sini."),
            // TODO: Nanti tampilkan list rute yang ditugaskan
          ],
        ),
      ),
    );
  }
}