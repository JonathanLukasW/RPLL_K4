import 'package:flutter/material.dart';
import '../../autentikasi/services/auth_service.dart';
import '../../autentikasi/screens/login_screen.dart';
import 'list_sppg_screen.dart';
import 'bgn_report_screen.dart'; // Screen baru UC03

class DashboardBgnScreen extends StatelessWidget {
  const DashboardBgnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BGN Monitoring"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Selamat Datang, Pengawas", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Text("Pilih menu di bawah untuk memulai:"),
            const SizedBox(height: 20),

            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // MENU 1: MANAJEMEN AKUN SPPG (UC04, UC05, UC06, UC07)
                  _buildMenuCard(
                    context,
                    icon: Icons.manage_accounts,
                    title: "Manajemen Akun SPPG",
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListSppgScreen())),
                  ),

                  // MENU 2: LAPORAN DISTRIBUSI & KUALITAS (UC03)
                  // Menggabungkan History, Bukti, Jadwal, Ketepatan, Keluhan
                  _buildMenuCard(
                    context,
                    icon: Icons.analytics,
                    title: "Laporan Distribusi & Kualitas",
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BgnReportScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await AuthService().signOut();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        },
        label: const Text("Logout"),
        icon: const Icon(Icons.logout),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required IconData icon, required String title, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)],
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(radius: 30, backgroundColor: color.withOpacity(0.1), child: Icon(icon, size: 30, color: color)),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}