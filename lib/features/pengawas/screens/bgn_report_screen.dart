import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/bgn_monitoring_service.dart';

class BgnReportScreen extends StatefulWidget {
  const BgnReportScreen({super.key});

  @override
  State<BgnReportScreen> createState() => _BgnReportScreenState();
}

class _BgnReportScreenState extends State<BgnReportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BgnMonitoringService _service = BgnMonitoringService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // [UBAH] Judul lebih relevan
        title: const Text("Laporan & Pengaduan"),
        backgroundColor: Colors.blue[800], // Ganti jadi Biru (Warna BGN) atau tetap Merah kalau mau highlight isu
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Logistik & Kemasan"),
            Tab(text: "Kualitas Makanan"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLogisticsIssues(),
          _buildFoodQualityIssues(),
        ],
      ),
    );
  }

  // TAB 1: MASALAH LOGISTIK (DARI KOORDINATOR)
  Widget _buildLogisticsIssues() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getGlobalCoordinatorComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada laporan logistik.");

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final sppgName = item['delivery_routes']['sppgs']['name'];
            final schoolName = item['schools']['name'];
            final date = item['delivery_routes']['date'];
            final notes = item['reception_notes'];
            final response = item['admin_response'];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: response == null ? Colors.red[50] : Colors.white,
              child: ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.red),
                title: Text("$sppgName -> $schoolName", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tgl: $date"),
                    Text("Laporan: $notes", style: const TextStyle(color: Colors.black87)),
                    const SizedBox(height: 5),
                    if (response != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(5)),
                        child: Text("Tindak Lanjut: $response", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      )
                    else
                      const Text("BELUM DITANGANI ADMIN SPPG", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: MASALAH KUALITAS MAKANAN (DARI WALI KELAS)
  Widget _buildFoodQualityIssues() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getGlobalTeacherComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada laporan kualitas makanan.");

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final sppgName = item['delivery_stops']['delivery_routes']['sppgs']['name'];
            final schoolName = item['delivery_stops']['schools']['name'];
            final className = item['class_name'];
            final issue = item['issue_type'];
            final notes = item['notes'];
            final response = item['admin_response'];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: response == null ? Colors.red[50] : Colors.white,
              child: ListTile(
                leading: const Icon(Icons.dangerous, color: Colors.red),
                title: Text("$sppgName -> $schoolName ($className)", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ISU: ${issue.toString().toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text("Detail: $notes"),
                    const SizedBox(height: 5),
                    if (response != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(5)),
                        child: Text("Tindak Lanjut: $response", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      )
                    else
                      const Text("BELUM DITANGANI ADMIN SPPG", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.grey),
          const SizedBox(height: 15),
          Text(text, style: const TextStyle(fontSize: 16, color: Colors.grey)),
        ],
      ),
    );
  }
}