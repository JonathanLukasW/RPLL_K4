import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
// Import Model
import '../../../models/sppg_model.dart';
// Import Service yang sudah ada fitur Ghost Client-nya
import '../services/sppg_service.dart';

class DetailSppgScreen extends StatelessWidget {
  final Sppg sppg;

  const DetailSppgScreen({super.key, required this.sppg});

  // ---------------------------------------------------------------------------
  // LOGIKA DIALOG "BUAT AKUN"
  // ---------------------------------------------------------------------------
  void _showCreateAccountDialog(BuildContext context) {
    final TextEditingController passwordController = TextEditingController();
    bool isLoading = false;

    showDialog(
      context: context,
      barrierDismissible: false, // User gabisa tutup dialog sembarangan
      builder: (context) {
        // Kita butuh StatefulBuilder DI DALAM Dialog agar bisa update state loading
        // khusus untuk tampilan dialog ini saja.
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Buat Akun Login"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Akun ini akan digunakan oleh Admin SPPG untuk login ke aplikasi mobile.",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  
                  // Tampilkan Email (Read Only)
                  const Text("Email Login:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      sppg.email ?? "Email belum diatur!",
                      style: TextStyle(color: sppg.email == null ? Colors.red : Colors.black),
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Input Password Baru
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password Baru",
                      hintText: "Minimal 6 karakter",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  
                  // Loading Indicator
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                ],
              ),
              actions: [
                // Tombol Batal (Hilang kalau lagi loading)
                if (!isLoading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Batal", style: TextStyle(color: Colors.grey)),
                  ),
                
                // Tombol Eksekusi
                if (!isLoading)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700], 
                      foregroundColor: Colors.white
                    ),
                    onPressed: () async {
                      // 1. Validasi Input
                      if (sppg.email == null || sppg.email!.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Error: SPPG ini tidak punya email. Edit data dulu!")),
                        );
                        return;
                      }
                      if (passwordController.text.length < 6) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Password minimal 6 karakter!")),
                        );
                        return;
                      }

                      // 2. Mulai Loading
                      setState(() => isLoading = true);

                      try {
                        // 3. Panggil Service (Ghost Client)
                        await SppgService().createSppgUser(
                          email: sppg.email!,
                          password: passwordController.text,
                          sppgId: sppg.id,
                          sppgName: sppg.name,
                        );

                        if (!context.mounted) return;
                        
                        // 4. Sukses
                        Navigator.pop(context); // Tutup Dialog
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("SUKSES! Akun Admin SPPG berhasil dibuat."),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 4),
                          ),
                        );

                      } catch (e) {
                        // 5. Gagal
                        setState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text("Buat Akun"),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Validasi lokasi untuk peta
    bool hasLocation = sppg.latitude != null && sppg.longitude != null;
    
    // Titik tengah peta (Default Bandung kalau kosong)
    final centerLocation = hasLocation 
        ? LatLng(sppg.latitude!, sppg.longitude!) 
        : const LatLng(-6.9175, 107.6191);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail SPPG"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // -----------------------------------------------------------------
            // 1. PETA LOKASI (Visualisasi OSM)
            // -----------------------------------------------------------------
            SizedBox(
              height: 250,
              width: double.infinity,
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: centerLocation,
                      initialZoom: 16.0, // Zoom level dekat
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mbg_monitoring',
                      ),
                      // Attribution (Wajib Legalitas)
                      const RichAttributionWidget(
                        attributions: [TextSourceAttribution('OpenStreetMap contributors')],
                      ),
                      // Pin Merah Lokasi
                      if (hasLocation)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: centerLocation,
                              width: 50,
                              height: 50,
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 40),
                            ),
                          ],
                        ),
                    ],
                  ),
                  // Gradient shadow di bawah
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 30,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.1), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // 2. INFORMASI TEKS
            // -----------------------------------------------------------------
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama SPPG
                  Text(
                    sppg.name,
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  
                  // Badge ID
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Text(
                      "ID: ${sppg.id.split('-').first}...", // Tampilkan ID pendek aja
                      style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Card Detail Kontak
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          _buildInfoRow(Icons.email, "Email Admin", sppg.email ?? "-"),
                          const Divider(),
                          _buildInfoRow(Icons.phone, "Telepon", sppg.phone ?? "-"),
                          const Divider(),
                          _buildInfoRow(Icons.map, "Alamat", sppg.address ?? "-"),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text("Lokasi GPS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Card(
                    color: Colors.grey[100],
                    elevation: 0,
                    child: ListTile(
                      leading: const Icon(Icons.gps_fixed, color: Colors.orange),
                      title: Text(hasLocation 
                          ? "${sppg.latitude}, ${sppg.longitude}" 
                          : "Koordinat belum diatur"),
                      subtitle: const Text("Latitude, Longitude"),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // -------------------------------------------------------------
                  // 3. TOMBOL AKSI
                  // -------------------------------------------------------------
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showCreateAccountDialog(context),
                      icon: const Icon(Icons.person_add),
                      label: const Text("BUAT AKUN LOGIN ADMIN"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Tombol Edit (Placeholder)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                         ScaffoldMessenger.of(context).showSnackBar(
                           const SnackBar(content: Text("Fitur Edit Data akan dibuat nanti")),
                         );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("EDIT DATA SPPG"),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget kecil buat baris info
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}