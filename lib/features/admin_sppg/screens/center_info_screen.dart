import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- APPROVAL DIALOG ---
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
                requestData: request,
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
                requestData: request,
              );
              setState(() {});
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
          _buildComplaintList(), // Reuse your existing logic or placeholder
        ],
      ),
    );
  }

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

  // Reuse your existing Complaint logic here (simplified for brevity)
  Widget _buildComplaintList() {
    return const Center(
      child: Text(
        "Fitur Pengaduan (Complain) - Coming Soon or reuse existing code",
      ),
    );
  }
}
