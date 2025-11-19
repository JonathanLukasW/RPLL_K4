import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

class LocationPickerScreen extends StatefulWidget {
  final double initialLat;
  final double initialLong;

  const LocationPickerScreen({
    super.key,
    this.initialLat = -6.9175, // Default Bandung
    this.initialLong = 107.6191,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _pickedLocation;
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  
  double _currentZoom = 15.0; 
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _pickedLocation = LatLng(widget.initialLat, widget.initialLong);
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    FocusScope.of(context).unfocus();

    try {
      final url = Uri.parse('https://photon.komoot.io/api/?q=$query&limit=1');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        if (features.isNotEmpty) {
          final coordinates = features[0]['geometry']['coordinates'];
          final double lon = coordinates[0];
          final double lat = coordinates[1];
          final newLocation = LatLng(lat, lon);

          setState(() {
            _pickedLocation = newLocation;
          });
          _mapController.move(newLocation, 16.0);
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Lokasi tidak ditemukan.")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _zoomMap(double change) {
    setState(() {
      _currentZoom = (_currentZoom + change).clamp(3.0, 18.0);
      _mapController.move(_pickedLocation, _currentZoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Pilih Lokasi"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.pop(context, _pickedLocation);
            },
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _pickedLocation,
              initialZoom: _currentZoom,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _pickedLocation = camera.center;
                    _currentZoom = camera.zoom;
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.mbg_monitoring',
              ),
              // [PENTING] Attribution OSM (Biar Legal)
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          const Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 40.0),
              child: Icon(Icons.location_pin, color: Colors.red, size: 50),
            ),
          ),
          Positioned(
            top: 10, left: 15, right: 15,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          hintText: "Cari lokasi...", border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _searchAddress(),
                      ),
                    ),
                    IconButton(
                      icon: _isSearching 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.search),
                      onPressed: _searchAddress,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 20, bottom: 160,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: "zoom_in", onPressed: () => _zoomMap(1.0),
                  backgroundColor: Colors.white, child: const Icon(Icons.add, color: Colors.black),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.small(
                  heroTag: "zoom_out", onPressed: () => _zoomMap(-1.0),
                  backgroundColor: Colors.white, child: const Icon(Icons.remove, color: Colors.black),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30, left: 20, right: 20,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Lat: ${_pickedLocation.latitude.toStringAsFixed(5)}, Long: ${_pickedLocation.longitude.toStringAsFixed(5)}"),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(context, _pickedLocation),
                        child: const Text("PILIH LOKASI INI"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}