import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  
  bool _isLoading = false;
  int _step = 1; // 1: Input Email, 2: Input OTP, 3: Input Password Baru

  // TAHAP 1: KIRIM OTP (TOKEN) KE EMAIL
  // Kita pakai signInWithOtp agar Supabase mengirim kode angka, bukan magic link
  Future<void> _sendOtp() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masukkan email Anda")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: _emailController.text.trim(),
        shouldCreateUser: false, // Pastikan user memang sudah ada
      );
      
      setState(() => _step = 2); // Pindah ke tahap input OTP
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kode OTP 6 digit telah dikirim ke email Anda.")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal mengirim OTP: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // TAHAP 2: VERIFIKASI OTP & LOGIN
  Future<void> _verifyOtp() async {
    if (_otpController.text.isEmpty) return;
    
    setState(() => _isLoading = true);
    try {
      // Verifikasi Token. Tipe-nya adalah 'email' (karena kita pakai signInWithOtp)
      // Jika berhasil, user akan otomatis ter-LOGIN.
      final res = await Supabase.instance.client.auth.verifyOTP(
        token: _otpController.text.trim(),
        type: OtpType.email, 
        email: _emailController.text.trim(),
      );
      
      if (res.session != null) {
        // Login berhasil! Sekarang kita minta user buat password baru.
        setState(() => _step = 3); 
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Kode OTP Salah atau Kadaluarsa.")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // TAHAP 3: UPDATE PASSWORD BARU
  // Karena user sudah posisi login (hasil tahap 2), kita bisa langsung update user.
  Future<void> _updatePassword() async {
    if (_newPasswordController.text.length < 6) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Password minimal 6 karakter")));
       return;
    }
    
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );
      
      if (!mounted) return;
      
      // Sukses! Logout dulu biar user login ulang pakai password baru (Opsional, tapi lebih aman)
      await Supabase.instance.client.auth.signOut();
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Password Berhasil Diubah! Silakan Login kembali."),
        backgroundColor: Colors.green,
      ));
      
      Navigator.pop(context); // Kembali ke Login Screen

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal simpan password: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // UI TAHAP 1: EMAIL
            if (_step == 1) ...[
              const Icon(Icons.lock_reset, size: 60, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                "Lupa Password?", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              const Text(
                "Masukkan email Anda. Kami akan mengirimkan kode OTP 6 digit untuk mengatur ulang kata sandi.", 
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email Terdaftar", 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.email)
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _isLoading ? const CircularProgressIndicator() : const Text("KIRIM KODE OTP"),
                ),
              ),
              
            // UI TAHAP 2: INPUT OTP
            ] else if (_step == 2) ...[
              const Icon(Icons.mark_email_read, size: 60, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                "Verifikasi OTP", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 10),
              Text(
                "Masukkan 6 digit kode yang dikirim ke ${_emailController.text}", 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  hintText: "000000",
                  border: OutlineInputBorder(), 
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOtp,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                  child: _isLoading ? const CircularProgressIndicator() : const Text("VERIFIKASI"),
                ),
              ),

            // UI TAHAP 3: PASSWORD BARU
            ] else ...[
              const Icon(Icons.key, size: 60, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Buat Password Baru", 
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password Baru", 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.lock)
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN PASSWORD"),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}