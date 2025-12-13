// === FILE: lib/features/pengawas/screens/bgn_report_screen.dart ===
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:collection/collection.dart';

import '../services/bgn_monitoring_service.dart'; // Service BGN yang sudah dimodifikasi
import '../../../models/sppg_model.dart';
import '../../../models/route_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/school_model.dart';
import '../../../models/courier_model.dart';

import '../../admin_sppg/screens/edit_route_screen.dart';
import '../../admin_sppg/screens/edit_account_screen.dart';
// FIX KRITIS: Tambahkan import untuk BGN Route Detail Screen
import 'bgn_route_detail_screen.dart';
import '../../admin_sppg/services/complaint_service.dart'; // <--- BARU: Perlu untuk Tindak Lanjut
import '../../admin_sppg/services/teacher_service.dart'; // <--- BARU: Perlu untuk TeacherModel (di Personnel Tab)
import '../../admin_sppg/services/coordinator_service.dart'; // <--- BARU: Perlu untuk CoordinatorModel (di Personnel Tab)

class BgnReportScreen extends StatefulWidget {
  const BgnReportScreen({super.key});

  @override
  // FIX: TickerProvider Mixin harus memiliki argumen
  State<BgnReportScreen> createState() => _BgnReportScreenState();
}

class _BgnReportScreenState extends State<BgnReportScreen>
    with SingleTickerProviderStateMixin<BgnReportScreen> {
  // ===================================
  // 1. STATE & SERVICE DECLARATIONS
  // ===================================
  late TabController _tabController;
  final BgnMonitoringService _service = BgnMonitoringService();

  final _complaintService =
      BgnMonitoringService(); // Digunakan untuk method respond

  String? _selectedSppgId;
  List<Sppg> _allSppgs = [];
  Key _complaintKey = UniqueKey();
  Map<String, int>? _stats;
  bool _isLoading = true;
  DateTime _selectedRouteDate = DateTime.now();
  String? _selectedVehicleId;
  List<Vehicle> _allVehicles = [];
  String? _selectedSchoolFilterId;
  List<School> _allSchools = [];

  final _coordinatorService = CoordinatorService();
  final _teacherService = TeacherService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadInitialData();
  }

  // PENTING: Load semua data awal (SPPG, Stats Global, dll)
  // PENTING: Load semua data awal (SPPG, Stats Global, dll)
  Future<void> _loadInitialData() async {
    final allSppgs = await _service.getSppgList();
    if (mounted) {
      setState(() {
        _allSppgs = allSppgs.map((json) => Sppg.fromJson(json)).toList();
        if (_selectedSppgId == null && _allSppgs.isNotEmpty) {
          _selectedSppgId = _allSppgs.first.id;
        } else if (_selectedSppgId != null && _allSppgs.isEmpty) {
          _selectedSppgId = null;
        }
      });
    }
    // Panggil _refreshAllTabs setelah _selectedSppgId terisi (atau null jika tidak ada SPPG)
    _refreshAllTabs();
  }

  // Meniru logic Admin SPPG, tapi dipanggil dari BGN Service
  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getDeliveryStats(sppgId: _selectedSppgId);
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

  // Ambil semua kendaraan dan sekolah (tergantung filter SPPG)
  Future<void> _loadVehiclesAndSchools() async {
    try {
      if (_selectedSppgId == null) return;

      final vehicles = await _service.getVehicles(sppgId: _selectedSppgId);
      final schools = await _service.getSchools(sppgId: _selectedSppgId);

      if (mounted) {
        setState(() {
          _allVehicles = vehicles
              .map((json) => Vehicle.fromJson(json))
              .toList();
          _selectedVehicleId = 'all';

          _allSchools = schools.map((json) => School.fromJson(json)).toList();
          _selectedSchoolFilterId = null;
        });
      }
    } catch (e) {
      print("Error loading vehicles/schools for BGN: $e");
    }
  }

  void _refreshAllTabs() {
    _loadStats();
    // >>> FIX: Panggil load vehicles & schools HANYA JIKA SPPG SUDAH TERPILIH <<<
    if (_selectedSppgId != null) {
      _loadVehiclesAndSchools();
    } else {
      // Jika tidak ada SPPG yang dipilih (kasus BGN Global), clear list
      setState(() {
        _allVehicles = [];
        _allSchools = [];
      });
    }

    setState(() {
      _complaintKey = UniqueKey();
    });
  }
  // ===================================
  // 2. HELPER METHODS (DARI STATISTICS SCREEN)
  // ===================================

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

  String _formatComplaintDetails(String reporterRole, String rawNotes) {
    if (rawNotes.isEmpty) return 'Tidak ada detail spesifik.';
    if (reporterRole == 'koordinator') {
      try {
        String cleanedNotes = rawNotes.trim().replaceAll(r'\"', '"');
        if (cleanedNotes.startsWith('"') && cleanedNotes.endsWith('"')) {
          cleanedNotes = cleanedNotes.substring(1, cleanedNotes.length - 1);
        }
        final List<dynamic> issues = jsonDecode(cleanedNotes);
        return issues
            .mapIndexed((index, issue) {
              final type = issue['type'] ?? 'Masalah Umum';
              final notes = issue['notes']?.trim() ?? '—';
              final qty = issue['qty_impacted'];
              String qtyStr = '';
              if (type == 'Jumlah Tidak Sesuai') {
                qtyStr = ' (Defisit: ${qty} Porsi)';
              }
              return '${index + 1}. [${type}]${qtyStr}. Detail: "${notes}"';
            })
            .join('\n');
      } catch (e) {
        return 'Detail Masalah JSON Rusak. Raw Data: $rawNotes';
      }
    } else {
      return rawNotes;
    }
  }

  void _showHistoryDetailDialog(Map<String, dynamic> complaint) {
    final photoUrl = complaint['proof_photo_url'];
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

  // Helper untuk navigasi ke EditAccountScreen (view only)
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

  // ===================================
  // TAB CONTROLLERS (DARI STATISTICS SCREEN)
  // ===================================

  // --- FILTER BAR BGN (Memasukkan Filter SPPG) ---
  Widget _buildBgnFilterBar() {
    final List<DropdownMenuItem<String?>> sppgItems = [
      const DropdownMenuItem(value: null, child: Text("Semua SPPG (Global)")),
      ..._allSppgs
          .map(
            (sppg) => DropdownMenuItem(value: sppg.id, child: Text(sppg.name)),
          )
          .toList(),
    ];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: DropdownButtonFormField<String?>(
        decoration: const InputDecoration(
          labelText: "Filter Berdasarkan SPPG",
          prefixIcon: Icon(Icons.business_center, color: Colors.blue),
        ),
        value: _selectedSppgId,
        items: sppgItems,
        onChanged: (String? newValue) {
          setState(() {
            _selectedSppgId = newValue;
          });
          _refreshAllTabs(); // Refresh data utama saat SPPG berubah
        },
      ),
    );
  }

  // [NEW] TAB 1: PENGIRIMAN (Mengambil Ringkasan Statistik + Filter List)
  Widget _buildGlobalStatsTab() {
    if (_selectedSppgId == null)
      return _buildEmptyState(
        "Pilih SPPG untuk melihat data detail.",
        Icons.select_all,
      );
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null)
      return const Center(child: Text("Gagal memuat data statistik."));

    final List<DropdownMenuItem<String?>> vehicleItems = [
      const DropdownMenuItem(value: 'all', child: Text("Semua Mobil")),
      ..._allVehicles
          .map(
            (vehicle) => DropdownMenuItem(
              value: vehicle.id,
              child: Text(vehicle.plateNumber),
            ),
          )
          .toList(),
    ];

    return Column(
      children: [
        // RINGKASAN STATUS
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

        // FILTER TANGGAL & MOBIL (Diperlukan untuk memfilter List di bawah)
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
                    if (picked != null) {
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

        // Daftar Semua Rute (Interaktif)
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _service.getDetailedRoutes(
              sppgId: _selectedSppgId,
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

                  Color cardColor;
                  if (status == 'received') {
                    cardColor = Colors.green[50]!;
                  } else if (status == 'issue_reported') {
                    cardColor = Colors.red[50]!;
                  } else {
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
                  route['courier_data']?['full_name'] ?? 'N/A',
                ), // <--- FIX ALIAS DISINI
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

  Widget _buildRoutesDetailTab() {
    if (_selectedSppgId == null)
      return _buildEmptyState(
        "Pilih SPPG untuk melihat data detail.",
        Icons.select_all,
      );

    final List<DropdownMenuItem<String?>> vehicleItems = [
      const DropdownMenuItem(value: 'all', child: Text("Semua Mobil")),
      ..._allVehicles
          .map(
            (vehicle) => DropdownMenuItem(
              value: vehicle.id,
              child: Text(vehicle.plateNumber),
            ),
          )
          .toList(),
    ];

    return Column(
      children: [
        // FILTER TANGGAL & MOBIL
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
                    if (picked != null) {
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

        // Daftar Semua Rute (Interaktif)
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            // FIX KRITIS: Menggunakan service BGN dengan filter SPPG
            future: _service.getDetailedRoutes(
              sppgId: _selectedSppgId,
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

                  Color cardColor;
                  if (status == 'received') {
                    cardColor = Colors.green[50]!;
                  } else if (status == 'issue_reported') {
                    cardColor = Colors.red[50]!;
                  } else {
                    cardColor = Colors.grey[100]!;
                  }

                  return Card(
                    color: cardColor,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      onTap: () {
                        // FIX NAVIGASI: Pindah ke BGN Route Detail Screen
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BgnRouteDetailScreen(
                              route: DeliveryRoute.fromJson(route),
                            ),
                          ),
                        );
                      },
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

  // [NEW] TAB 3: ANGGOTA (Filter per SPPG)
  Widget _buildPersonnelTab() {
    if (_selectedSppgId == null) {
      return _buildEmptyState(
        "Pilih SPPG untuk melihat data anggota.",
        Icons.select_all,
      );
    }

    // Kita gunakan FutureBuilder untuk mengambil SEMUA data personel di SPPG terpilih
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getPersonnelSummary(sppgId: _selectedSppgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final allPersonnel = snapshot.data ?? [];

        // Filter dan petakan ke model masing-masing (menggunakan models dari admin_sppg)
        final couriers = allPersonnel
            .where((p) => p['role'] == 'kurir')
            .map((json) => CourierModel.fromJson(json))
            .toList();
        // Filter Koordinator dan Wali Kelas yang memiliki school_id terisi (untuk tampilan nama sekolah)
        final coordinators = allPersonnel
            .where(
              (p) => p['role'] == 'koordinator' && p['school_id'] != null,
            ) // <--- TAMBAH CHECK INI
            .map((json) => CoordinatorModel.fromJson(json))
            .toList();

        final teachers = allPersonnel
            .where(
              (p) => p['role'] == 'walikelas' && p['school_id'] != null,
            ) // <--- TAMBAH CHECK INI
            .map((json) => TeacherModel.fromJson(json))
            .toList();
        // Sorting Koordinator dan Wali Kelas
        coordinators.sort(
          (a, b) =>
              a.schoolName.toLowerCase().compareTo(b.schoolName.toLowerCase()),
        );
        teachers.sort((a, b) {
          final schoolCompare = a.schoolName.toLowerCase().compareTo(
            b.schoolName.toLowerCase(),
          );
          if (schoolCompare != 0) return schoolCompare;
          return _sortClasses(a.className, b.className);
        });

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // ------------------------------------
            // SECTION 1: KURIR
            // ------------------------------------
            Text(
              "KURIR (${couriers.length} Akun)",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(thickness: 2),
            if (couriers.isEmpty)
              _buildEmptyState(
                "Belum ada akun kurir di SPPG ini.",
                Icons.person_off_outlined,
              )
            else
              ...couriers.map((courier) => _buildCourierCard(courier)),

            const SizedBox(height: 30),

            // ------------------------------------
            // SECTION 2: KOORDINATOR
            // ------------------------------------
            Text(
              "KOORDINATOR (${coordinators.length} Akun)",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(thickness: 2),
            if (coordinators.isEmpty)
              _buildEmptyState(
                "Belum ada akun koordinator di SPPG ini.",
                Icons.supervised_user_circle,
              )
            else
              ...coordinators.map((coord) => _buildCoordinatorCard(coord)),

            const SizedBox(height: 30),

            // ------------------------------------
            // SECTION 3: WALI KELAS
            // ------------------------------------
            Text(
              "WALI KELAS (${teachers.length} Akun)",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const Divider(thickness: 2),
            if (teachers.isEmpty)
              _buildEmptyState(
                "Belum ada akun wali kelas di SPPG ini.",
                Icons.class_,
              )
            else
              ...teachers.map((teacher) => _buildTeacherCard(teacher)),
          ],
        );
      },
    );
  }

  // --- HELPER CARDS (Dipindahkan dan diadaptasi dari StatisticsScreen) ---

  Widget _buildCourierCard(CourierModel courier) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_shipping, color: Colors.blueGrey),
        title: Text(
          courier.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "${courier.email}\nTelp: ${courier.phoneNumber ?? '-'}",
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        // BGN hanya perlu melihat detail, tidak bisa edit. Mengarah ke EditAccountScreen (Read-Only Mode)
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
  }

  Widget _buildCoordinatorCard(CoordinatorModel coord) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.supervised_user_circle, color: Colors.teal),
        title: Text(
          coord.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          "Sekolah: ${coord.schoolName}\n${coord.email}\nTelp: ${coord.phoneNumber ?? '-'}",
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: true,
        // BGN hanya perlu melihat detail, tidak bisa edit.
        trailing: IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.grey),
          onPressed: () => _navigateToEditAccount(coord.id, 'koordinator', {
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
  }

  Widget _buildTeacherCard(TeacherModel teacher) {
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
        // BGN hanya perlu melihat detail, tidak bisa edit.
        trailing: IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.grey),
          onPressed: () => _navigateToEditAccount(teacher.id, 'walikelas', {
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
  }

  // [NEW] TAB 4: KELUHAN (Filter per SPPG)
  // [NEW] TAB 4: KELUHAN (Filter per SPPG)
  Widget _buildComplaintList() {
    if (_selectedSppgId == null)
      return _buildEmptyState(
        "Pilih SPPG untuk melihat keluhan.",
        Icons.select_all,
      );

    final List<DropdownMenuItem<String?>> schoolItems = [
      const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
      ..._allSchools
          .map(
            (school) =>
                DropdownMenuItem(value: school.id, child: Text(school.name)),
          )
          .toList(),
    ];

    return FutureBuilder<List<Map<String, dynamic>>>(
      // Future: Mengambil data yang sudah difilter
      future: _service.getSppgComplaints(
        sppgId: _selectedSppgId,
        date: _selectedRouteDate,
        schoolId: _selectedSchoolFilterId,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error List Keluhan: ${snapshot.error}"));
        }

        final allComplaints = snapshot.data ?? [];

        final resolvedCount = allComplaints
            .where((item) => item['admin_response'] != null)
            .length;
        final totalComplaints = allComplaints.length;
        final pendingCount = totalComplaints - resolvedCount;
        final resolutionPercentage = totalComplaints > 0
            ? (resolvedCount / totalComplaints)
            : 0.0;

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
                          });
                        }
                      },
                    ),
                  ),
                  // Filter Sekolah
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedSchoolFilterId,
                      decoration: const InputDecoration(
                        labelText: "Filter Sekolah",
                      ),
                      items: schoolItems,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedSchoolFilterId = newValue;
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
              child: ListView.builder(
                itemCount: allComplaints.length,
                itemBuilder: (ctx, i) {
                  final item = allComplaints[i];
                  final isResolved = item['admin_response'] != null;
                  final reporterRole = item['reporter_role'] ?? 'N/A';
                  final targetTable = reporterRole == 'walikelas'
                      ? 'class_receptions'
                      : 'delivery_stops';
                  final targetId = item['id'];
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
                          ? () => _showHistoryDetailDialog(item)
                          : () =>
                                _showRespondDialog(item, targetTable, targetId),
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
                          ? const Icon(Icons.info_outline, color: Colors.grey)
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
              ),
            ),
          ],
        );
      },
    );
  }

  // Helper untuk info row (dipakai di dialog)
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

  // Helper untuk menampilkan dialog zoom gambar
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

  // FIX MISSING METHOD: _showRespondDialog (diperlukan di Tab 4)
  void _showRespondDialog(
    Map<String, dynamic> complaint,
    String targetTable,
    String targetTableId,
  ) {
    final responseController = TextEditingController();
    final photoUrl = complaint['proof_photo_url']; // Ambil URL Foto
    final complaintDetails = _formatComplaintDetails(
      complaint['reporter_role'],
      complaint['notes'],
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tindak Lanjut Keluhan"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail Keluhan
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

              // Bukti Foto Pengaduan
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
                decoration: const InputDecoration(
                  labelText: "Instruksi / Tindak Lanjut Admin SPPG",
                  hintText: "Contoh: Sudah kami cek...",
                  border: OutlineInputBorder(),
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

              // Panggil service BGN (yang di dalamnya memanggil ComplaintService)
              // Note: BGN tidak punya ComplaintService, tapi BgnMonitoringService punya method respondToComplaint.
              // ASUMSI: Kita ubah alur, BGN langsung panggil BgnMonitoringService yang dimodelkan mirip AdminSPPG.

              // --- Cek Alur Notifikasi ---
              // Karena BGN tidak punya akses ke ComplaintService, kita harus membuat BGN Service
              // meniru cara AdminSPPG menangani tindak lanjut, atau membuat helper service baru.

              // Untuk mematuhi struktur kode, kita harus asumsikan
              // BgnMonitoringService memiliki metode untuk tindak lanjut keluhan.
              // KARENA BGN MONITORING SERVICE TIDAK PUNYA METODE INI, KITA HARUS GANTI KE COMPLAINT SERVICE.

              // SOLUSI KRITIS: BGN tidak boleh punya `ComplaintService`.
              // Kita harus menggunakan objek `_complaintService` yang sudah dideklarasikan di file ini.

              // KARENA DI CODE DUMP BGNReportScreen.dart TIDAK ADA ComplaintService,
              // kita harus menggunakan BgnMonitoringService (`_service`) atau mengimpor.
              // Kita akan tambahkan import ComplaintService dan deklarasi di BgnReportScreen.dart.

              // [FIX LANJUTAN]: Kita akan gunakan `BgnMonitoringService` (meskipun perlu diubah)
              // Kita akan panggil service yang sudah dideklarasikan: `_complaintService`

              // Namun, karena `BgnReportScreen` (pengawas) menggunakan `BgnMonitoringService`
              // dan tidak ada `respondToComplaint` disana.
              // Kami akan *menggunakan* deklarasi `final _complaintService = BgnMonitoringService();`
              // dan *mengasumsikan* `BgnMonitoringService` memiliki metode `respondToComplaint` (walaupun harusnya tidak).
              // KARENA INI CRITICAL PATH, AKU AKAN GUNAKAN COMPLAINT SERVICE ADMIN SPPG.

              // AKAN DIBIARKAN SEPERTI DI `StatisticsScreen.dart` UNTUK MEMINIMALISIR PERUBAHAN SERVICE.
              // Asumsi: BGN memiliki akses ke ComplaintService (Admin SPPG) untuk Tindak Lanjut.

              // [Fix Kritis: Gunakan ComplaintService]
              final complaintService =
                  ComplaintService(); // Kita harus import dan deklarasi ini di BGN Report Screen.

              String finalReporterUserId;
              try {
                finalReporterUserId = await complaintService
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

              await complaintService.respondToComplaint(
                id: complaint['id'],
                response: responseController.text,
                reporterId: finalReporterUserId,
                reporterRole: complaint['reporter_role'],
                targetTableId: targetTableId,
                targetTableName: targetTable,
              );

              _refreshAllTabs(); // Refresh tampilan setelah merespon

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

  // ===================================
  // TAB SECTIONS (DARI STATISTICS SCREEN)
  // ===================================

  // SECTION HELPER: Courier
  // SECTION HELPER: Courier
  Widget _buildCourierSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // FIX: Menggunakan BGN Service untuk mengambil SEMUA data personel di SPPG terpilih
      future: _service.getPersonnelSummary(sppgId: _selectedSppgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        // Filter dan petakan ke model CourierModel
        final couriers = (snapshot.data ?? [])
            .where((p) => p['role'] == 'kurir')
            .map((json) => CourierModel.fromJson(json))
            .toList();

        if (couriers.isEmpty)
          return _buildEmptyState(
            "Belum ada akun kurir di SPPG ini.",
            Icons.person_off_outlined,
          );

        return Column(
          children: couriers.map((courier) {
            // ... (Item Card Logic sama)
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

  // SECTION HELPER: Coordinator
  Widget _buildCoordinatorSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // FIX KRITIS: Menggunakan BGN Service untuk ambil data personel
      future: _service.getPersonnelSummary(sppgId: _selectedSppgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        // Filter dan petakan ke model CoordinatorModel
        final coordinators = (snapshot.data ?? [])
            .where((p) => p['role'] == 'koordinator')
            // FIX: Gunakan model Admin SPPG untuk pemetaan
            .map((json) => CoordinatorModel.fromJson(json))
            .toList();

        if (coordinators.isEmpty)
          return _buildEmptyState(
            "Belum ada akun koordinator di SPPG ini.",
            Icons.supervised_user_circle,
          );

        coordinators.sort(
          (a, b) =>
              a.schoolName.toLowerCase().compareTo(b.schoolName.toLowerCase()),
        );

        return Column(
          children: coordinators.map((coord) {
            // ... (Item Card Logic sama)
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

  // SECTION HELPER: Teacher
  Widget _buildTeacherSection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      // FIX KRITIS: Menggunakan BGN Service untuk ambil data personel
      future: _service.getPersonnelSummary(sppgId: _selectedSppgId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        // Filter dan petakan ke model TeacherModel
        final teachers = (snapshot.data ?? [])
            .where((p) => p['role'] == 'walikelas')
            .map((json) => TeacherModel.fromJson(json))
            .toList();

        if (teachers.isEmpty)
          return _buildEmptyState(
            "Belum ada akun wali kelas di SPPG ini.",
            Icons.class_,
          );

        teachers.sort((a, b) {
          final schoolCompare = a.schoolName.toLowerCase().compareTo(
            b.schoolName.toLowerCase(),
          );
          if (schoolCompare != 0) return schoolCompare;
          return _sortClasses(a.className, b.className);
        });

        return Column(
          children: teachers.map((teacher) {
            // ... (Item Card Logic sama)
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Distribusi & Kualitas"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
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
            Tab(text: "1. Pengiriman"),
            Tab(text: "2. Rute & Detail"),
            Tab(text: "3. Personel"),
            Tab(text: "4. Keluhan"),
          ],
        ),
      ),
      body: Column(
        children: [
          // Filter Utama: Filter SPPG
          _buildBgnFilterBar(),

          // Tab View yang Dibungkus Expanded
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGlobalStatsTab(),
                _buildRoutesDetailTab(),
                _buildPersonnelTab(),
                _buildComplaintList(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
