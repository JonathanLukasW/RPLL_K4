import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/bgn_monitoring_service.dart';

class BgnTrackingScreen extends StatefulWidget {
  const BgnTrackingScreen({super.key});

  @override
  State<BgnTrackingScreen> createState() => _BgnTrackingScreenState();
}

class _BgnTrackingScreenState extends State<BgnTrackingScreen> {
  final BgnMonitoringService _service = BgnMonitoringService();
  List<Marker> _markers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSppgMarkers();
  }

  Future<void> _loadSppgMarkers() async {
    try {
      final sppgs = await _service.getAllSppgLocations();
      
      final List<Marker> markers = [];
      
      for (var sppg in sppgs) {
        // Parsing aman (Handle String atau Double)
        if (sppg['gps_lat'] != null && sppg['gps_long'] != null) {
          double lat = double.parse(sppg['gps_lat'].toString());
          double long = double.parse(sppg['gps_long'].toString());

          markers.add(
            Marker(
              point: LatLng(lat, long),
              width: 80, // Lebar diperbesar biar teks muat
              height: 80,
              child: Column(
                children: [
                  const Icon(Icons.location_city, color: Colors.blue, size: 40),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Text(
                      sppg['name'] ?? 'SPPG',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _markers = markers;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error map: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Peta Sebaran Dapur"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: const MapOptions(
                // FOKUS JAWA BARAT (Bandung)
                initialCenter: LatLng(-6.9175, 107.6191), 
                initialZoom: 10.0, // Zoom level kota/provinsi
                interactionOptions: InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.mbg_monitoring',
                ),
                MarkerLayer(markers: _markers),
              ],
            ),
    );
  }
}