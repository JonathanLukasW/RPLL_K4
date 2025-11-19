import 'package:flutter/material.dart';
// Sesuaikan path import ini dengan struktur foldermu
import '../../autentikasi/services/auth_service.dart';
import '../../autentikasi/screens/login_screen.dart';
// Nanti kita buat halaman ini di langkah selanjutnya:
import 'list_sppg_screen.dart'; 

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
            const Text(
              "Selamat Datang, Pengawas",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text("Pilih menu di bawah untuk memulai:"),
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
                    onTap: () {
                      // Navigasi ke Halaman List SPPG
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ListSppgScreen()),
                      );
                    },
                  ),

                  // Menu 2: Peta Tracking
                  _buildMenuCard(
                    context,
                    icon: Icons.map_outlined,
                    title: "Peta Tracking Live",
                    color: Colors.green,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fitur Peta akan dibuat...")),
                      );
                    },
                  ),

                  // Menu 3: Laporan Insiden
                  _buildMenuCard(
                    context,
                    icon: Icons.warning_amber_rounded,
                    title: "Laporan Insiden",
                    color: Colors.redAccent,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fitur Laporan akan dibuat...")),
                      );
                    },
                  ),

                  // Menu 4: Statistik
                  _buildMenuCard(
                    context,
                    icon: Icons.bar_chart,
                    title: "Statistik Kinerja",
                    color: Colors.purple,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Fitur Statistik akan dibuat...")),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Tombol Logout
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Logout logic
          await AuthService().signOut();
          if (!context.mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
        },
        label: const Text("Logout"),
        icon: const Icon(Icons.logout),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
      ),
    );
  }

  // --- FUNGSI INI HARUS ADA DI DALAM KELAS, TAPI DI LUAR 'build' ---
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
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
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
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}