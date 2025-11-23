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
  List<LatLng> _polylinePoints = [];
  LatLng? _sppgLocation; // Lokasi Dapur
  
  bool _isLoading = true;
  String _currentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.route.status;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Ambil Lokasi Dapur (Start Point)
      final origin = await _routeService.getSppgLocation();
      _sppgLocation = origin;

      // 2. Ambil daftar sekolah (Stops)
      final stopsData = await _routeService.getRouteStops(widget.route.id);
      
      // 3. Kumpulkan semua titik untuk Garis Rute
      List<LatLng> routingPoints = [];
      
      // A. Masukkan Dapur (Wajib jadi titik pertama)
      if (origin != null) {
        routingPoints.add(origin); 
        print("Start Point (Dapur): ${origin.latitude}, ${origin.longitude}");
      } else {
        print("Warning: Lokasi Dapur (SPPG) belum diset/tidak ditemukan.");
      }

      // B. Masukkan Sekolah-sekolah
      for (var stop in stopsData) {
        final school = stop['schools'];
        if (school['gps_lat'] != null && school['gps_long'] != null) {
          try {
            double lat = double.parse(school['gps_lat'].toString());
            double long = double.parse(school['gps_long'].toString());
            routingPoints.add(LatLng(lat, long));
          } catch (e) {
            print("Error parsing koordinat sekolah: $e");
          }
        }
      }

      // 4. Minta Garis Rute ke OSRM
      // Syarat bikin garis: Minimal ada 2 titik (Misal: 1 Dapur + 1 Sekolah)
      List<LatLng> polyline = [];
      if (routingPoints.length >= 2) {
         polyline = await _routeService.getRoutePolyline(routingPoints);
      }

      if (!mounted) return;
      setState(() {
        _stops = stopsData;
        _polylinePoints = polyline;
        _isLoading = false;
      });

      // 5. Fit Kamera Peta (Auto Zoom biar pas)
      if (routingPoints.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          try {
             _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routingPoints),
                padding: const EdgeInsets.all(60), // Padding agak lega
              ),
            );
          } catch (e) {
            print("Map Controller Error: $e"); 
          }
        });
      }

    } catch (e) {
      print("Error fetch data: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchGoogleMaps(double lat, double long) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$long&mode=d");
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
    _fetchData(); 
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
            height: 300, // Agak dibesarkan biar enak zoom-nya
            child: FlutterMap(
              mapController: _mapController,
              options: const MapOptions(
                initialCenter: LatLng(-6.9175, 107.6191),
                initialZoom: 13.0,
                // Interaction Flags: Memastikan user bisa cubit (pinch) & geser (drag)
                interactionOptions: InteractionOptions(
                  flags: InteractiveFlag.all, 
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mbg_monitoring',
                ),
                // GARIS RUTE (BIRU TEBAL)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polylinePoints,
                      strokeWidth: 5.0,
                      color: Colors.blueAccent,
                    ),
                  ],
                ),
                // MARKER LAYER
                MarkerLayer(
                  markers: [
                    // A. MARKER DAPUR (START) - Ikon Ungu
                    if (_sppgLocation != null)
                      Marker(
                        point: _sppgLocation!,
                        width: 50,
                        height: 50,
                        child: const Column(
                          children: [
                            Icon(Icons.store_mall_directory, color: Colors.purple, size: 35),
                            Text("DAPUR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple)),
                          ],
                        ),
                      ),

                    // B. MARKER SEKOLAH (TUJUAN) - Ikon Merah/Hijau
                    ..._stops.map((stop) {
                      final school = stop['schools'];
                      final isCompleted = stop['status'] == 'completed';
                      
                      if (school['gps_lat'] == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                      
                      double lat = double.parse(school['gps_lat'].toString());
                      double long = double.parse(school['gps_long'].toString());

                      return Marker(
                        point: LatLng(lat, long),
                        width: 45,
                        height: 45,
                        child: Column(
                          children: [
                            Icon(
                              Icons.location_on, 
                              color: isCompleted ? Colors.green : Colors.red,
                              size: 35,
                            ),
                            // Biar tau urutannya di peta
                            Container(
                               padding: const EdgeInsets.all(2),
                               decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                               child: Text("${stop['sequence_order']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold))
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
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
                      
                      double? lat;
                      double? long;
                      if (school['gps_lat'] != null) {
                         lat = double.parse(school['gps_lat'].toString());
                         long = double.parse(school['gps_long'].toString());
                      }

                      return Card(
                        color: isCompleted ? Colors.green[50] : Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isCompleted ? Colors.green : Colors.grey[300],
                            child: Text("${index + 1}", style: TextStyle(color: isCompleted ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                          ),
                          title: Text(school['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Menu: ${school['menu_default'] ?? '-'} (${school['student_count']} pax)"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // TOMBOL NAVIGASI
                              if (lat != null && long != null)
                                IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue),
                                  onPressed: () => _launchGoogleMaps(lat!, long!),
                                  tooltip: "Buka Google Maps",
                                ),
                              
                              // TOMBOL SELESAI
                              if (_currentStatus == 'active' && !isCompleted)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green, 
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16)
                                  ),
                                  onPressed: () => _completeStop(stop['id'], school['name']),
                                  child: const Text("Tiba"),
                                )
                              else if (isCompleted)
                                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            )
          : null,
    );
  }
}