import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// Import Layar Lupa Password
import 'forgot_password_screen.dart';
// Import Semua Dashboard
import '../../pengawas/screens/dashboard_bgn_screen.dart';
import '../../admin_sppg/screens/dashboard_admin_screen.dart';
import '../../kurir/screens/dashboard_kurir_screen.dart';
import '../../koordinator/screens/dashboard_koordinator_screen.dart';
import '../../walikelas/screens/dashboard_teacher_screen.dart';

// --- AKUN DEBUG (SECTION FOR MANUAL INPUT) ---
// WARNING: CONTAINS REAL PASSWORDS FOR DEBUGGING. DELETE BEFORE PRODUCTION!
const List<Map<String, String>> _debugAccounts = [
  // PENGWAS BGN
  {'name': 'Admin BGN','email': 'lukasjoo17@gmail.com','password': 'sahroni123','role': 'bgn',},
  // ADMIN SPPG
  {'name': 'Admin SPPG 1 (Rezky)','email': 'rezkysukajaya@gmail.com','password': 'sukajaya123','role': 'admin_sppg',},
  {'name': 'Admin SPPG 2 (Aley)','email': 'aleykaryawangi@gmail.com','password': 'karyawangi123','role': 'admin_sppg',},
  {'name': 'Admin SPPG 3 (Amanda)','email': 'amandakayuambon@gmail.com','password': 'kayuambon123','role': 'admin_sppg',},
  // KURIR
  {'name': 'Kurir 1 (Andika)','email': 'andikabinawisata@gmail.com','password': 'andika123','role': 'kurir',},
  {'name': 'Kurir 2 (Max)','email': 'max@gmail.com','password': 'max123','role': 'kurir',},
  {'name': 'Kurir 3 (Lewis)','email': 'lewis@gmail.com','password': 'lewis123','role': 'kurir',},
  // KOORDINATOR
  {'name': 'Koord 1 (Vincent)','email': 'vincentsmpn6@gmail.com','password': 'vincent123','role': 'koordinator',},
  {'name': 'Koord 2 (Arya)','email': 'aryabhayangkari19@gmail.com','password': 'arya123','role': 'koordinator',},
  {'name': 'Koord 3 (Deffa)','email': 'deffapgri@gmail.com','password': 'deffa123','role': 'koordinator',},
  {'name': 'Koord 4 (Khaerul)','email': 'khaerulpancasila@gmail.com','password': 'khaerul123','role': 'koordinator',},
  // WALI KELAS
  {'name': 'Wali Kelas 8A (William)','email': 'smpn6_8a@gmail.com','password': 'smpn6_8a','role': 'walikelas',},
  {'name': 'Wali Kelas 8B (Kevin)','email': 'smpn6_8b@gmail.com','password': 'smpn6_8b','role': 'walikelas',},
  {'name': 'Wali Kelas 7A (Siti)','email': 'smpn6_7a@gmail.com','password': 'smpn6_7a','role': 'walikelas',},
  {'name': 'Wali Kelas 7B (Eiza)','email': 'smpn6_7b@gmail.com','password': 'smpn6_7b','role': 'walikelas',},
];
// --- END OF DEBUG ACCOUNTS ---

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // --- DEBUG STATE ---
  Map<String, String>? _selectedDebugAccount;
  // --- END DEBUG STATE ---

  // --- REUSABLE NAVIGATION LOGIC ---
  void _navigateToDashboard(BuildContext context, String role) {
    if (role == 'bgn') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardBgnScreen()),);
    } else if (role == 'admin_sppg') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardAdminScreen()),);
    } else if (role == 'kurir') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardKurirScreen()),);
    } else if (role == 'koordinator') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardKoordinatorScreen()),);
    } else if (role == 'walikelas') {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DashboardTeacherScreen()),);
    } else {
      // Fallback for unknown role
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Akses Ditolak: Role '$role' tidak dikenali."), backgroundColor: Colors.red),);
      Supabase.instance.client.auth.signOut();
    }
  }

  // --- ORIGINAL LOGIN FUNCTION (SLIGHTLY MODIFIED) ---
  Future<void> _login() async {
    // Before logging in, check if the fields are empty.
    // If they are empty, but a debug account is selected, populate them first.
    if (_emailController.text.isEmpty && _selectedDebugAccount != null) {
      _emailController.text = _selectedDebugAccount!['email']!;
      _passwordController.text = _selectedDebugAccount!['password']!;
    }
    
    setState(() { _isLoading = true; });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception("Email dan Password harus diisi.");
      }

      // 1. Login Auth
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(email: email, password: password);

      if (res.user == null) {
        throw Exception("Login gagal. Periksa kembali email & password Anda.");
      }

      if (!mounted) return;

      // 2. Cek Role di Database
      final userId = res.user!.id;
      final profileData = await Supabase.instance.client.from('profiles').select().eq('id', userId).single();

      if (profileData == null) throw Exception("Profil user tidak ditemukan.");
      
      final String rawRole = profileData['role'] ?? 'unknown';
      final String role = rawRole.toLowerCase().trim();

      if (!mounted) return;

      // 3. Navigasi Sesuai Role
      _navigateToDashboard(context, role);
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal Masuk: ${e.toString().replaceAll('Exception:', '')}"), backgroundColor: Colors.red),);
    } finally {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  // --- DEBUG FUNCTION TO POPULATE FIELDS ---
  void _populateFields(Map<String, String>? account) {
    setState(() {
      _selectedDebugAccount = account;
      if (account != null) {
        _emailController.text = account['email']!;
        _passwordController.text = account['password']!;
      } else {
        _emailController.clear();
        _passwordController.clear();
      }
    });
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
              const Text("MBG Monitoring", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const Text("Silakan masuk untuk melanjutkan", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // --- DEBUG QUICK LOGIN SECTION ---
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.red[50], // Nice, angry red for warnings
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.redAccent),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "⚠️ DEBUG QUICK SELECT (AUTO-FILL) - DELETE IN PRODUCTION!",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Dropdown for accounts
                    DropdownButtonFormField<Map<String, String>>(
                      decoration: const InputDecoration(
                        labelText: "Pilih Akun Cepat",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_search, color: Colors.redAccent,),
                      ),
                      value: _selectedDebugAccount,
                      items: _debugAccounts.map((account) {
                        return DropdownMenuItem<Map<String, String>>(
                          value: account,
                          child: Text("${account['name']} (${account['role']?.toUpperCase()})",),
                        );
                      }).toList(),
                      onChanged: _populateFields, // Use the new auto-fill function
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      "Memilih akun akan otomatis mengisi Email dan Password di bawah.",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // --- END DEBUG QUICK LOGIN SECTION ---

              // Input Email (Original)
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email)),
              ),
              const SizedBox(height: 16),
              // Input Password (Original)
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock)),
              ),
              const SizedBox(height: 10),
              // Tombol Lupa Password
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),);
                  },
                  child: const Text("Lupa Password?", style: TextStyle(color: Colors.blue)),
                ),
              ),
              const SizedBox(height: 20),
              // Tombol Masuk
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
}