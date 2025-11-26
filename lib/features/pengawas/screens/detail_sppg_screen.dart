import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/sppg_model.dart';
import '../../../models/school_model.dart';
import '../services/sppg_service.dart';
import '../../admin_sppg/services/school_service.dart'; // Import School Service

class DetailSppgScreen extends StatelessWidget {
  final Sppg sppg;

  const DetailSppgScreen({super.key, required this.sppg});

  // Fungsi Hapus
  Future<void> _deleteSppg(BuildContext context) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus SPPG?"),
        content: const Text("Tindakan ini akan menghapus data SPPG ini. Data terkait mungkin ikut terhapus."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SppgService().deleteSppg(sppg.id);
        if(!context.mounted) return;
        Navigator.pop(context, true); // Balik ke list dan refresh
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("SPPG Dihapus.")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasLocation = sppg.latitude != null && sppg.longitude != null;
    final centerLocation = hasLocation 
        ? LatLng(sppg.latitude!, sppg.longitude!) 
        : const LatLng(-6.9175, 107.6191);

    return Scaffold(
      appBar: AppBar(
        title: Text(sppg.name),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // Tombol Hapus (UC06)
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: "Hapus SPPG",
            onPressed: () => _deleteSppg(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. PETA
            SizedBox(
              height: 200,
              width: double.infinity,
              child: FlutterMap(
                options: MapOptions(initialCenter: centerLocation, initialZoom: 15.0),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.example.mbg'),
                  if (hasLocation) MarkerLayer(markers: [Marker(point: centerLocation, width: 50, height: 50, child: const Icon(Icons.location_pin, color: Colors.red, size: 40))]),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Detail Info", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ListTile(leading: const Icon(Icons.map), title: Text(sppg.address ?? "-"), subtitle: const Text("Alamat")),
                  ListTile(leading: const Icon(Icons.email), title: Text(sppg.email ?? "-"), subtitle: const Text("Email Admin")),
                  ListTile(leading: const Icon(Icons.phone), title: Text(sppg.phone ?? "-"), subtitle: const Text("Telepon")),
                  
                  const Divider(height: 30),

                  // 2. LIST SEKOLAH PENERIMA MANFAAT (UC07)
                  const Text("Daftar Penerima Manfaat (Sekolah)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  
                  SizedBox(
                    height: 300, // Fixed height untuk list
                    child: FutureBuilder<List<School>>(
                      future: SchoolService().getSchoolsBySppgId(sppg.id),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                        final schools = snapshot.data ?? [];
                        if (schools.isEmpty) return const Center(child: Text("Belum ada sekolah terdaftar."));
                        
                        return ListView.builder(
                          itemCount: schools.length,
                          itemBuilder: (ctx, i) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.school, color: Colors.orange),
                              title: Text(schools[i].name),
                              subtitle: Text("${schools[i].studentCount} Siswa"),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}