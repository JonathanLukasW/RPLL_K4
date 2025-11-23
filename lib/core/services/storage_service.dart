import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // Pastikan sudah ada di pubspec

class StorageService {
  final _supabase = Supabase.instance.client;

  // Fungsi Pilih Foto dari Kamera/Galeri
  Future<File?> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 70, // Kompres dikit biar gak berat
      maxWidth: 1024,   // Resize
    );

    if (image != null) {
      return File(image.path);
    }
    return null;
  }

  // Fungsi Upload ke Supabase
  Future<String> uploadEvidence(File file, String folderName) async {
    try {
      // Nama file unik: evidence/stops/timestamp.jpg
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$folderName/$fileName';

      // Upload
      await _supabase.storage.from('evidence').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      // Ambil URL Publik
      final String publicUrl = _supabase.storage.from('evidence').getPublicUrl(path);
      return publicUrl;
      
    } catch (e) {
      throw Exception("Gagal upload foto: $e");
    }
  }
}