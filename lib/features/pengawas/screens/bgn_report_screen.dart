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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Laporan Distribusi & Kualitas"), // UC03
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          isScrollable: true, // Biar muat di layar kecil
          tabs: const [
            Tab(text: "History & Bukti"),
            Tab(text: "Jadwal SPPG"),
            Tab(text: "Keluhan Masalah"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHistoryList(),
          _buildScheduleList(),
          _buildComplaintList(),
        ],
      ),
    );
  }

  // TAB 1: HISTORY & BUKTI & KETEPATAN
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
            final school = item['schools']['name'];
            final date = item['delivery_routes']['date'];
            final photoUrl = item['proof_photo_url'];

            // Logika Ketepatan Waktu (Sederhana: Kalau received_time < deadline dianggap Tepat)
            // Di sini kita labeli saja
            bool isOnTime = true; // Placeholder logika

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ExpansionTile(
                leading: const Icon(Icons.history, color: Colors.blue),
                title: Text("$sppg -> $school"),
                subtitle: Text(
                  "Tgl: $date | Status: ${isOnTime ? 'Tepat Waktu' : 'Terlambat'}",
                ),
                children: [
                  if (photoUrl != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Image.network(
                        photoUrl,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      "Penerima: ${item['recipient_name'] ?? '-'} \nCatatan: ${item['reception_notes'] ?? '-'}",
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
