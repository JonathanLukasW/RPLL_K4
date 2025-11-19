import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import Dashboard
import '../../pengawas/screens/dashboard_bgn_screen.dart';
import '../../admin_sppg/screens/dashboard_admin_screen.dart';
import '../../kurir/screens/dashboard_kurir_screen.dart'; // Import Dashboard Kurir

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
    setState(() { _isLoading = true; });

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
      
      // [PERBAIKAN KRUSIAL] - Normalisasi string role: kecilkan dan buang spasi
      final String rawRole = profileData['role'] ?? 'unknown';
      final String role = rawRole.toLowerCase().trim(); // <-- FIX RLS ERROR DISINI

      print("Role yang Diterima dari DB: $rawRole");
      print("Role yang Digunakan (Normalized): $role");


      // 3. Resepsionis Pintar Mengarahkan User
      if (!mounted) return;

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
      } else if (role == 'kurir') { // <-- Sekarang comparison lebih aman
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardKurirScreen()),
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
  // ... (kode dispose dan build tetap sama) ...
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            // ... (kode UI form) ...
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text("MBG Monitoring", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Silakan masuk untuk melanjutkan", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),
              
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("MASUK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}