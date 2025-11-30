import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart';
import '../services/route_service.dart';
import '../services/school_service.dart';

class EditRouteScreen extends StatefulWidget {
  final DeliveryRoute route;
  const EditRouteScreen({super.key, required this.route});

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();

  // List untuk menampung data Sekolah + ETA
  List<Map<String, dynamic>> _uiStops = []; 
  List<School> _allSchools = [];
  
  // Data Peta
  LatLng? _sppgLocation; 
  List<LatLng> _polylinePoints = [];
  
  int _cookingDuration = 120; // Default durasi masak (bisa diambil dari menu nanti)
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Ambil Lokasi Dapur (Start Point)
      _sppgLocation = await _routeService.getSppgLocation();

      // 2. Ambil Data Stops (Sekolah + ETA) dari Database
      final stops = await _routeService.getRouteStops(widget.route.id);
      
      _uiStops = [];
      List<LatLng> routingPoints = [];
      
      // Masukkan Dapur ke titik peta jika ada
      if (_sppgLocation != null) {
        routingPoints.add(_sppgLocation!);
      }

      for (var s in stops) {
        final sc = s['schools'];
        
        // Parsing Koordinat Sekolah
        double? lat, long;
        if (sc['gps_lat'] != null && sc['gps_long'] != null) {
          try {
            lat = double.parse(sc['gps_lat'].toString());
            long = double.parse(sc['gps_long'].toString());
            // Validasi agar tidak 0,0
            if (lat != 0 && long != 0) {
               routingPoints.add(LatLng(lat, long));
            }
          } catch (_) {}
        }

        // Masukkan ke List UI untuk ditampilkan di bawah peta
        _uiStops.add({
          'school': School(
            id: sc['id'],
            sppgId: "", 
            name: sc['name'],
            address: sc['address'],
            latitude: lat,
            longitude: long,
            studentCount: sc['student_count'] ?? 0,
            deadlineTime: sc['deadline_time'],
          ),
          'eta': s['estimated_arrival_time'] ?? '--:--', // Ambil Jam Estimasi
        });
      }

      // 3. Ambil Garis Rute (Polyline) dari OSRM
      if (routingPoints.length >= 2) {
        _polylinePoints = await _routeService.getRoutePolyline(routingPoints);
      }

      // 4. Ambil Semua Sekolah (Untuk opsi tambah sekolah nanti)
      _allSchools = await SchoolService().getMySchools();

      if (!mounted) return;
      setState(() => _isLoading = false);

