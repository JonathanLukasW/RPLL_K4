// === FILE: lib/features/admin_sppg/screens/edit_route_screen.dart ===
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart'; // Untuk firstWhereOrNull
import 'package:intl/intl.dart';
import '../../../models/route_model.dart';
import '../../../models/school_model.dart';
import '../services/route_service.dart';
import '../services/school_service.dart'; // Import School Service
import 'dart:convert';

class EditRouteScreen extends StatefulWidget {
  final DeliveryRoute route;
  const EditRouteScreen({super.key, required this.route});

  @override
  State<EditRouteScreen> createState() => _EditRouteScreenState();
}

class _EditRouteScreenState extends State<EditRouteScreen> {
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _stops = []; // Detail stop + school info
  List<LatLng> _polylinePoints = [];
  LatLng? _sppgLocation;
  bool _isLoading = true;

  // [FIX 1] State untuk melacak status rute (diperlukan untuk UI proof)
  late String _currentStatus;

  @override
  void initState() {
    super.initState();
    // [FIX 2] Inisialisasi status
    _currentStatus = widget.route.status;
    _fetchRouteDetails();
  }

  // Tombol aksi (misal: Hapus Rute)
  Future<void> _deleteRoute() async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Rute?"),
        content: const Text(
          "Menghapus rute ini akan menghapus semua perhentian dan jadwal produksi terkait!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _routeService.deleteRoute(widget.route.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Rute Dihapus!")));
        Navigator.pop(context, true); // Kembali ke dashboard
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error Hapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = widget.route.date;
    try {
      dateStr = DateFormat(
        'EEEE, d MMMM yyyy',
        'id_ID',
      ).format(DateTime.parse(widget.route.date));
    } catch (_) {}

    final LatLng defaultCenter =
        _sppgLocation ?? const LatLng(-6.9175, 107.6191);

    // Mendapatkan URL bukti muat (diperbaiki dari model DeliveryRoute)
    final String? loadProofUrl = widget.route.loadProofPhotoUrl;

    return Scaffold(
      appBar: AppBar(
        title: Text("Detail Rute: ${widget.route.vehiclePlate ?? '-'}"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          if (widget.route.status == 'pending')
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: "Hapus Rute",
              onPressed: _deleteRoute,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchRouteDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- INFO UTAMA ---
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        _buildInfoRow(
                          Icons.local_shipping,
                          "Armada",
                          widget.route.vehiclePlate ?? "Mobil HILANG",
                        ),
                        _buildInfoRow(
                          Icons.person,
                          "Kurir Utama",
                          widget.route.courierName ?? "Kurir HILANG",
                        ),
                        _buildInfoRow(
                          Icons.departure_board,
                          "Jam Berangkat (Target)",
                          _formatTime(widget.route.departureTime),
                          color: Colors.red,
                        ),
                        _buildInfoRow(
                          Icons.check_circle_outline,
                          "Status Rute",
                          widget.route.status.toUpperCase(),
                          color: _getStatusColor(widget.route.status),
                        ),

                        const Divider(height: 30),

                        // [BARU]: BUKTI MUAT (LOADING PROOF)
                        _buildProofSection(
                          title: "Bukti Muat Armada (Loading Proof)",
                          url: loadProofUrl, // Menggunakan field dari model
                          isRouteProof: true,
                        ),

                        const Divider(height: 30),

                        const Text(
                          "Urutan Perhentian & Bukti Tiba",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // --- PETA RUTE ---
                  SizedBox(
                    height: 300,
                    width: double.infinity,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: defaultCenter,
                        initialZoom: 13.0,
                        initialCameraFit: CameraFit.bounds(
                          bounds: LatLngBounds.fromPoints([
                            if (_sppgLocation != null) _sppgLocation!,
                            ..._stops
                                .where((s) => s['schools']['gps_lat'] != null)
                                .map(
                                  (s) => LatLng(
                                    double.parse(
                                      s['schools']['gps_lat'].toString(),
                                    ),
                                    double.parse(
                                      s['schools']['gps_long'].toString(),
                                    ),
                                  ),
                                ),
                          ]),
                          padding: const EdgeInsets.all(50),
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.mbg_monitoring',
                        ),
                        // Polyline Rute
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _polylinePoints,
                              strokeWidth: 5.0,
                              color: Colors.blueAccent,
                            ),
                          ],
                        ),
                        // Markers
                        MarkerLayer(
                          markers: [
                            if (_sppgLocation != null)
                              Marker(
                                point: _sppgLocation!,
                                width: 80,
                                height: 80,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.store_mall_directory,
                                      color: Colors.purple,
                                      size: 40,
                                    ),
                                    Text(
                                      "DAPUR",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.purple,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Markers Sekolah
                            ..._stops.map((stop) {
                              final school = stop['schools'];
                              final isHighRisk = school['is_high_risk'] == true;
                              final isCompleted =
                                  stop['status'] == 'completed' ||
                                  stop['status'] == 'received' ||
                                  stop['status'] == 'issue_reported';

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
                                          : (isHighRisk
                                                ? Colors.red
                                                : Colors.orange),
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
                  ),

                  const Divider(thickness: 2, height: 30),

                  // --- DETAIL URUTAN SEKOLAH (STOP LIST) ---
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      "Urutan Perhentian (Optimasi Jarak & Waktu)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ..._stops.map((stop) {
                    final school = stop['schools'];
                    final courierProofUrl =
                        stop['courier_proof_photo_url'] as String?;
                    final isFinalized =
                        stop['status'] == 'received' ||
                        stop['status'] == 'issue_reported';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(stop['status']),
                          child: Text(
                            "${stop['sequence_order']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          school['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Status: ${stop['status'].toUpperCase()} | Est. Tiba: ${_formatTime(stop['estimated_arrival_time'])}",
                        ),
                        trailing: courierProofUrl != null
                            ? const Icon(
                                Icons.photo_camera,
                                color: Colors.green,
                              )
                            : const Icon(
                                Icons.pending_actions,
                                color: Colors.grey,
                              ),

                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Detail Penerimaan (Admin/Koordinator)
                                if (isFinalized)
                                  _buildInfoRow(
                                    Icons.check_circle_outline,
                                    "Diterima Koord/Wali",
                                    stop['recipient_name'] ?? 'N/A',
                                    color: Colors.green,
                                  ),

                                // Bukti Tiba Kurir
                                const SizedBox(height: 10),
                                _buildProofSection(
                                  title: "Bukti Foto Tiba Kurir",
                                  url: courierProofUrl,
                                  isRouteProof: false,
                                ),

                                // Bukti Penerimaan Sekolah (jika ada)
                                if (stop['proof_photo_url'] != null)
                                  _buildProofSection(
                                    title: "Bukti Keluhan",
                                    url: stop['proof_photo_url'],
                                    isRouteProof: false,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  // [BARU] Helper untuk Menampilkan Gambar Bukti
  Widget _buildProofSection({
    required String title,
    required String? url,
    bool isRouteProof = false,
  }) {
    if (url == null || url.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(
            isRouteProof && _currentStatus == 'pending'
                ? "Rute belum dimulai, bukti muat belum diunggah."
                : "Bukti belum tersedia.",
            style: const TextStyle(color: Colors.red),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showImageDialog(context, url, title),
          child: Container(
            height: 150,
            width: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
              image: DecorationImage(
                image: NetworkImage(url),
                fit: BoxFit.cover,
              ),
            ),
            child: const Align(
              alignment: Alignment.center,
              child: Icon(Icons.zoom_in, color: Colors.white, size: 40),
            ),
          ),
        ),
      ],
    );
  }

  // [BARU] Helper untuk Dialog Zoom Gambar
  void _showImageDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Image.network(url, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  // Function to map weekday number to local day name
  String _mapDayToLocal(int day) {
    const List<String> days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return days[day - 1];
  }

  // Existing helper for info row (assuming it exists but wasn't included in the dump)
  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  Future<void> _fetchRouteDetails() async {
    setState(() => _isLoading = true);
    try {
      final origin = await _routeService.getSppgLocation();
      _sppgLocation = origin;
      final stopsData = await _routeService.getRouteStops(widget.route.id);

      // Susun koordinat untuk polyline
      List<LatLng> routingPoints = [];
      if (origin != null) routingPoints.add(origin);
      for (var stop in stopsData) {
        final school = stop['schools'];
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
        // Ambil polyline dari OSRM
        polyline = await _routeService.getRoutePolyline(routingPoints);
      }

      if (!mounted) return;
      setState(() {
        _stops = stopsData;
        _polylinePoints = polyline;
        _isLoading = false;
        // Update current status in case it changed since we loaded the widget
        _currentStatus = widget.route.status;
      });

      // Zoom map (existing logic)
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Bukan Urusan Gue: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'received':
        return Colors.green;
      case 'issue_reported':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr ?? "--:--";
    }
  }
}
