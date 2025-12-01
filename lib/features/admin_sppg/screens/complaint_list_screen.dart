import 'package:flutter/material.dart';
import '../services/complaint_service.dart';

class ComplaintListScreen extends StatefulWidget {
  const ComplaintListScreen({super.key});

  @override
  State<ComplaintListScreen> createState() => _ComplaintListScreenState();
}

class _ComplaintListScreenState extends State<ComplaintListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ComplaintService _service = ComplaintService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // --- DIALOG RESPON ADMIN ---
  void _showRespondDialog(String table, String id, String currentNote) {
    final responseController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Beri Instruksi"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Masalah:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(currentNote, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 15),
              TextField(
                controller: responseController,
                decoration: const InputDecoration(
                  labelText: "Instruksi Tindak Lanjut",
                  hintText: "Contoh: Segera retur, kami kirim pengganti.",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text("Batal")
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _service.respondToComplaint(
                  table: table, 
                  id: id, 
                  response: responseController.text
                );
                
                setState(() {}); // Refresh list
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Instruksi Terkirim!"))
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red)
                  );
                }
              }
            },
            child: const Text("Kirim"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Pengaduan"),
        backgroundColor: Colors.red[700], // Warna Merah biar kerasa 'Urgent'
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Dari Koordinator"),
            Tab(text: "Dari Wali Kelas"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCoordinatorList(),
          _buildTeacherList(),
        ],
      ),
    );
  }

  // TAB 1: LAPORAN KOORDINATOR
  Widget _buildCoordinatorList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getCoordinatorComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(child: Text("Tidak ada laporan dari Koordinator."));
        }

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            // Ambil data dengan pengecekan null yang aman
            final schoolName = item['schools'] != null ? item['schools']['name'] : 'Sekolah ?';
            final note = item['reception_notes'] ?? '-';
            final isResolved = item['admin_response'] != null;

            return Card(
              margin: const EdgeInsets.all(8),
              color: isResolved ? Colors.grey[200] : Colors.red[50],
              child: ListTile(
                leading: Icon(Icons.warning, color: isResolved ? Colors.grey : Colors.red),
                title: Text(schoolName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Laporan: $note"),
                    if (isResolved) 
                      Text("Respon: ${item['admin_response']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: isResolved 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () => _showRespondDialog('delivery_stops', item['id'], note),
                        child: const Text("Respon"),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  // TAB 2: LAPORAN WALI KELAS
  Widget _buildTeacherList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _service.getTeacherComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final data = snapshot.data ?? [];
        if (data.isEmpty) {
          return const Center(child: Text("Tidak ada laporan dari Wali Kelas."));
        }

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            
            // Navigasi JSON yang agak dalam karena join
            String schoolName = 'Sekolah ?';
            if (item['delivery_stops'] != null && 
                item['delivery_stops']['schools'] != null) {
               schoolName = item['delivery_stops']['schools']['name'];
            }

            final className = item['class_name'] ?? '-';
            final issue = item['issue_type'] ?? 'Masalah';
            final note = item['notes'] ?? '-';
            final isResolved = item['admin_response'] != null;

            return Card(
              margin: const EdgeInsets.all(8),
              color: isResolved ? Colors.grey[200] : Colors.red[50],
              child: ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: Text("$schoolName - Kls $className"),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Masalah: $issue"),
                    Text("Catatan: $note"),
                    if (isResolved) 
                      Text("Respon: ${item['admin_response']}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                trailing: isResolved 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : ElevatedButton(
                        onPressed: () => _showRespondDialog('class_receptions', item['id'], "$issue: $note"),
                        child: const Text("Respon"),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}