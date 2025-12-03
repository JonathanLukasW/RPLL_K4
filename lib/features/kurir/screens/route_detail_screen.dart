// === FILE: lib/features/kurir/screens/route_detail_screen.dart ===
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';

import '../../admin_sppg/services/route_service.dart';
import '../../../models/route_model.dart';
import '../../../core/services/storage_service.dart';

class RouteDetailScreen extends StatefulWidget {
  final DeliveryRoute route;

  const RouteDetailScreen({super.key, required this.route});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen> {
  final RouteService _routeService = RouteService();
  final StorageService _storageService = StorageService();
  final MapController _mapController = MapController();

  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _polylinePoints = [];
  LatLng? _sppgLocation;

  bool _isLoading = true;
  String _currentStatus = 'pending';

  // [BARU] Variabel untuk Jam Berangkat
  String _departureTime = "--:--";

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.route.status;
    _departureTime = _formatTime(
      widget.route.departureTime,
    ); // Ambil dari Model Route
    _fetchData();
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      // Format HH:mm:ss -> HH:mm
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr;
    }
  }

  void _zoomMap(double change) {
    final currentZoom = _mapController.camera.zoom;
    final newZoom = (currentZoom + change).clamp(3.0, 18.0);
    _mapController.move(_mapController.camera.center, newZoom);
  }

  Future<void> _fetchData() async {
    try {
      final origin = await _routeService.getSppgLocation();
      _sppgLocation = origin;

      final stopsData = await _routeService.getRouteStops(widget.route.id);

      List<LatLng> routingPoints = [];
      if (origin != null) routingPoints.add(origin);

      for (var i = 0; i < stopsData.length; i++) {
        final school = stopsData[i]['schools'];
        if (school['gps_lat'] != null && school['gps_long'] != null) {
          double? lat = double.tryParse(school['gps_lat'].toString());
          double? long = double.tryParse(school['gps_long'].toString());
          if (lat != null && long != null) {
            routingPoints.add(LatLng(lat, long));
          }
        }
      }

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
          } catch (_) {}
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // [BARU] Fungsi Cek & Selesaikan Rute
  Future<void> _tryCompleteRoute() async {
    setState(() => _isLoading = true); // Use isLoading for temporary UI block
    try {
      // 1. Re-fetch stops to ensure data is up-to-date
      final stopsData = await _routeService.getRouteStops(widget.route.id);
      final totalStops = stopsData.length;
      final completedStops = stopsData
          .where((s) => s['status'] == 'completed')
          .length;

      if (completedStops < totalStops) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Belum semua sekolah Selesai (Completed)! Cek lagi, bego.",
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // 2. Jika SEMUA stop sudah 'completed', baru update route status ke 'completed'
      await _routeService.updateRouteStatus(widget.route.id, 'completed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Rute SELESAI TOTAL! Good job, I guess. Status diubah ke Completed.",
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
      // Update local state and exit
      setState(() {
        _currentStatus = 'completed';
        _isLoading = false; // Turn off loading here, it's done.
      });
      // Optional: Pop the screen and refresh the previous list
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal menyelesaikan rute: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchGoogleMaps(double lat, double long) async {
    final Uri googleMapsUrl = Uri.parse(
      "google.navigation:q=$lat,$long&mode=d",
    );
    try {
      await launchUrl(googleMapsUrl);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  void _showValidationDialog() {
    File? photoFile;
    bool isSubmitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("Validasi Muatan"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Wajib lampirkan foto muatan di mobil."),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final file = await _storageService.pickImage(
                      ImageSource.camera,
                    );
                    if (file != null) setDialogState(() => photoFile = file);
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: photoFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 30),
                              Text("FOTO BUKTI MUAT"),
                            ],
                          )
                        : Image.file(photoFile!, fit: BoxFit.cover),
                  ),
                ),
                if (isSubmitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal"),
                ),
              if (!isSubmitting)
                ElevatedButton(
                  onPressed: () async {
                    if (photoFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Foto bukti wajib ada!")),
                      );
                      return;
                    }
                    setDialogState(() => isSubmitting = true);
                    try {
                      final url = await _storageService.uploadEvidence(
                        photoFile!,
                        'loading_proof',
                      );
                      await _routeService.validateLoadWithPhoto(
                        widget.route.id,
                        url,
                      );
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      setState(() => _currentStatus = 'active');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Pengiriman Dimulai!")),
                      );
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                    }
                  },
                  child: const Text("Mulai Pengiriman"),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showCompleteDialog(String stopId, String schoolName) {
    File? photoFile;
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Tiba di $schoolName"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Lampirkan foto bukti makanan sampai."),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final file = await _storageService.pickImage(
                      ImageSource.camera,
                    );
                    if (file != null) setDialogState(() => photoFile = file);
                  },
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.grey),
                    ),
                    child: photoFile == null
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt),
                              Text("FOTO BUKTI"),
                            ],
                          )
                        : Image.file(photoFile!, fit: BoxFit.cover),
                  ),
                ),
                if (isSubmitting)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal"),
                ),
              if (!isSubmitting)
                ElevatedButton(
                  onPressed: () async {
                    if (photoFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Foto bukti wajib ada!")),
                      );
                      return;
                    }
                    setDialogState(() => isSubmitting = true);
                    try {
                      final url = await _storageService.uploadEvidence(
                        photoFile!,
                        'arrival_proof',
                      );
                      // Use completeStopWithPhoto which sets status to 'completed'
                      await _routeService.completeStopWithPhoto(stopId, url);
                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _fetchData(); // Refresh list stops
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Selesai di $schoolName!")),
                      );
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                    }
                  },
                  child: const Text("Selesai"),
                ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool allStopsCompleted =
        _stops.isNotEmpty && _stops.every((s) => s['status'] == 'completed');
    final bool isRouteActive = _currentStatus == 'active';
    final bool isRouteCompleted = _currentStatus == 'completed';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Pengiriman"),
        backgroundColor: isRouteCompleted
            ? Colors.green[800]
            : (isRouteActive ? Colors.green[700] : Colors.blue[800]),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- PETA (TETAP SAMA) ---
          SizedBox(
            height: 250,
            child: Stack(
              children: [
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
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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
                                Icon(
                                  Icons.store_mall_directory,
                                  color: Colors.purple,
                                  size: 35,
                                ),
                                Text(
                                  "DAPUR",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple,
                                    backgroundColor: Colors.white70,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ..._stops.map((stop) {
                          final school = stop['schools'];
                          final isCompleted = stop['status'] == 'completed';
                          if (school['gps_lat'] == null)
                            return const Marker(
                              point: LatLng(0, 0),
                              child: SizedBox(),
                            );
                          double lat = double.parse(
                            school['gps_lat'].toString(),
                          );
                          double long = double.parse(
                            school['gps_long'].toString(),
                          );
                          return Marker(
                            point: LatLng(lat, long),
                            width: 60,
                            height: 60,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: isCompleted
                                      ? Colors.green
                                      : Colors.red,
                                  size: 35,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.grey),
                                  ),
                                  child: Text(
                                    "${stop['sequence_order']}",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Column(
                    children: [
                      FloatingActionButton.small(
                        heroTag: "btnZoomIn",
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

          // --- [BARU] INFO JADWAL BERANGKAT ---
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.orange[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Jadwal Berangkat:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  _departureTime,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ),

          // LIST SEKOLAH
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

                      // Ambil ETA (Estimasi Tiba)
                      String eta = _formatTime(stop['estimated_arrival_time']);

                      double? lat, long;
                      if (school['gps_lat'] != null) {
                        lat = double.parse(school['gps_lat'].toString());
                        long = double.parse(school['gps_long'].toString());
                      }

                      return Card(
                        color: isCompleted ? Colors.green[50] : Colors.white,
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: isCompleted
                                ? Colors.green
                                : Colors.grey[300],
                            child: Text(
                              "${index + 1}",
                              style: TextStyle(
                                color: isCompleted
                                    ? Colors.white
                                    : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(
                            school['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          // [BARU] Tampilkan Estimasi Tiba
                          subtitle: Text(
                            "Est. Tiba: $eta\nMenu: ${school['menu_default'] ?? '-'}",
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (lat != null && long != null)
                                IconButton(
                                  icon: const Icon(
                                    Icons.directions,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () =>
                                      _launchGoogleMaps(lat!, long!),
                                  tooltip: "Navigasi",
                                ),

                              if (_currentStatus == 'active' && !isCompleted)
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () => _showCompleteDialog(
                                    stop['id'],
                                    school['name'],
                                  ),
                                  child: const Text("Tiba"),
                                )
                              else if (isCompleted)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 32,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      bottomNavigationBar: isRouteCompleted
          ? null
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. VALIDASI & MULAI (HANYA MUNCUL JIKA PENDING)
                  if (_currentStatus == 'pending')
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _showValidationDialog,
                        icon: const Icon(Icons.checklist),
                        label: const Text("VALIDASI MUATAN & MULAI"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),

                  // 2. SELESAIKAN RUTE (HANYA MUNCUL JIKA ACTIVE DAN SEMUA STOP COMPLETED)
                  if (isRouteActive && allStopsCompleted) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _tryCompleteRoute, // New function call
                        icon: const Icon(Icons.check_circle),
                        label: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "SELESAIKAN PENGIRIMAN TOTAL",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