      // 5. Fit Camera (Zoom Peta Otomatis)
      // [FIX ERROR MERAH]: Cek routingPoints tidak kosong sebelum fitCamera
      if (routingPoints.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          try {
             _mapController.fitCamera(CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routingPoints),
                padding: const EdgeInsets.all(60), // Padding biar gak mepet pinggir
             ));
          } catch (e) {
             print("Map Error (Abaikan): $e");
          }
        });
      } else {
         // Jika tidak ada koordinat sama sekali, beri info
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Info: Peta tidak tampil karena lokasi GPS kosong.")));
      }

    } catch (e) {
      print("Error Fetch: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- DIALOG TAMBAH SEKOLAH ---
  void _addSchoolDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tambah Sekolah"),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: _allSchools.length,
            itemBuilder: (c, i) {
              final s = _allSchools[i];
              // Cek duplikasi: Jangan tampilkan sekolah yang sudah ada di rute
              if (_uiStops.any((item) => (item['school'] as School).id == s.id)) return const SizedBox.shrink();
              
              return ListTile(
                title: Text(s.name),
                subtitle: Text("${s.studentCount} Pax | Deadline: ${s.deadlineTime ?? '-'}"),
                trailing: const Icon(Icons.add_circle, color: Colors.green),
                onTap: () {
                  setState(() {
                    _uiStops.add({
                      'school': s,
                      'eta': 'Hitung...', // Placeholder sebelum save & recalculate
                    });
                  });
                  Navigator.pop(ctx);
                  _recalculateAndSave(); // Simpan & Hitung Ulang
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // --- HAPUS SEKOLAH ---
  void _removeSchool(int index) {
    setState(() => _uiStops.removeAt(index));
    _recalculateAndSave(); // Simpan & Hitung Ulang
  }

  // --- LOGIKA SIMPAN & HITUNG ULANG RUTE ---
  Future<void> _recalculateAndSave() async {
    setState(() => _isLoading = true);
    try {
      // Ambil list School murni untuk dikirim ke service
      List<School> schoolsOnly = _uiStops.map((e) => e['school'] as School).toList();

      await _routeService.updateRouteSchools(
        widget.route.id, 
        schoolsOnly, 
        _cookingDuration
      );
      
      await _fetchData(); // Refresh agar Peta & ETA baru muncul
      
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rute & Jadwal Diperbarui!")));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
      setState(() => _isLoading = false);
    }
  }

  // Format Jam (Hapus detik HH:mm:ss -> HH:mm)
  String _formatTime(String time) {
    if (time.length > 5) return time.substring(0, 5);
    return time;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Rute & Peta"), 
        backgroundColor: Colors.orange[800], 
        foregroundColor: Colors.white
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- PETA VISUALISASI ---
                SizedBox(
                  height: 250,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: const MapOptions(
                      initialCenter: LatLng(-6.9175, 107.6191), // Default Bandung
                      initialZoom: 13.0,
                      // Pastikan gesture aktif (Zoom/Pan)
                      interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.mbg',
                      ),
                      // Garis Rute (Biru)
                      PolylineLayer(
                        polylines: [
                          Polyline(points: _polylinePoints, strokeWidth: 4.0, color: Colors.blue)
                        ]
                      ),
                      // Marker (Pin)
                      MarkerLayer(
                        markers: [
                           // Marker Dapur
                           if (_sppgLocation != null)
                            Marker(
                              point: _sppgLocation!,
                              width: 50, height: 50,
                              child: const Column(
                                children: [
                                  Icon(Icons.store, color: Colors.purple, size: 35),
                                  Text("DAPUR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, backgroundColor: Colors.white)),
                                ],
                              ),
                            ),
                          // Marker Sekolah
                          ..._uiStops.asMap().entries.map((entry) {
                            final s = entry.value['school'] as School;
                            if (s.latitude == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                            return Marker(
                              point: LatLng(s.latitude!, s.longitude!),
                              width: 40, height: 40,
                              child: Column(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.red, size: 30),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey)),
                                    child: Text("${entry.key + 1}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                                  )
                                ],
                              ),
                            );
                          }).toList()
                        ],
                      ),
                    ],
                  ),
                ),

                // --- INFO HEADER LIST ---
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.blue[50],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Urutan & Estimasi:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("${_uiStops.length} Sekolah", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
                
                // --- LIST SEKOLAH (BISA DIGESER URUTANNYA) ---
                Expanded(
                  child: ReorderableListView(
                    onReorder: (oldIndex, newIndex) {
                       // Fitur geser urutan manual
                       if (newIndex > oldIndex) newIndex -= 1;
                       final item = _uiStops.removeAt(oldIndex);
                       _uiStops.insert(newIndex, item);
                       setState(() {});
                       _recalculateAndSave(); // Hitung ulang rute jika urutan berubah
                    },
                    children: [
                      for (int index = 0; index < _uiStops.length; index++)
                        Card(
                          key: ValueKey((_uiStops[index]['school'] as School).id),
                          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange[100],
                              child: Text("${index + 1}"),
                            ),
                            title: Text((_uiStops[index]['school'] as School).name),
                            subtitle: Text("Deadline: ${(_uiStops[index]['school'] as School).deadlineTime ?? '-'}"),
                            
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tampilan Estimasi Waktu (ETA)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(5),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text("Est. Tiba", style: TextStyle(fontSize: 8)),
                                      Text(
                                        _formatTime(_uiStops[index]['eta'].toString()), 
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Tombol Hapus Sekolah dari Rute
                                IconButton(
                                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                                  onPressed: () => _removeSchool(index),
                                ),
                                // Handle Drag
                                const Icon(Icons.drag_handle, color: Colors.grey),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                ),
              ],
            ),
      // TOMBOL TAMBAH SEKOLAH
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSchoolDialog,
        label: const Text("Tambah Sekolah"),
        icon: const Icon(Icons.add_location),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
    );
  }
}