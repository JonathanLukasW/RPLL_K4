// === FILE: lib/features/admin_sppg/screens/statistics_screen.dart ===
import 'package:fl_chart/fl_chart.dart'; // Import Library Grafik
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Untuk mengurai JSON Issue Details

import '../../../models/courier_model.dart';
// [FIX 1]: Import Model DeliveryRoute yang hilang
import '../../../models/route_model.dart';
import '../services/stats_service.dart';
// BARU: Import service report yang baru kita buat
import '../services/stats_service.dart';
import '../services/report_service.dart';
import '../services/complaint_service.dart'; // <--- PASTIKAN INI ADA
import '../services/coordinator_service.dart';
import '../services/teacher_service.dart';
import '../../../models/vehicle_model.dart'; // Import Vehicle Model
import '../services/vehicle_service.dart'; // Import Vehicle Service
import 'edit_route_screen.dart'; // Import EditRouteScreen
import 'edit_account_screen.dart'; // <--- DITAMBAH: Fix Error

import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart';
// Tambahkan import collection untuk mapIndexed
import 'package:collection/collection.dart';
import '../../../models/school_model.dart'; // <--- PASTIKAN INI ADA
import '../../admin_sppg/services/school_service.dart'; // <--- PASTIKAN INI ADA

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  // ===================================
  // 1. FIX: DEKLARASI MISSING FIELDS
  // ===================================
  late TabController _tabController;
  final StatsService _statsService = StatsService();
  final AdminReportService _reportService = AdminReportService();
  final VehicleService _vehicleService = VehicleService();
  final ComplaintService _complaintService = ComplaintService();
  // [NEWLY ADDED] School Service (untuk filter sekolah)
  final SchoolService _schoolService = SchoolService();
  final CourierService _courierService = CourierService();
  final CoordinatorService _coordinatorService = CoordinatorService();
  final TeacherService _teacherService = TeacherService();
  final RouteService _routeService = RouteService();

  Key _complaintKey = UniqueKey();
  Map<String, int>? _stats;
  bool _isLoading = true;

  DateTime _selectedRouteDate = DateTime.now();
  String? _selectedVehicleId;
  List<Vehicle> _allVehicles = [];

  // FIX SCOPE: Tambahkan Field yang Hilang/Tidak Terdefinisi
  String? _selectedSchoolFilterId; // <--- DITAMBAH
  List<School> _allSchools = []; // <--- DITAMBAH

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // FIX: Tambahkan load schools di sini
    final results = await Future.wait([
      _loadStats(),
      _loadVehicles(),
      _loadSchools(), // <--- NEW CALL
    ]);
    _refreshAllTabs();
  }

  // FIX: Tambahkan method load schools
  Future<void> _loadSchools() async {
    try {
      final data = await _schoolService.getMySchools();
      if (mounted) {
        setState(() {
          _allSchools = data;
        });
      }
    } catch (e) {
      print("Error loading schools for filter: $e");
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await _statsService.getDeliveryStats();
      if (mounted) {
        setState(() {
          _stats = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadVehicles() async {
    try {
      final data = await _vehicleService.getMyVehicles();
      if (mounted) {
        setState(() {
          _allVehicles = data;
          _selectedVehicleId = 'all';
        });
      }
    } catch (e) {
      print("Error loading vehicles: $e");
    }
  }

  void _refreshAllTabs() {
    _loadStats();
    setState(() {
      _complaintKey = UniqueKey();
    });
  }

  // Helper untuk memformat waktu
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr;
    }
  }

  // Helper untuk mendapatkan warna status
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

  // [BARU HELPER] Mengurai JSON Issue Details dari Koordinator/Wali Kelas (Dipindahkan ke sini agar dapat diakses oleh widget lokal)
  String _formatComplaintDetails(String reporterRole, String rawNotes) {
    if (rawNotes.isEmpty) return 'Tidak ada detail spesifik.';

    // Kasus 1: Laporan Koordinator (Diharapkan format JSON Array dari issue_details)
    if (reporterRole == 'koordinator') {
      try {
        String cleanedNotes = rawNotes.trim();

        // [FIX KRITIS JSON STRING]: Hapus quotes ganda di awal/akhir
        if (cleanedNotes.startsWith('"') && cleanedNotes.endsWith('"')) {
          cleanedNotes = cleanedNotes.substring(1, cleanedNotes.length - 1);
        }
        // Hapus escape character '\' yang mungkin tersisa
        cleanedNotes = cleanedNotes.replaceAll(r'\"', '"');

        final List<dynamic> issues = jsonDecode(cleanedNotes);

        if (issues.isEmpty) return 'Diterima, tetapi detail masalah kosong.';

        return issues
            .mapIndexed((index, issue) {
              final type = issue['type'] ?? 'Masalah Umum';
              final notes = issue['notes']?.trim() ?? '—';
              final qty = issue['qty_impacted'];

              String qtyStr = '';
              if (type == 'Jumlah Tidak Sesuai') {
                qtyStr = ' (Defisit: ${qty} Porsi)';
              } else if (type == 'Kemasan Rusak') {
                qtyStr = ' (Rusak: ${qty} Kotak)';
              } else if (type == 'Terlambat') {
                qtyStr = ' (Telat: ${qty} Menit)';
              }

              return '${index + 1}. [${type}]${qtyStr}. Detail: "${notes}"';
            })
            .join('\n');
      } catch (e) {
        // Jika decoding JSON masih gagal
        return 'Detail Masalah JSON Rusak. Raw Data: $rawNotes';
      }
    }
    // Kasus 2: Laporan Wali Kelas (Masih menggunakan format notes lama/tunggal)
    else {
      return rawNotes;
    }
  }

  // [BARU HELPER] Fungsi untuk menampilkan dialog detail rute
  void _showRouteDetailDialog(Map<String, dynamic> route) {
    final List<dynamic> stops = route['delivery_stops'] ?? [];
    final List<dynamic> menuItems = route['route_menus'] ?? [];

    // Hitung ringkasan status stops
    final int totalStops = stops.length;
    final int issues = stops
        .where((s) => s['status'] == 'issue_reported')
        .length;
    final int received = stops.where((s) => s['status'] == 'received').length;
    final int completedCourier = stops
        .where((s) => s['status'] == 'completed')
        .length;
    final int pending = totalStops - issues - received - completedCourier;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Detail Rute: ${route['vehicles']['plate_number']}"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info Umum
                _buildInfoRow(
                  Icons.calendar_today,
                  "Tanggal",
                  DateFormat(
                    'EEEE, d MMMM yyyy',
                    'id_ID',
                  ).format(DateTime.parse(route['date'])),
                ),
                _buildInfoRow(
                  Icons.departure_board,
                  "Jam Berangkat",
                  _formatTime(route['departure_time']),
                ),
                _buildInfoRow(
                  Icons.person,
                  "Kurir",
                  route['profiles!courier_id']?['full_name'] ?? 'N/A',
                ),
                const Divider(height: 20),

                // Ringkasan Status Stops
                const Text(
                  "Status Perhentian",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                _buildInfoRow(
                  Icons.check_circle,
                  "Diterima Koord",
                  "$received Stop",
                  color: Colors.green,
                ),
                _buildInfoRow(
                  Icons.warning,
                  "Ada Keluhan",
                  "$issues Stop",
                  color: Colors.red,
                ),
                _buildInfoRow(
                  Icons.timer,
                  "Selesai Kurir (Menunggu Konf.)",
                  "$completedCourier Stop",
                  color: Colors.orange,
                ),
                _buildInfoRow(
                  Icons.pending_actions,
                  "Pending/Active",
                  "$pending Stop",
                  color: Colors.grey,
                ),
                _buildInfoRow(
                  Icons.route,
                  "Total Perhentian",
                  "$totalStops Stop",
                ),
                const Divider(height: 20),

                // Daftar Menu
                const Text(
                  "Menu yang Dibawa",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                ...menuItems.map((menuRoute) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      "• ${menuRoute['menus']['name']}",
                      style: TextStyle(fontSize: 13),
                    ),
                  );
                }).toList(),
                const Divider(height: 20),

                // Daftar Stops Detail
                const Text(
                  "Urutan Stops",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 8),
                ...stops.map((stop) {
                  final schoolName = stop['schools']['name'];
                  final status = stop['status'];
                  final eta = _formatTime(stop['estimated_arrival_time']);
                  final actualTime = stop['arrival_time'] != null
                      ? _formatTime(stop['arrival_time'])
                      : '--:--';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${stop['sequence_order']}. ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                schoolName,
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(
                                "Status: ${status.toUpperCase()} | ETA: $eta | Tiba: $actualTime",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getStatusColor(status),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("TUTUP"),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EditRouteScreen(route: DeliveryRoute.fromJson(route)),
                ),
              );
            },
            icon: const Icon(Icons.edit, size: 18),
            label: const Text("DETAIL DI MAP"),
          ),
        ],
      ),
    );
  }

  // Helper untuk info row (diperlukan di dalam dialog)
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
          Icon(icon, size: 18, color: const Color.fromARGB(255, 189, 0, 0)),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // [NEW HELPER] Helper untuk menampilkan dialog zoom gambar
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

  // ===================================
  // 2. FIX: IMPLEMENTASI MISSING HELPER METHODS
  // ===================================

  // FIX MISSING METHOD: _showHistoryDetailDialog (diperlukan di Tab 4)
  void _showHistoryDetailDialog(Map<String, dynamic> complaint) {
    final photoUrl = complaint['proof_photo_url']; // Ambil URL Foto
    final reporterRole = complaint['reporter_role'];
    final complaintDetails = _formatComplaintDetails(
      reporterRole,
      complaint['notes'],
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Riwayat Tindak Lanjut: ${complaint['school_name']}"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(
                Icons.person,
                "Pelapor",
                "${complaint['reporter_name']} (${reporterRole.toUpperCase()})",
              ),
              _buildInfoRow(
                Icons.check_circle,
                "Status",
                "SUDAH DITANGANI",
                color: Colors.green,
              ),
              const Divider(),
              const Text(
                "Rincian Keluhan:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  complaintDetails,
                  style: TextStyle(fontSize: 13, color: Colors.red[900]),
                ),
              ),

              // [NEW SECTION] Foto Bukti Pengaduan
              if (photoUrl != null && photoUrl.isNotEmpty) ...[
                const SizedBox(height: 15),
                const Text(
                  "Bukti Foto Pelapor:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageDialog(
                    context,
                    photoUrl,
                    "Bukti dari ${complaint['reporter_name']}",
                  ),
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white70),
                  ),
                ),
              ],

              const SizedBox(height: 15),
              const Text(
                "Respon Admin:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(complaint['admin_response'] ?? 'N/A'),
            ],
          ),
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

  // FIX MISSING METHOD: _showRespondDialog (diperlukan di Tab 4)
  void _showRespondDialog(
    Map<String, dynamic> complaint,
    String targetTable,
    String targetTableId,
  ) {
    final responseController = TextEditingController();
    final photoUrl =
        complaint['proof_photo_url']; // Ambil URL Foto untuk ditampilkan di dialog respon
    final complaintDetails = _formatComplaintDetails(
      complaint['reporter_role'],
      complaint['notes'],
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tindak Lanjut Keluhan"),
        content: SingleChildScrollView(
          // Tambahkan SingleChildScrollView
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail Keluhan (seperti di showHistoryDetailDialog)
              const Text(
                "Rincian Keluhan:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  complaintDetails,
                  style: TextStyle(fontSize: 13, color: Colors.red[900]),
                ),
              ),

              // [NEW SECTION] Foto Bukti Pengaduan di Dialog Respon
              if (photoUrl != null && photoUrl.isNotEmpty) ...[
                const SizedBox(height: 15),
                const Text(
                  "Bukti Foto Pelapor:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageDialog(
                    context,
                    photoUrl,
                    "Bukti dari ${complaint['reporter_name']}",
                  ),
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white70),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              // Input Respon Admin
              const Text(
                "Respon Admin:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              TextField(
                controller: responseController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: "Instruksi / Tindak Lanjut Admin SPPG",
                  hintText: "Contoh: Sudah kami cek...",
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (responseController.text.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wajib isi instruksi!")),
                );
                return;
              }
              Navigator.pop(ctx);
              // Logic submit response (tetap sama)
              String finalReporterUserId;
              try {
                finalReporterUserId = await _complaintService
                    .getReporterIdForNotification(
                      targetTableId,
                      complaint['reporter_role'],
                    );
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Gagal tentukan penerima notifikasi: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                return;
              }
              await _complaintService.respondToComplaint(
                id: complaint['id'],
                response: responseController.text,
                reporterId: finalReporterUserId,
                reporterRole: complaint['reporter_role'],
                targetTableId: targetTableId,
                targetTableName: targetTable,
              );
              _refreshAllTabs();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tindak Lanjut & Notifikasi Terkirim!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("KIRIM INSTRUKSI"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAllTabs,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true,
          tabs: const [
            Tab(text: "1. Pengiriman"), // Ganti nama tab
            Tab(text: "2. Rute & Detail"),
            Tab(text: "3. Anggota"),
            Tab(text: "4. Keluhan"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGlobalStatsTab(),
          _buildRoutesDetailTab(),
          _buildPersonnelTab(),
          _buildComplaintsTab(),
        ],
      ),
    );
  }

  // [REWRITE] TAB 1: Pengiriman (Mengganti Pie Chart dengan List Interaktif)
  Widget _buildGlobalStatsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null)
      return const Center(child: Text("Gagal memuat data statistik."));

    // List Item Dropdown Mobil
    final List<DropdownMenuItem<String?>> vehicleItems = [
      const DropdownMenuItem(value: 'all', child: Text("Semua Mobil")),
      ..._allVehicles.map(
        (vehicle) => DropdownMenuItem(
          value: vehicle.id,
          child: Text(vehicle.plateNumber),
        ),
      ),
    ];

    // Filter dan List Route yang akan ditampilkan di Tab 1 (Semua Route dengan filter tanggal/mobil)
    return Column(
      children: [
        // FILTER Section (Sama dengan Tab 2)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Filter Tanggal
              Expanded(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.grey),
                  title: Text(
                    DateFormat(
                      'd MMMM yyyy',
                      'id_ID',
                    ).format(_selectedRouteDate),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedRouteDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && picked != _selectedRouteDate) {
                      setState(() {
                        _selectedRouteDate = picked;
                      });
                    }
                  },
                ),
              ),
              // Filter Mobil
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedVehicleId,
                  decoration: const InputDecoration(labelText: "Filter Mobil"),
                  items: vehicleItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedVehicleId = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Ringkasan Status
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatChip("TOTAL", _stats!['total']!, Colors.indigo),
              _buildStatChip("SUKSES", _stats!['received']!, Colors.green),
              _buildStatChip("MASALAH", _stats!['issues']!, Colors.red),
            ],
          ),
        ),
        const Divider(),

        // Daftar Semua Rute (Interaktif)
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _reportService.getDetailedRoutes(
              date: _selectedRouteDate,
              vehicleId: _selectedVehicleId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              final routes = snapshot.data ?? [];
              if (routes.isEmpty)
                return const Center(
                  child: Text("Tidak ada aktivitas pengiriman."),
                );

              return ListView.builder(
                itemCount: routes.length,
                itemBuilder: (ctx, i) {
                  final route = routes[i];
                  final courierName =
                      route['courier_data']?['full_name'] ?? 'Kurir N/A';
                  final status = route['status'];
                  final formattedDate = DateFormat(
                    'dd MMM yy',
                  ).format(DateTime.parse(route['date']));

                  // [FIX MINOR WARNA CARD]: Jika pending/active, gunakan grey/putih. Jika final, gunakan warna status.
                  Color cardColor;
                  if (status == 'received') {
                    cardColor = Colors.green[50]!;
                  } else if (status == 'issue_reported') {
                    cardColor = Colors.red[50]!;
                  } else {
                    // pending, active, completed (semua ini adalah rute ongoing/history biasa)
                    cardColor = Colors.grey[100]!;
                  }

                  return Card(
                    color: cardColor, // <-- Menggunakan cardColor baru
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      onTap: () => _showRouteDetailDialog(route),
                      leading: Icon(
                        Icons.local_shipping,
                        color: _getStatusColor(status),
                      ),
                      title: Text(
                        "$formattedDate - ${route['vehicles']['plate_number']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Kurir: $courierName | Status: ${status.toUpperCase()}",
                      ),
                      trailing: const Icon(Icons.info_outline, size: 16),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String title, int value, Color color) {
    return Column(
      children: [
        Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // TAB 2: RUTE & DETAIL (Diperbarui untuk menggunakan filter)
  Widget _buildRoutesDetailTab() {
    // List Item Dropdown Mobil
    final List<DropdownMenuItem<String?>> vehicleItems = [
      const DropdownMenuItem(value: 'all', child: Text("Semua Mobil")),
      ..._allVehicles.map(
        (vehicle) => DropdownMenuItem(
          value: vehicle.id,
          child: Text(vehicle.plateNumber),
        ),
      ),
    ];

    return Column(
      children: [
        // FILTER Section (Sama dengan Tab 1)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Filter Tanggal
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                  ),
                  title: Text(
                    DateFormat(
                      'd MMMM yyyy',
                      'id_ID',
                    ).format(_selectedRouteDate),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedRouteDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null && picked != _selectedRouteDate) {
                      setState(() {
                        _selectedRouteDate = picked;
                      });
                    }
                  },
                ),
              ),
              // Filter Mobil
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedVehicleId,
                  decoration: const InputDecoration(labelText: "Filter Mobil"),
                  items: vehicleItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedVehicleId = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        // LIST RUTE HASIL FILTER
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            // Panggil service dengan filter yang baru
            future: _reportService.getDetailedRoutes(
              date: _selectedRouteDate,
              vehicleId: _selectedVehicleId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final routes = snapshot.data ?? [];
              if (routes.isEmpty)
                return const Center(
                  child: Text("Tidak ada rute yang cocok dengan filter."),
                );
              return ListView.builder(
                itemCount: routes.length,
                itemBuilder: (ctx, i) {
                  final route = routes[i];
                  // [FIX AKSES DATA KURIR DARI ALIAS BARU]
                  final courierName =
                      route['courier_data']?['full_name'] ?? 'Kurir N/A';
                  final status = route['status'];
                  final isOngoing = status == 'active' || status == 'pending';
                  final formattedDate = DateFormat(
                    'dd MMM yy',
                  ).format(DateTime.parse(route['date']));
                  return Card(
                    color: isOngoing ? Colors.blue[50] : Colors.grey[100],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditRouteScreen(
                              route: DeliveryRoute.fromJson(
                                route,
                              ), // Pass Map ke Model
                            ),
                          ),
                        );
                      },
                      leading: Icon(
                        isOngoing ? Icons.directions_run : Icons.local_shipping,
                        color: isOngoing ? Colors.blue : Colors.grey,
                      ),
                      title: Text(
                        "[${isOngoing ? 'ONGOING' : 'HISTORY'}] $formattedDate - ${route['vehicles']['plate_number']}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Kurir: $courierName | Status: ${status.toUpperCase()}", // <-- GUNAKAN ALIAS BARU
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      // ...
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // [BARU HELPER] DARI DashboardAdminScreen
  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // [BARU HELPER] DARI DashboardAdminScreen
  int _sortClasses(String? a, String? b) {
    if (a == null || b == null) return 0;
    final exp = RegExp(r'^(\d+)([a-zA-Z]*)');
    final matchA = exp.firstMatch(a.toUpperCase());
    final matchB = exp.firstMatch(b.toUpperCase());
    if (matchA == null || matchB == null) return a.compareTo(b);
    final numA = int.tryParse(matchA.group(1)!) ?? 0;
    final numB = int.tryParse(matchB.group(1)!) ?? 0;
    final charA = matchA.group(2) ?? '';
    final charB = matchB.group(2) ?? '';
    if (numA != numB) return numA.compareTo(numB);
    return charA.compareTo(charB);
  }

  // [REMAKE TOTAL] TAB 3: ANGGOTA - KITA PAKAI FUNGSI MIRIP DENGAN ADMIN DASHBOARD

  Widget _buildPersonnelTab() {
    // Kita bagi per section agar datanya terjamin dari service masing-masing.
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ------------------------------------
        // SECTION 1: KURIR
        // ------------------------------------
        Text(
          "KURIR",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        const Divider(thickness: 2),
        _buildCourierSection(),
        const SizedBox(height: 30),

        // ------------------------------------
        // SECTION 2: KOORDINATOR
        // ------------------------------------
        Text(
          "KOORDINATOR",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        const Divider(thickness: 2),
        _buildCoordinatorSection(),
        const SizedBox(height: 30),

        // ------------------------------------
        // SECTION 3: WALI KELAS
        // ------------------------------------
        Text(
          "WALI KELAS",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.orange[800],
          ),
        ),
        const Divider(thickness: 2),
        _buildTeacherSection(),
      ],
    );
  }

  // ===========================================
  // HELPER SECTION FOR REMADE TAB 3
  // ===========================================

  Widget _buildCourierSection() {
    return FutureBuilder<List<CourierModel>>(
      future: _courierService.getMyCouriers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final couriers = snapshot.data ?? [];
        if (couriers.isEmpty)
          return _buildEmptyState(
            "Belum ada akun kurir.",
            Icons.person_off_outlined,
          );

        return Column(
          children: couriers.map((courier) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.local_shipping,
                  color: Colors.blueGrey,
                ),
                title: Text(
                  courier.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${courier.email}\nTelp: ${courier.phoneNumber ?? '-'}",
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  onPressed: () => _navigateToEditAccount(courier.id, 'kurir', {
                    'name': courier.name,
                    'email': courier.email,
                    'schoolId': null,
                    'className': null,
                    'phoneNumber': courier.phoneNumber,
                  }),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildCoordinatorSection() {
    // Koordinator Service sudah mengembalikan CoordinatorModel yang mencakup schoolName.
    return FutureBuilder<List<CoordinatorModel>>(
      future: _coordinatorService.getMyCoordinators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final coordinators = snapshot.data ?? [];
        if (coordinators.isEmpty)
          return _buildEmptyState(
            "Belum ada akun koordinator.",
            Icons.supervised_user_circle,
          );

        // Sorting: Sort berdasarkan Nama Sekolah (Ascending)
        coordinators.sort(
          (a, b) =>
              a.schoolName.toLowerCase().compareTo(b.schoolName.toLowerCase()),
        );

        return Column(
          children: coordinators.map((coord) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(
                  Icons.supervised_user_circle,
                  color: Colors.teal,
                ),
                title: Text(
                  coord.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Sekolah: ${coord.schoolName}\n${coord.email}\nTelp: ${coord.phoneNumber ?? '-'}",
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  onPressed: () =>
                      _navigateToEditAccount(coord.id, 'koordinator', {
                        'name': coord.name,
                        'email': coord.email,
                        'schoolId': coord.schoolId,
                        'className': null,
                        'phoneNumber': coord.phoneNumber,
                        'schoolName': coord.schoolName,
                      }),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildTeacherSection() {
    return FutureBuilder<List<TeacherModel>>(
      future: _teacherService.getMyTeachers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final teachers = snapshot.data ?? [];
        if (teachers.isEmpty)
          return _buildEmptyState("Belum ada akun wali kelas.", Icons.class_);

        // Sorting: Sort by School Name then Class Name
        teachers.sort((a, b) {
          final schoolCompare = a.schoolName.toLowerCase().compareTo(
            b.schoolName.toLowerCase(),
          );
          if (schoolCompare != 0) return schoolCompare;
          return _sortClasses(a.className, b.className);
        });

        return Column(
          children: teachers.map((teacher) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.class_, color: Colors.indigo),
                title: Text(
                  teacher.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Kelas ${teacher.className} (${teacher.studentCountClass} Siswa) @ ${teacher.schoolName}\n${teacher.email}\nTelp: ${teacher.phoneNumber ?? '-'}",
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                trailing: IconButton(
                  icon: const Icon(Icons.info_outline, color: Colors.grey),
                  onPressed: () =>
                      _navigateToEditAccount(teacher.id, 'walikelas', {
                        'name': teacher.name,
                        'email': teacher.email,
                        'schoolId': teacher.schoolId,
                        'className': teacher.className,
                        'phoneNumber': teacher.phoneNumber,
                        'schoolName': teacher.schoolName,
                        'studentCountClass': teacher.studentCountClass,
                      }),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // Navigation Helper
  void _navigateToEditAccount(
    String userId,
    String role,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountScreen(
          userId: userId,
          initialRole: role,
          initialData: data,
        ),
      ),
    );
  }

  // [REMAKE TOTAL] TAB 4: KELUHAN MASUK (Enhanced View + Filter)
  Widget _buildComplaintsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null)
      return const Center(child: Text("Gagal memuat data statistik global."));

    // [BARU]: Ambil data complaints tanpa filter untuk menghitung metrik resolusi
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _complaintService.getSppgComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error List Keluhan: ${snapshot.error}"));
        }
        final allComplaints = snapshot.data ?? [];

        // Hitung Metrik Resolusi
        final resolvedCount = allComplaints
            .where((item) => item['admin_response'] != null)
            .length;
        final totalComplaints = allComplaints.length;
        final pendingCount = totalComplaints - resolvedCount;
        final resolutionPercentage = totalComplaints > 0
            ? (resolvedCount / totalComplaints)
            : 0.0;

        // Buat Pie Chart Resolusi
        final pieChartDataResolution = PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 50,
          sections: [
            PieChartSectionData(
              color: Colors.green,
              value: resolvedCount.toDouble(),
              title: '${resolvedCount}',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            PieChartSectionData(
              color: Colors.red,
              value: pendingCount.toDouble(),
              title: '${pendingCount}',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        );

        // Filter Options (Sekolah)
        final List<DropdownMenuItem<String?>> schoolItems = [
          const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
          ..._allVehicles.map(
            (vehicle) => DropdownMenuItem(
              value: vehicle.id,
              child: Text(vehicle.plateNumber),
            ),
          ),
        ];

        return Column(
          children: [
            // --- SECTION A: METRIK RESOLUSI & PERSENTASE ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Tingkat Resolusi Keluhan: ${(resolutionPercentage * 100).toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(
                    height: 250,
                    child: PieChart(pieChartDataResolution),
                  ),

                  // Stat Baris
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip("DITANGANI", resolvedCount, Colors.green),
                      _buildStatChip("PENDING", pendingCount, Colors.red),
                      _buildStatChip("TOTAL", totalComplaints, Colors.indigo),
                    ],
                  ),
                ],
              ),
            ),

            // --- FILTER SECTION ---
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  // Filter Tanggal
                  Expanded(
                    child: ListTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.red,
                      ),
                      title: Text(
                        DateFormat(
                          'd MMMM yyyy',
                          'id_ID',
                        ).format(_selectedRouteDate),
                      ),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedRouteDate,
                          firstDate: DateTime(2024),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedRouteDate = picked;
                            _complaintKey = UniqueKey(); // Force refresh list
                          });
                        }
                      },
                    ),
                  ),
                  // Filter Sekolah (Diganti dengan Dropdown Sekolah BUKAN Mobil)
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedSchoolFilterId,
                      decoration: const InputDecoration(
                        labelText: "Filter Sekolah",
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("Semua Sekolah"),
                        ),
                        ..._allSchools
                            .map(
                              (school) => DropdownMenuItem(
                                value: school.id,
                                child: Text(school.name),
                              ),
                            )
                            .toList(),
                      ],
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSchoolFilterId = newValue;
                          _complaintKey = UniqueKey(); // Force refresh list
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // --- SECTION B: LIST KELUHAN (Filtered) ---
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                key:
                    UniqueKey(), // Menggunakan UniqueKey untuk data yang filtered
                // Panggil service dengan filter yang baru
                future: _complaintService.getSppgComplaints(
                  date: _selectedRouteDate,
                  schoolId: _selectedSchoolFilterId,
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final filteredData = snapshot.data ?? [];

                  if (filteredData.isEmpty) {
                    return const Center(
                      child: Text("Tidak ada keluhan masuk sesuai filter."),
                    );
                  }
                  return ListView.builder(
                    itemCount: filteredData.length,
                    itemBuilder: (ctx, i) {
                      final item = filteredData[i];
                      final isResolved = item['admin_response'] != null;
                      final reporterRole = item['reporter_role'] ?? 'N/A';
                      final targetTable = reporterRole == 'walikelas'
                          ? 'class_receptions'
                          : 'delivery_stops';
                      final targetId = item['id'];

                      // Gunakan helper format details
                      final complaintDetails = _formatComplaintDetails(
                        reporterRole,
                        item['notes'],
                      );

                      return Card(
                        color: isResolved ? Colors.green[50] : Colors.red[100],
                        margin: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        child: ListTile(
                          onTap: isResolved
                              ? () =>
                                    _showHistoryDetailDialog(
                                      item,
                                    ) // Tampilkan detail history
                              : () => _showRespondDialog(
                                  item,
                                  targetTable,
                                  targetId,
                                ), // Respon jika pending

                          leading: Icon(
                            isResolved ? Icons.check_circle : Icons.warning,
                            color: isResolved ? Colors.green : Colors.red,
                          ),
                          title: Text(
                            item['school_name'] ?? 'Sekolah N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Dari: ${item['reporter_name']} (${reporterRole.toUpperCase()})",
                              ),
                              Text(
                                "Rincian: ${complaintDetails}",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isResolved
                                    ? "Ditangani Admin"
                                    : "PENDING TINDAK LANJUT",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isResolved
                                      ? Colors.green[800]
                                      : Colors.red[800],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: isResolved
                              ? const Icon(
                                  Icons.info_outline,
                                  color: Colors.grey,
                                )
                              : ElevatedButton(
                                  onPressed: () => _showRespondDialog(
                                    item,
                                    targetTable,
                                    targetId,
                                  ),
                                  child: const Text("Tindak Lanjut"),
                                ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
