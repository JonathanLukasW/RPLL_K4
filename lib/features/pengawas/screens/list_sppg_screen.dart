import 'package:flutter/material.dart';
import '../services/sppg_service.dart';
import '../../../models/sppg_model.dart';
import 'add_sppg_screen.dart';
import 'detail_sppg_screen.dart';

class ListSppgScreen extends StatefulWidget {
  const ListSppgScreen({super.key});

  @override
  State<ListSppgScreen> createState() => _ListSppgScreenState();
}

class _ListSppgScreenState extends State<ListSppgScreen> {
  final SppgService _sppgService = SppgService();

  List<Sppg> _sppgList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _sppgService.getAllSppgs();
      if (!mounted) return;
      setState(() {
        _sppgList = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  // Fungsi Delete
  Future<void> _deleteSppg(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus SPPG?"),
        content: const Text("Data yang dihapus tidak bisa dikembalikan."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _sppgService.deleteSppg(id);
      _fetchData(); // Refresh list
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Master SPPG"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          // [BARU] TOMBOL REFRESH
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: _fetchData, // Panggil fungsi refresh data
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _sppgList.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: _sppgList.length,
                itemBuilder: (context, index) {
                  final sppg = _sppgList[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        child: Icon(Icons.kitchen, color: Colors.blue[800]),
                      ),
                      title: Text(
                        sppg.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        sppg.address ?? "Alamat belum diisi",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // TOMBOL EDIT
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AddSppgScreen(sppgToEdit: sppg),
                                ),
                              ).then((val) {
                                if (val == true) _fetchData();
                              });
                            },
                          ),
                          // TOMBOL DELETE
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteSppg(sppg.id),
                          ),
                          // TOMBOL DETAIL (PANAH)
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      DetailSppgScreen(sppg: sppg),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSppgScreen()),
          );
          if (result == true) {
            _fetchData();
          }
        },
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Tambah SPPG"),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.business_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "Belum ada data SPPG.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          TextButton(onPressed: _fetchData, child: const Text("Refresh")),
        ],
      ),
    );
  }
}
