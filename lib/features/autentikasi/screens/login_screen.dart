import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- IMPORT SEMUA DASHBOARD ---
import '../../pengawas/screens/dashboard_bgn_screen.dart';
import '../../admin_sppg/screens/dashboard_admin_screen.dart';
import '../../kurir/screens/dashboard_kurir_screen.dart';
import '../../koordinator/screens/dashboard_koordinator_screen.dart';
import '../../walikelas/screens/dashboard_teacher_screen.dart'; // [BARU] Dashboard Wali Kelas

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- FUNGSI LOGIN UTAMA ---
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception("Email dan Password harus diisi.");
      }

      // 1. Proses Login Auth Supabase
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) {
        throw Exception("Login gagal. Periksa kembali email & password Anda.");
      }

      if (!mounted) return;

      // 2. Ambil Data Profile User untuk Cek Role
      final userId = res.user!.id;
      final profileData = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (profileData == null) {
        throw Exception("Profil user tidak ditemukan di database.");
      }

      // Normalisasi string role: kecilkan dan buang spasi (PENTING)
      final String rawRole = profileData['role'] ?? 'unknown';
      final String role = rawRole.toLowerCase().trim(); 

      print("Login User: $email");
      print("Role Detected: $role");

      // 3. Resepsionis Pintar Mengarahkan User
      if (!mounted) return;

      if (role == 'bgn') {
        // Arahkan ke Dashboard Pengawas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardBgnScreen()),
        );
      } else if (role == 'admin_sppg') {
        // Arahkan ke Dashboard Admin SPPG
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardAdminScreen()),
        );
      } else if (role == 'kurir') {
        // Arahkan ke Dashboard Kurir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardKurirScreen()),
        );
      } else if (role == 'koordinator') {
        // Arahkan ke Dashboard Koordinator
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardKoordinatorScreen()),
        );
      } else if (role == 'walikelas') { 
        // [BARU] Arahkan ke Dashboard Wali Kelas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardTeacherScreen()),
        );
      } else {
        // Role tidak dikenali
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Akses Ditolak: Role '$rawRole' tidak dikenali."),
            backgroundColor: Colors.red,
          ),
        );
        // Logout lagi agar sesi yang salah terhapus
        await Supabase.instance.client.auth.signOut();
      }

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal Masuk: ${e.toString().replaceAll('Exception:', '')}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              
              const Text(
                "MBG Monitoring",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Silakan masuk untuk melanjutkan",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // Input Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),

              // Input Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 30),

              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "MASUK",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}