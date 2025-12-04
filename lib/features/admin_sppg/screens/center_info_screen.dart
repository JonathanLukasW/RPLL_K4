// FILE: lib/features/admin_sppg/screens/center_info_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/services/request_service.dart';
import '../services/complaint_service.dart';

class CenterInfoScreen extends StatefulWidget {
  const CenterInfoScreen({super.key});

  @override
  State<CenterInfoScreen> createState() => _CenterInfoScreenState();
}

class _CenterInfoScreenState extends State<CenterInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RequestService _requestService = RequestService();
  final ComplaintService _complaintService = ComplaintService();

  // [FIX] Definisikan Key untuk memaksa refresh tab Komplain
  Key _complaintKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _refreshData() {
    setState(() {
      // Force refresh of the complaint tab's FutureBuilder
      _complaintKey = UniqueKey();
    });
  }

  // --- APPROVAL DIALOG (Untuk Request) ---
  void _showApprovalDialog(ChangeRequestModel request) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Review: ${request.type}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sekolah: ${request.schoolName}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              width: double.infinity,
              child: Text(
                request.oldNotes,
              ), // Shows the summarized request data
            ),
            const SizedBox(height: 15),
            const Text("Catatan Admin (Alasan Ditolak/Info):"),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (noteController.text.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wajib isi alasan penolakan!")),
                );
                return;
              }
              Navigator.pop(ctx);
              await _requestService.respondRequest(
                requestId: request.id,
                status: 'rejected',
                adminNote: noteController.text,
                requestData: request, // <--- CRITICAL: Pass the data object
              );
              setState(() {});
            },
            child: const Text("TOLAK", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // "Apply Changes" logic is handled in the service for Menu/Porsi
              await _requestService.respondRequest(
                requestId: request.id,
                status: 'approved',
                adminNote: noteController.text.isEmpty
                    ? "OK"
                    : noteController.text,
                requestData: request, // <--- CRITICAL: Pass the data object
              );
              setState(() {});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Disetujui & Data Diupdate!")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("TERIMA & TERAPKAN"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Informasi"), // Renamed from Pusat Pengaduan
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // ADD REFRESH BUTTON
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Pengajuan (Request)"),
            Tab(text: "Pengaduan (Complain)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList(),
          _buildComplaintList(key: _complaintKey), // Use the dynamic key
        ],
      ),
    );
  }

  // --- WIDGET LIST PENGAJUAN (REQUEST) ---
  Widget _buildRequestList() {
    return FutureBuilder<List<ChangeRequestModel>>(
      future: _requestService.getIncomingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());

        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(child: Text("Tidak ada pengajuan masuk."));

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            bool isPending = item.status == 'pending';
            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: Icon(
                  item.type.contains("Menu")
                      ? Icons.restaurant_menu
                      : (item.type.contains("Porsi")
                            ? Icons.pie_chart
                            : Icons.calendar_today),
                  color: Colors.indigo,
                ),
                title: Text(
                  item.schoolName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("[${item.type}]"),
                    Text(
                      item.oldNotes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isPending)
                      Text(
                        "Status: ${item.status.toUpperCase()} (${item.adminResponse})",
                        style: TextStyle(
                          color: item.status == 'approved'
                              ? Colors.green
                              : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                ),
                trailing: isPending
                    ? ElevatedButton(
                        onPressed: () => _showApprovalDialog(item),
                        child: const Text("Review"),
                      )
                    : const Icon(Icons.check_circle, color: Colors.grey),
              ),
            );
          },
        );
      },
    );
  }

  // --- WIDGET LIST PENGADUAN (COMPLAINT) ---
  Widget _buildComplaintList({required Key key}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: key,
      future: _complaintService.getSppgComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(
            child: Text(
              "Tidak ada keluhan masuk dari Koordinator maupun Wali Kelas.",
            ),
          );
        }

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            final isResolved = item['admin_response'] != null;
            final reporterRole = item['reporter_role'] ?? 'N/A';

            // Tentukan target table dan ID untuk update
            // ID complaint di RPC (item['id']) adalah ID PRIMARY KEY di CR/DS
            final targetTable = reporterRole == 'walikelas'
                ? 'class_receptions'
                : 'delivery_stops';
            final targetId = item['id'];

            return Card(
              color: isResolved ? Colors.green[50] : Colors.red[100],
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        color: isResolved ? Colors.green[800] : Colors.red[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                trailing: isResolved
                    ? const Icon(Icons.reply, color: Colors.grey)
                    : ElevatedButton(
                        onPressed: () => _showRespondComplaintDialog(
                          item,
                          reporterRole,
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
    );
  }

  // --- DIALOG TINDAK LANJUT KOMPLAIN ---
  void _showRespondComplaintDialog(
    Map<String, dynamic> complaint,
    String reporterRole,
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
                "Instruksi / Tindak Lanjut Admin SPPG (Untuk ${reporterRole.toUpperCase()})",
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
                // Panggil service untuk mendapatkan ID user yang benar-benar melapor
                finalReporterUserId = await _complaintService
                    .getReporterIdForNotification(targetTableId, reporterRole);
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
                id: complaint['id'], // ID unik complaint (dari RPC)
                response: responseController.text,
                reporterId:
                    finalReporterUserId, // ID user yang akan dapat notif
                reporterRole: reporterRole,
                targetTableId: targetTableId,
                targetTableName: targetTable,
              );
              _refreshData();
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
