import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../../pengawas/screens/dashboard_bgn_screen.dart';
import '../../admin_sppg/screens/dashboard_admin_screen.dart';
import '../../kurir/screens/dashboard_kurir_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Controller untuk mengambil teks dari inputan
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Service Auth yang tadi kita buat
  final _authService = AuthService();
  
  // Status loading (biar tombol muter-muter pas diklik)
  bool _isLoading = false;

  // Fungsi saat tombol Login ditekan
  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Panggil fungsi login dari Service
      final userProfile = await _authService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      // 2. Cek Role dan Pindahkan Halaman
      
      final role = userProfile?.role;

      if (role == 'bgn') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardBgnScreen()),
        );
      } else if (role == 'admin_sppg') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardAdminScreen()),
        );
      } else if (role == 'kurir') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardKurirScreen()),
        );
      } else {
        // Role lain (Koordinator/Wali Kelas) sementara tampilkan pesan dulu
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login Berhasil! Role: $role (Halaman belum dibuat)")),
        );
      }
      // NANTI DI SINI KITA ARRAHKAN KE HALAMAN SESUAI ROLE
      // Misal: if (role == 'bgn') ke DashboardBGN, dst.
      
    } catch (e) {
      // 3. Jika gagal, tampilkan error
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
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
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- LOGO / JUDUL ---
              const Icon(
                Icons.local_shipping_outlined,
                size: 80,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                "MBG Logistics",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Sistem Monitoring Distribusi Pangan",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // --- INPUT EMAIL ---
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // --- INPUT PASSWORD ---
              TextField(
                controller: _passwordController,
                obscureText: true, // Biar password jadi bintang-bintang
                decoration: const InputDecoration(
                  labelText: "Password",
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // --- TOMBOL LOGIN ---
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("MASUK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              
              const SizedBox(height: 20),
              const Text(
                "Lupa password? Hubungi Admin BGN.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}