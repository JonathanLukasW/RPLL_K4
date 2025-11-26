import 'package:flutter/material.dart';
import '../../shared/services/request_service.dart';

class AdminRequestListScreen extends StatefulWidget {
  const AdminRequestListScreen({super.key});

  @override
  State<AdminRequestListScreen> createState() => _AdminRequestListScreenState();
}

class _AdminRequestListScreenState extends State<AdminRequestListScreen> {
  final RequestService _service = RequestService();

  void _showRespondDialog(String id) {
    final responseController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Respon Pengajuan"),
        content: TextField(
          controller: responseController,
          decoration: const InputDecoration(
            labelText: "Alasan / Catatan",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await _service.respondRequest(
                id,
                'rejected',
                responseController.text,
              );
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("TOLAK", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _service.respondRequest(
                id,
                'approved',
                responseController.text,
              );
              if (!mounted) return;
              Navigator.pop(ctx);
              setState(() {});
            },
            child: const Text("TERIMA"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kotak Masuk Pengajuan"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<ChangeRequestModel>>(
        future: _service.getIncomingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          final data = snapshot.data ?? [];
          if (data.isEmpty)
            return const Center(child: Text("Tidak ada pengajuan baru."));

          return ListView.builder(
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final item = data[i];
              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  leading: const Icon(Icons.mail, color: Colors.orange),
                  title: Text(item.schoolName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "[${item.type}] ${item.requestDate}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(item.oldNotes),
                      if (item.status != 'pending')
                        Text(
                          "Status: ${item.status} (${item.adminResponse})",
                          style: const TextStyle(color: Colors.grey),
                        ),
                    ],
                  ),
                  trailing: item.status == 'pending'
                      ? ElevatedButton(
                          onPressed: () => _showRespondDialog(item.id),
                          child: const Text("Jawab"),
                        )
                      : const Icon(Icons.check, color: Colors.green),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
