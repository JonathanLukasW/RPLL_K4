import 'package:flutter/material.dart';
import '../../shared/services/request_service.dart'; // Sesuaikan path

class CoordinatorRequestScreen extends StatefulWidget {
  const CoordinatorRequestScreen({super.key});

  @override
  State<CoordinatorRequestScreen> createState() => _CoordinatorRequestScreenState();
}

class _CoordinatorRequestScreenState extends State<CoordinatorRequestScreen> {
  final RequestService _service = RequestService();
  final _detailsController = TextEditingController();
  String _selectedType = 'Perubahan Jadwal';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pengajuan Perubahan"), backgroundColor: Colors.teal),
      body: Column(
        children: [
          // --- FORM PENGAJUAN ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Buat Pengajuan Baru", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: "Jenis Pengajuan", border: OutlineInputBorder()),
                      items: ['Perubahan Jadwal', 'Perubahan Menu', 'Tambah/Kurang Porsi']
                          .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _detailsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Detail Permintaan", 
                        hintText: "Contoh: Mohon kirim jam 10 karena ada ujian.",
                        border: OutlineInputBorder()
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: const Icon(Icons.send),
                        label: const Text("Kirim Pengajuan"),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
          
          const Divider(),
          
          // --- LIST RIWAYAT ---
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("Riwayat Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_detailsController.text.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await _service.submitRequest(type: _selectedType, details: _detailsController.text);
      _detailsController.clear();
      setState(() {}); // Refresh list
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Terkirim!")));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<ChangeRequestModel>>(
      future: _service.getMyRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return const Center(child: Text("Belum ada riwayat."));

        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            Color statusColor = Colors.orange;
            if (item.status == 'approved') statusColor = Colors.green;
            if (item.status == 'rejected') statusColor = Colors.red;

            return ListTile(
              title: Text(item.type, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${item.details}\nRespon: ${item.adminResponse ?? '-'}", style: const TextStyle(fontSize: 12)),
              trailing: Chip(
                label: Text(item.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10)),
                backgroundColor: statusColor,
              ),
            );
          },
        );
      },
    );
  }
}