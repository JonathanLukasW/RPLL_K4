import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Import halaman login yang baru saja kita buat
import 'features/autentikasi/screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Muat file rahasia .env
  await dotenv.load(fileName: ".env");

  // 2. Nyalakan Koneksi Supabase
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MBG Logistics', 
      debugShowCheckedModeBanner: false, // Biar pita 'Debug' di pojok hilang
      theme: ThemeData(
        // Kita pakai warna Hijau sebagai warna utama (Identik dengan kesegaran/makanan)
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        // Sedikit styling tambahan biar input text lebih rapi
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
      // PENTING: Di sini kita arahkan langsung ke LoginScreen
      home: const LoginScreen(),
    );
  }
}