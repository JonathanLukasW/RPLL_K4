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
  LatLng? _sppgLocation; 
  
  bool _isLoading = true;
  String _currentStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.route.status;
    _fetchData();
  }

  // --- FUNGSI ZOOM MANUAL (BARU) ---
  void _zoomMap(double change) {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + change).clamp(3.0, 18.0); // Batas zoom
    _mapController.move(_mapController.camera.center, newZoom);
  }

  Future<void> _fetchData() async {
    try {
      print("--- MULAI AMBIL DATA RUTE ---");

      // 1. Ambil Lokasi Dapur
      final origin = await _routeService.getSppgLocation();
      _sppgLocation = origin;
      if (origin != null) print("1. Dapur: ${origin.latitude}, ${origin.longitude}");

      // 2. Ambil daftar sekolah (Stops)
      final stopsData = await _routeService.getRouteStops(widget.route.id);
      
      // 3. Susun Urutan Titik untuk Garis (Polyline)
      List<LatLng> routingPoints = [];
      
      if (origin != null) routingPoints.add(origin); 

      for (var i = 0; i < stopsData.length; i++) {
        final stop = stopsData[i];
        final school = stop['schools'];
        
        if (school['gps_lat'] != null && school['gps_long'] != null) {
          double? lat = double.tryParse(school['gps_lat'].toString());
          double? long = double.tryParse(school['gps_long'].toString());
          
          if (lat != null && long != null) {
            routingPoints.add(LatLng(lat, long));
          }
        }
      }

      // 4. Minta Garis Rute ke OSRM
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

      // 5. Fit Kamera (Zoom otomatis ke rute)
      if (routingPoints.isNotEmpty) {
        Future.delayed(const Duration(seconds: 1), () {
          if (!mounted) return;
          try {
             _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(routingPoints),
                padding: const EdgeInsets.all(60), 
              ),
            );
          } catch (e) { print("Map Camera Error: $e"); }
        });
      }

    } catch (e) {
      print("Error fetch data: $e");
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchGoogleMaps(double lat, double long) async {
    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$long&mode=d");
    try {
        await launchUrl(googleMapsUrl);
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
          // 1. PETA NAVIGASI (ATAS) - SEKARANG PAKAI STACK
          // -------------------------------------------------------
          SizedBox(
            height: 300, 
            child: Stack(
              children: [
                // A. MAP UTAMA
                FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(-6.9175, 107.6191),
                    initialZoom: 13.0,
                    interactionOptions: InteractionOptions(
                      flags: InteractiveFlag.all, 
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.mbg_monitoring',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _polylinePoints,
                          strokeWidth: 5.0,
                          color: Colors.blueAccent,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        if (_sppgLocation != null)
                          Marker(
                            point: _sppgLocation!,
                            width: 60, 
                            height: 60, 
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.store_mall_directory, color: Colors.purple, size: 35),
                                Text("DAPUR", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.purple, backgroundColor: Colors.white70)),
                              ],
                            ),
                          ),

                        ..._stops.map((stop) {
                          final school = stop['schools'];
                          final isCompleted = stop['status'] == 'completed';
                          
                          if (school['gps_lat'] == null) return const Marker(point: LatLng(0,0), child: SizedBox());
                          
                          double lat = double.parse(school['gps_lat'].toString());
                          double long = double.parse(school['gps_long'].toString());

                          return Marker(
                            point: LatLng(lat, long),
                            width: 60,
                            height: 60, 
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on, 
                                  color: isCompleted ? Colors.green : Colors.red,
                                  size: 35,
                                ),
                                Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                   decoration: BoxDecoration(
                                     color: Colors.white, 
                                     borderRadius: BorderRadius.circular(4),
                                     border: Border.all(color: Colors.grey)
                                   ),
                                   child: Text(
                                     "${stop['sequence_order']}", 
                                     style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                                   )
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),

                // B. TOMBOL ZOOM (OVERLAY)
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: "btnZoomIn", // Wajib unik biar ga error
                        onPressed: () => _zoomMap(1),
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.add, color: Colors.black),
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton.small(
                        heroTag: "btnZoomOut",
                        onPressed: () => _zoomMap(-1),
                        backgroundColor: Colors.white,
                        child: const Icon(Icons.remove, color: Colors.black),
                      ),
                    ],
                  ),
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
                              if (lat != null && long != null)
                                IconButton(
                                  icon: const Icon(Icons.directions, color: Colors.blue),
                                  onPressed: () => _launchGoogleMaps(lat!, long!),
                                  tooltip: "Navigasi",
                                ),
                              
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