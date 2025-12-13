import 'package:flutter/material.dart';

// Import Auth & Login
import '../../autentikasi/services/auth_service.dart';
import '../../autentikasi/screens/login_screen.dart';

// Import Screens Fitur BGN
import 'list_sppg_screen.dart';
import 'bgn_report_screen.dart'; // Screen Laporan Terpadu

// [PENTING] Import Halaman Profil (Tempat Ganti Password)
import '../../../core/screens/profile_screen.dart';
import '../../autentikasi/screens/login_screen.dart'
    as login_screen; // <--- Import dengan alias

class DashboardBgnScreen extends StatefulWidget {
  const DashboardBgnScreen({super.key});

  @override
  State<DashboardBgnScreen> createState() => _DashboardBgnScreenState(); // <-- UBAH KE STATEFUL
}

class _DashboardBgnScreenState extends State<DashboardBgnScreen> {
  // <-- UBAH KE STATE

  // Ambil initial state dari variabel global
  bool _isDebugActive = login_screen.isDebugModeActive;

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // [BARU] Toggle Debug Mode
  void _toggleDebugMode(bool isActive) {
    setState(() {
      _isDebugActive = isActive;
      login_screen.isDebugModeActive = isActive; // UPDATE GLOBAL STATE

      // Memberikan feedback yang jelas
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isActive
                ? "Debug Mode AKTIF. Perlu Log out untuk melihat perubahan."
                : "Debug Mode NONAKTIF.",
          ),
          backgroundColor: isActive ? Colors.red : Colors.green,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BGN Monitoring"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // [BARU] TOGGLE DEBUG MENU
          Tooltip(
            message: "Toggle Quick Login Debug",
            child: Switch(
              value: _isDebugActive,
              onChanged: _toggleDebugMode,
              activeColor: Colors.redAccent,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[200],
            ),
          ),
          // [FITUR GANTI PASSWORD ADA DI SINI]
          // Tombol Profil (Icon Orang)
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: "Profil & Password",
            onPressed: () {
              // Navigasi ke Halaman Profil
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
            const Text("Pilih menu di bawah untuk memulai:"),
            const SizedBox(height: 20),

            // Grid Menu
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  // MENU 1: MANAJEMEN AKUN SPPG
                  _buildMenuCard(
                    context,
                    icon: Icons.manage_accounts,
                    title: "Manajemen Akun SPPG",
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ListSppgScreen(),
                        ),
                      );
                    },
                  ),

                  // MENU 2: LAPORAN DISTRIBUSI & KUALITAS
                  _buildMenuCard(
                    context,
                    icon: Icons.analytics,
                    title: "Laporan Distribusi & Kualitas",
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BgnReportScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
