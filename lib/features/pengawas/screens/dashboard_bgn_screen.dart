import 'package:flutter/material.dart';
import '../../../core/screens/profile_screen.dart'; // Import Profil
import 'list_sppg_screen.dart';
import 'bgn_report_screen.dart';
import 'bgn_statistics_screen.dart'; // Import Statistik
import 'bgn_tracking_screen.dart';   // Import Tracking

class DashboardBgnScreen extends StatelessWidget {
  const DashboardBgnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BGN Monitoring"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // [PERBAIKAN] Ganti Logout dengan Profil
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: "Profil Saya",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Selamat Datang, Pengawas",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Pantauan Nasional Program Makan Bergizi Gratis"),
            const SizedBox(height: 20),

            // Grid Menu
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // Menu 1: Data Master SPPG
                  _buildMenuCard(
                    context,
                    icon: Icons.business_outlined,
                    title: "Data Master SPPG",
                    color: Colors.blue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListSppgScreen())),
                  ),

                  // Menu 2: Peta Tracking (SUDAH AKTIF)
                  _buildMenuCard(
                    context,
                    icon: Icons.map_outlined,
                    title: "Peta Sebaran SPPG",
                    color: Colors.green,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BgnTrackingScreen())),
                  ),

                  // Menu 3: Laporan Insiden
                  _buildMenuCard(
                    context,
                    icon: Icons.warning_amber_rounded,
                    title: "Laporan & Pengaduan",
                    color: Colors.redAccent,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BgnReportScreen())),
                  ),

                  // Menu 4: Statistik (SUDAH AKTIF)
                  _buildMenuCard(
                    context,
                    icon: Icons.bar_chart,
                    title: "Statistik Nasional",
                    color: Colors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BgnStatisticsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, spreadRadius: 2),
          ],
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}