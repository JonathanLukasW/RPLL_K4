import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Visualisasi Peta
import 'package:latlong2/latlong.dart'; // Tipe data Koordinat
import 'package:url_launcher/url_launcher.dart'; // Buka Google Maps

import '../../admin_sppg/services/route_service.dart';
import '../../../models/route_model.dart';

class RouteDetailScreen extends StatefulWidget {
  final DeliveryRoute route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();
  
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _polylinePoints = []; // Titik-titik garis rute biru
  bool _isLoading = true;
  String _currentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.route.status;
    _fetchData();
  }

  // --- AMBIL DATA STOP & HITUNG JALUR ---
  Future<void> _fetchData() async {
    try {
      // 1. Ambil daftar sekolah (Stops)
      final stopsData = await _routeService.getRouteStops(widget.route.id);
      
      // 2. Ambil Koordinat Sekolah untuk marker & rute
      List<LatLng> points = [];
      
      // (Opsional) Tambahkan Titik Awal (Dapur SPPG) jika punya datanya.
      // Untuk sekarang kita mulai dari sekolah pertama.
      
      for (var stop in stopsData) {
        final school = stop['schools'];
        if (school['latitude'] != null && school['longitude'] != null) {
          points.add(LatLng(school['latitude'], school['longitude']));
        }
      }

      // 3. Minta Garis Rute ke OSRM (Service yang baru kita buat)
      List<LatLng> polyline = [];
      if (points.isNotEmpty) {
        // Kalau titiknya cuma 1, ga bisa bikin garis, jadi marker aja
        if (points.length > 1) {
          polyline = await _routeService.getRoutePolyline(points);
        }
      }

      if (!mounted) return;
      setState(() {
        _stops = stopsData;
        _polylinePoints = polyline;
        _isLoading = false;
      });

      // 4. Fit Kamera Peta biar semua titik kelihatan
      if (points.isNotEmpty) {
        // Kasih delay dikit biar peta render dulu
        Future.delayed(const Duration(milliseconds: 500), () {
          _mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(50),
            ),
          );
        });
      }

    } catch (e) {
      print("Error fetch data: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- BUKA GOOGLE MAPS (Navigasi) ---
  Future<void> _launchGoogleMaps(double lat, double long) async {
    // Format URL untuk mode navigasi (turn-by-turn)
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$long&mode=d");
    
    // Fallback link browser kalau aplikasinya ga ada
    final Uri browserUrl = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$long");

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal buka maps: $e")));
    }
  }

  // --- LOGIKA BUTTONS (Sama seperti sebelumnya) ---
  void _showValidationDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Validasi Muatan"),
          content: const Text("Pastikan semua menu sudah sesuai SOP sebelum berangkat."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _routeService.updateRouteStatus(widget.route.id, 'active');
                setState(() => _currentStatus = 'active');
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              child: const Text("Konfirmasi & Jalan"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _completeStop(String stopId, String schoolName) async {
    await _routeService.updateStopStatus(stopId, 'completed');
    _fetchData(); // Refresh data
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sampai di $schoolName!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Pengiriman"),
        backgroundColor: _currentStatus == 'active' ? Colors.green[700] : Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // -------------------------------------------------------
          // 1. PETA NAVIGASI (ATAS)
          // -------------------------------------------------------
          SizedBox(
            height: 250, // Tinggi Peta
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-6.9175, 107.6191), // Default Bandung
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mbg_monitoring',
                ),
                // GARIS RUTE (BIRU)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 4.0,
                      color: Colors.blue,
                    ),
                  ],
                ),
                // MARKER (PIN SEKOLAH)
                MarkerLayer(
                  markers: _stops.map((stop) {
                    final school = stop['schools'];
                    final isCompleted = stop['status'] == 'completed';
                    if (school['latitude'] == null) return const Marker(point: LatLng(0,0), child: SizedBox()); // Skip if null

                    return Marker(
                      point: LatLng(school['latitude'], school['longitude']),
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.location_on, 
                        color: isCompleted ? Colors.green : Colors.red,
                        size: 40,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // -------------------------------------------------------
          // 2. LIST PENGIRIMAN (BAWAH)
          // -------------------------------------------------------
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _stops.length,
                    itemBuilder: (context, index) {
                      final stop = _stops[index];
                      final school = stop['schools'];
                      final bool isCompleted = stop['status'] == 'completed';
                      final lat = school['latitude'];
                      final long = school['longitude'];

                      return Card(
                        color: isCompleted ? Colors.green[50] : Colors.white,
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isCompleted ? Colors.green : Colors.grey[300],
                            child: Text("${index + 1}", style: TextStyle(color: isCompleted ? Colors.white : Colors.black)),
                          ),
                          title: Text(school['name']),
                          subtitle: Text("Menu: ${school['menu_default'] ?? '-'} (${school['student_count']} pax)"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TOMBOL NAVIGASI (GOOGLE MAPS)
                              if (lat != null && long != null)
                                IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue),
                                  onPressed: () => _launchGoogleMaps(lat, long),
                                ),
                              
                              // TOMBOL SELESAI
                              if (_currentStatus == 'active' && !isCompleted)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10)
                                  ),
                                  onPressed: () => _completeStop(stop['id'], school['name']),
                                  child: const Text("Tiba"),
                                )
                              else if (isCompleted)
                                const Icon(Icons.check_circle, color: Colors.green),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
      // Tombol Start (Muncul cuma pas Pending)
      bottomNavigationBar: _currentStatus == 'pending'
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _showValidationDialog,
                icon: const Icon(Icons.checklist),
                label: const Text("VALIDASI MUATAN & MULAI"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            )
          : null,
    );
  }
}