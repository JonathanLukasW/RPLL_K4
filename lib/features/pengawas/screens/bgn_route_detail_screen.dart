// === FILE: lib/features/pengawas/screens/bgn_route_detail_screen.dart ===
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/route_model.dart';
import '../../admin_sppg/services/route_service.dart';

class BgnRouteDetailScreen extends StatefulWidget {
  final DeliveryRoute route;
  const BgnRouteDetailScreen({super.key, required this.route});

  @override
  State<BgnRouteDetailScreen> createState() => _BgnRouteDetailScreenState();
}

class _BgnRouteDetailScreenState extends State<BgnRouteDetailScreen> {
  final RouteService _routeService = RouteService();
  final MapController _mapController = MapController();
  List<Map<String, dynamic>> _stops = [];
  List<LatLng> _polylinePoints = [];
  LatLng? _sppgLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRouteDetails();
  }

  // --- Helper methods (minimal essential logic for rendering) ---
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.green;
      case 'issue_reported':
        return Colors.red;
      case 'completed':
        return Colors.orange;
      case 'active':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

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
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // FIX: Helper untuk Menampilkan Gambar Bukti (Diambil dari EditRouteScreen Admin)
  Widget _buildProofSection({
    required String title,
    required String? url,
    bool isRouteProof = false,
  }) {
    // BGN hanya view, jadi kita tidak perlu logika isRouteProof
    if (url == null || url.isEmpty) {
      return const SizedBox.shrink(); // Hide section if no proof
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {
            // Ini memerlukan helper _showImageDialog (asumsi sudah ada/dibuat di BgnReportScreen)
            // Untuk BGN Route Detail Screen, kita harus membuat stub/helper lokal jika belum ada.
            // Karena ini file terpisah, kita perlu buat helper lokal.
            if (mounted) {
              _showLocalImageDialog(context, url, title);
            }
          },
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

  void _showLocalImageDialog(BuildContext context, String url, String title) {
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
  // --- End Helper ---

  Future<LatLng?> _fetchSppgLocation() async {
    try {
      final response = await Supabase.instance.client
          .from('sppgs')
          .select('gps_lat, gps_long')
          .eq('id', widget.route.sppgId)
          .single();
      if (response['gps_lat'] != null) {
        return LatLng(
          double.parse(response['gps_lat'].toString()),
          double.parse(response['gps_long'].toString()),
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Logic fetch detail rute
  Future<void> _fetchRouteDetails() async {
    setState(() => _isLoading = true);
    try {
      final origin = await _fetchSppgLocation();
      _sppgLocation = origin;
      final stopsData = await _routeService.getRouteStops(widget.route.id);

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
        polyline = await _routeService.getRoutePolyline(routingPoints);
      }

      if (!mounted) return;
      setState(() {
        _stops = stopsData;
        _polylinePoints = polyline;
        _isLoading = false;
      });

      // FIX: Panggil fitCamera setelah setState selesai (post-render)
      if (routingPoints.isNotEmpty && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (routingPoints.isNotEmpty && mounted) {
            final bounds = LatLngBounds.fromPoints(routingPoints);
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- UI Components ---
  Widget _buildStopTile(Map<String, dynamic> stop, int index) {
    final school = stop['schools'];
    final status = stop['status'];
    final eta = _formatTime(stop['estimated_arrival_time']);
    final courierProofUrl = stop['courier_proof_photo_url'] as String?;
    // FIX KRITIS: Ambil bukti keluhan
    final complaintProofUrl = stop['proof_photo_url'] as String?;
    final isIssueReported = status == 'issue_reported';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(status),
          child: Text(
            "${index + 1}",
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
        subtitle: Text("Status: ${status.toUpperCase()} | ETA: $eta"),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.check_circle_outline,
                  "Penerima",
                  stop['recipient_name'] ?? 'Belum Konfirmasi',
                ),
                _buildInfoRow(
                  Icons.inventory,
                  "Porsi Diterima",
                  "${stop['received_qty'] ?? 0}",
                ),

                const SizedBox(height: 10),

                // Bukti Tiba Kurir
                _buildProofSection(
                  title: "Bukti Tiba Kurir",
                  url: courierProofUrl,
                ),

                const SizedBox(height: 10),
                // FIX KRITIS: Bukti Keluhan (jika ada issue)
                if (isIssueReported && complaintProofUrl != null)
                  _buildProofSection(
                    title: "Bukti Keluhan Penerima",
                    url: complaintProofUrl,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
    final isCompleted = widget.route.status == 'completed';
    final courierName = widget.route.courierName ?? 'N/A';

    final allPoints = [
      if (_sppgLocation != null) _sppgLocation!,
      ..._stops
          .where((s) => s['schools']['gps_lat'] != null)
          .map(
            (s) => LatLng(
              double.parse(s['schools']['gps_lat'].toString()),
              double.parse(s['schools']['gps_long'].toString()),
            ),
          ),
    ];
    // FIX KRITIS: Hapus bounds.isValid. Cek validitas dilakukan melalui list.isNotEmpty
    final bounds = allPoints.isNotEmpty
        ? LatLngBounds.fromPoints(allPoints)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text("Detail Rute: ${widget.route.vehiclePlate ?? 'N/A'}"),
        backgroundColor: isCompleted ? Colors.green[800] : Colors.blue[800],
        foregroundColor: Colors.white,
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
                          ),
                        ),
                        _buildInfoRow(
                          Icons.local_shipping,
                          "Armada",
                          widget.route.vehiclePlate ?? "N/A",
                        ),
                        _buildInfoRow(Icons.person, "Kurir Utama", courierName),
                        _buildInfoRow(
                          Icons.departure_board,
                          "Jam Berangkat",
                          _formatTime(widget.route.departureTime),
                        ),
                        _buildInfoRow(
                          Icons.check_circle_outline,
                          "Status Rute",
                          widget.route.status.toUpperCase(),
                          color: _getStatusColor(widget.route.status),
                        ),
                        const Divider(height: 30),
                        const Text(
                          "Urutan Perhentian",
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
                        // FIX AKHIR: Gunakan allPoints.isNotEmpty
                        initialCameraFit: allPoints.isNotEmpty
                            ? CameraFit.bounds(
                                bounds:
                                    bounds!, // Kita tahu bounds tidak null jika allPoints tidak kosong
                                padding: const EdgeInsets.all(50),
                              )
                            // Fallback jika tidak ada GPS data sama sekali
                            : null,
                        initialCenter: defaultCenter,
                        initialZoom: 13.0,
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
                        // Markers (Dapur dan Stops)
                        MarkerLayer(
                          markers: [
                            if (_sppgLocation != null)
                              Marker(
                                point: _sppgLocation!,
                                width: 60,
                                height: 60,
                                child: const Icon(
                                  Icons.store_mall_directory,
                                  color: Colors.purple,
                                  size: 35,
                                ),
                              ),
                            ..._stops.map((stop) {
                              final school = stop['schools'];
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
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      color: _getStatusColor(stop['status']),
                                      size: 35,
                                    ),
                                    Text(
                                      "${stop['sequence_order']}",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
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

                  // --- LIST DETAIL STOPS ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      children: List.generate(
                        _stops.length,
                        (index) => _buildStopTile(_stops[index], index),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
