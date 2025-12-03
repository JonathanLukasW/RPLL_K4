import 'package:flutter/material.dart';
import '../services/bgn_monitoring_service.dart';

class BgnReportScreen extends StatefulWidget {
  const BgnReportScreen({super.key});

  @override
  State<BgnReportScreen> createState() => _BgnReportScreenState();
}

class _BgnReportScreenState extends State<BgnReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BgnMonitoringService _service = BgnMonitoringService();

  // [BARU] Fungsi Refresh yang akan memuat ulang semua FutureBuilder
  Future<void> _refreshAllTabs() async {
    // Memaksa rebuild FutureBuilder dengan memanggil setState di BgnReportScreen
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Distribusi & Kualitas"), // RENAMED!
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // [BARU] TOMBOL REFRESH
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
            // RENAME & FOCUS
            Tab(text: "1. History & Kualitas"),
            // RENAME & FOCUS
            Tab(text: "2. Jadwal & Rute Aktif"),
            // CONSOLIDATE
            Tab(text: "3. Keluhan Masalah"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList(),
          _buildActiveSchedulesList(), // RENAME!
          _buildComplaintList(),
        ],
      ),
    );
  }

  // TAB 1: HISTORY & KUALITAS (Updated to be more detailed)
  Widget _buildHistoryList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getDeliveryHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(child: Text("Belum ada riwayat pengiriman."));

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final sppg = item['delivery_routes']['sppgs']['name'];
            final school = item['schools'];
            final date = item['delivery_routes']['date'];
            final finalStatus = item['status'];
            final isIssue = finalStatus == 'issue_reported';

            return Card(
              color: isIssue ? Colors.red[50] : Colors.green[50],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ExpansionTile(
                leading: Icon(
                  isIssue ? Icons.warning : Icons.check_circle,
                  color: isIssue ? Colors.red : Colors.green,
                ),
                title: Text("$sppg -> ${school['name']}"),
                subtitle: Text(
                  "Tgl: $date | Status: ${finalStatus.toUpperCase()}",
                ),
                children: [
                  // Detail Pengiriman
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Penerima: ${item['recipient_name'] ?? '-'}"),
                        Text(
                          "Porsi Diterima: ${item['received_qty'] ?? '-'} / ${school['student_count']}",
                        ),
                        Text(
                          "Deadline (Toleransi): ${school['deadline_time']} (${school['tolerance_minutes']}m)",
                        ),
                        Text(
                          "Kurir Tiba: ${item['arrival_time']?.substring(11, 16) ?? '-'}",
                        ),
                        Text(
                          "Catatan Penerima: ${item['reception_notes'] ?? '-'}",
                        ),

                        if (item['proof_photo_url'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Image.network(
                              item['proof_photo_url'],
                              height: 150,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: JADWAL & RUTE AKTIF (Renamed from _buildScheduleList)
  Widget _buildActiveSchedulesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getAllSchedules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(
            child: Text("Tidak ada rute ongoing atau jadwal mendatang."),
          );

        // Separate active/pending routes from general schedule list for clarity
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final status = item['status'];
            final isOngoing = status == 'active' || status == 'pending';

            return ListTile(
              leading: Icon(
                isOngoing ? Icons.access_time : Icons.calendar_today,
                color: isOngoing ? Colors.blue[800] : Colors.orange,
              ),
              title: Text(item['sppgs']['name']),
              subtitle: Text(
                "Jadwal: ${item['date']} | Status: ${status.toUpperCase()} | Mobil: ${item['vehicles'] != null ? item['vehicles']['plate_number'] : '-'}",
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: JADWAL PENGIRIMAN SETIAP SPPG
  Widget _buildScheduleList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getAllSchedules(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(child: Text("Belum ada jadwal mendatang."));

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            return ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.orange),
              title: Text(item['sppgs']['name']),
              subtitle: Text(
                "Jadwal: ${item['date']} | Mobil: ${item['vehicles'] != null ? item['vehicles']['plate_number'] : '-'}",
              ),
            );
          },
        );
      },
    );
  }

  // TAB 3: LAPORAN KELUHAN SEMUA SPPG
  Widget _buildComplaintList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getAllComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(child: Text("Aman! Tidak ada keluhan."));
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final sppg = item['delivery_routes']['sppgs']['name'];
            final school = item['schools']['name'];
            return Card(
              color: Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.warning, color: Colors.red),
                title: Text("$sppg -> $school"),
                subtitle: Text("Keluhan: ${item['reception_notes']}"),
                trailing: item['admin_response'] != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Text(
                        "Belum Ditangani",
                        style: TextStyle(color: Colors.red, fontSize: 10),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}
