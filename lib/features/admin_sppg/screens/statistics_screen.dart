// === FILE: lib/features/admin_sppg/screens/statistics_screen.dart ===
import 'package:fl_chart/fl_chart.dart'; // Import Library Grafik
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/stats_service.dart';
// BARU: Import service report yang baru kita buat
import '../services/stats_service.dart';
import '../services/report_service.dart';
import '../services/complaint_service.dart'; // <--- PASTIKAN INI ADA
import '../services/coordinator_service.dart';
import '../services/teacher_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with SingleTickerProviderStateMixin {
  // Tambahkan SingleTickerProviderStateMixin
  late TabController _tabController;
  final StatsService _statsService = StatsService();
  final AdminReportService _reportService = AdminReportService();
  final ComplaintService _complaintService =
      ComplaintService(); // UNTUK KOMPLAIN

  // [FIX] Definisikan Key dan Service yang hilang/digunakan di _buildComplaintsTab
  Key _complaintKey = UniqueKey(); // <--- FIX 2: DEFINISI KEY INI!

  Map<String, int>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 Tabs
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _statsService.getDeliveryStats();
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Fungsi Refresh untuk semua tab
  void _refreshAllTabs() {
    _loadStats();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // RENAME: Laporan Kinerja -> Laporan Distribusi & Kualitas
        title: const Text("Laporan Distribusi & Kualitas"),
        backgroundColor: Colors.indigo[800],
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
          labelColor: Colors.white, // <--- SET ACTIVE LABEL TO WHITE
          unselectedLabelColor:
              Colors.white70, // <--- SET INACTIVE LABEL TO WHITE70
          isScrollable: true,
          tabs: const [
            Tab(text: "1. Pengiriman"), // Global Stats (Old Pie Chart)
            Tab(text: "2. Rute & Detail"), // All Routes (Ongoing & History)
            Tab(text: "3. Anggota"), // All Users (Kurir, Koord, Wali)
            Tab(text: "4. Keluhan"), // Complaints
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

  // TAB 1: Kinerja Global (Existing Pie Chart)
  Widget _buildGlobalStatsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null)
      return const Center(child: Text("Gagal memuat data statistik."));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          const Text(
            "Status Pengiriman Keseluruhan",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          // --- GRAFIK LINGKARAN (PIE CHART) ---
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  // Bagian Hijau (Sukses Diterima)
                  PieChartSectionData(
                    color: Colors.green,
                    value: _stats!['received']!.toDouble(),
                    title: '${_stats!['received']}',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // Bagian Merah (Masalah)
                  PieChartSectionData(
                    color: Colors.red,
                    value: _stats!['issues']!.toDouble(),
                    title: '${_stats!['issues']}',
                    radius: 60,
                    titleStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  // Bagian Abu (Dalam Proses / Pending/Completed Courier)
                  PieChartSectionData(
                    color: Colors.grey,
                    value: _stats!['pending']!.toDouble(),
                    title: '${_stats!['pending']}',
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          // --- KETERANGAN (LEGEND) ---
          _buildLegend(
            Colors.green,
            "Sukses Diterima Koord",
            _stats!['received']!,
          ),
          _buildLegend(Colors.red, "Ada Masalah/Komplain", _stats!['issues']!),
          _buildLegend(
            Colors.grey,
            "Dalam Proses / Kurir Tiba",
            _stats!['pending']!,
          ),
          const Divider(height: 40),
          Card(
            color: Colors.indigo[50],
            child: ListTile(
              leading: const Icon(Icons.analytics, color: Colors.indigo),
              title: const Text("Total Aktivitas Pengiriman"),
              trailing: Text(
                "${_stats!['total']}",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text(
            "$value",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.green;
      case 'issue_reported':
        return Colors.red;
      case 'completed':
        return Colors.orange; // Courier completed his delivery job at the stop
      case 'active':
        return Colors.blue;
      default:
        return Colors.grey; // Pending/Unknown
    }
  }

  // TAB 2: RUTE & DETAIL (Ongoing & History)
  Widget _buildRoutesDetailTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportService.getDetailedRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final routes = snapshot.data ?? [];
        if (routes.isEmpty)
          return const Center(child: Text("Belum ada data rute."));

        return ListView.builder(
          itemCount: routes.length,
          itemBuilder: (ctx, i) {
            final route = routes[i];
            final routeStops = route['delivery_stops'] as List<dynamic>? ?? [];
            final courierName =
                route['profiles!courier_id']?['full_name'] ??
                'Kurir N/A'; //also make sure the courier name is properly displayed
            final status = route['status'];
            final isOngoing = status == 'active' || status == 'pending';
            final formattedDate = DateFormat(
              'dd MMM yy',
            ).format(DateTime.parse(route['date']));

            return Card(
              color: isOngoing ? Colors.blue[50] : Colors.grey[100],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: ExpansionTile(
                leading: Icon(
                  isOngoing ? Icons.directions_run : Icons.local_shipping,
                  color: isOngoing ? Colors.blue : Colors.grey,
                ),
                title: Text(
                  "[${isOngoing ? 'ONGOING' : 'HISTORY'}] $formattedDate - ${route['vehicles']['plate_number']}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Kurir: $courierName | Status: ${status.toUpperCase()}",
                ),
                children: routeStops.map<Widget>((stop) {
                  final school = stop['schools'];
                  final stopStatus = stop['status'];
                  final eta =
                      stop['estimated_arrival_time']?.substring(0, 5) ??
                      '--:--';
                  final finalStatus = stopStatus == 'received'
                      ? 'Diterima'
                      : (stopStatus == 'issue_reported'
                            ? 'KOMPLAIN'
                            : (stopStatus == 'completed'
                                  ? 'Kurir Tiba'
                                  : 'Pending'));

                  return ListTile(
                    contentPadding: const EdgeInsets.only(
                      left: 30,
                      right: 16,
                      top: 4,
                      bottom: 4,
                    ),
                    leading: Icon(
                      stopStatus == 'received'
                          ? Icons.check_circle
                          : (stopStatus == 'issue_reported'
                                ? Icons.error
                                : Icons.remove_red_eye),
                      color: _getStatusColor(stopStatus),
                    ),
                    title: Text(
                      school['name'],
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text("Est. Tiba: $eta | Status: $finalStatus"),
                    trailing: Text("Porsi: ${school['student_count']}"),
                  );
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  // TAB 3: PERSONEL (Kurir, Koord, Wali Kelas)
  Widget _buildPersonnelTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportService.getPersonnelSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final personnel = snapshot.data ?? [];
        if (personnel.isEmpty)
          return const Center(child: Text("Tidak ada data personel SPPG."));

        final grouped = Map.fromIterable(
          personnel.map((p) => p['role']).toSet(),
          key: (role) => role,
          value: (role) => personnel.where((p) => p['role'] == role).toList(),
        );

        return ListView(
          children: [
            ...grouped.entries.map((entry) {
              final role = entry.key;
              final list = entry.value;
              return ExpansionTile(
                title: Text(
                  "${role.toUpperCase()} (${list.length})",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[900],
                  ),
                ),
                children: list
                    .map(
                      (p) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(p['full_name'] ?? 'N/A'),
                        subtitle: Text(
                          "${p['email']}\nSekolah: ${p['schools']?['name'] ?? '-'}",
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          p['role'] == 'kurir'
                              ? 'KURIR'
                              : (p['role'] == 'koordinator' ? 'KOORD' : 'WALI'),
                        ),
                      ),
                    )
                    .toList(),
              );
            }),
          ],
        );
      },
    );
  }

  // TAB 4: KELUHAN MASUK (Remake total, menampilkan Global Pie Chart + List Keluhan)
  Widget _buildComplaintsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_stats == null)
      return const Center(child: Text("Gagal memuat data statistik global."));

    // 1. Ambil data Pie Chart Global (dari _stats - Tab 1)
    final pieChartDataGlobal = PieChartData(
      sectionsSpace: 2,
      centerSpaceRadius: 50,
      sections: [
        // Bagian Hijau (Sukses Diterima)
        PieChartSectionData(
          color: Colors.green,
          value: _stats!['received']!.toDouble(),
          title: '${_stats!['received']}',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        // Bagian Merah (Masalah)
        PieChartSectionData(
          color: Colors.red,
          value: _stats!['issues']!.toDouble(),
          title: '${_stats!['issues']}',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        // Bagian Abu (Dalam Proses / Pending/Completed Courier)
        PieChartSectionData(
          color: Colors.grey,
          value: _stats!['pending']!.toDouble(),
          title: '${_stats!['pending']}',
          radius: 50,
          titleStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );

    return Column(
      children: [
        // --- SECTION A: GLOBAL PIE CHART ---
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Daftar Keluhan",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(height: 220, child: PieChart(pieChartDataGlobal)),

        const Padding(
          padding: EdgeInsets.only(top: 10, bottom: 10),
          child: Text(
            "Daftar Keluhan Masuk Koordinator & Wali Kelas",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ),
        const Divider(),

        // --- SECTION B: LIST KELUHAN (DARI COMPLAINT SERVICE) ---
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: _complaintKey, // Memaksa refresh list keluhan
            future: _complaintService.getSppgComplaints(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text("Error List Keluhan: ${snapshot.error}"),
                );
              }

              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Center(child: Text("Tidak ada keluhan masuk."));
              }

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (ctx, i) {
                  final item = data[i];
                  final isResolved = item['admin_response'] != null;
                  final reporterRole = item['reporter_role'] ?? 'N/A';

                  // Logic untuk Tindak Lanjut
                  final targetTable = reporterRole == 'walikelas'
                      ? 'class_receptions'
                      : 'delivery_stops';
                  final targetId = item['id'];

                  return Card(
                    color: isResolved ? Colors.green[50] : Colors.red[100],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
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
                          Text("Keluhan: ${item['notes']}"),
                          Text(
                            isResolved
                                ? "Respon: ${item['admin_response']}"
                                : "Status: BELUM DITINDAK LANJUT",
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
                      trailing: isResolved
                          ? const Icon(Icons.reply, color: Colors.grey)
                          : ElevatedButton(
                              // Panggil dialog respons
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
  }

  // Tambahkan _showRespondDialog (dari CenterInfoScreen, tapi diganti nama)

  void _showRespondDialog(
    Map<String, dynamic> complaint,
    String targetTable,
    String targetTableId,
  ) {
    final responseController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tindak Lanjut Keluhan"),
        content: TextField(
          controller: responseController,
          decoration: InputDecoration(
            labelText:
                "Instruksi / Tindak Lanjut Admin SPPG (Untuk ${complaint['reporter_role'].toUpperCase()})",
            border: const OutlineInputBorder(),
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

              // Cek ID Penerima Notifikasi (ID user profiles/auth)
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
                id: complaint['id'], // ID unik complaint
                response: responseController.text,
                reporterId:
                    finalReporterUserId, // ID user yang akan dapat notif
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
}
