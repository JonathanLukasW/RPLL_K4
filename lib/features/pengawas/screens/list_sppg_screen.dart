import 'package:flutter/material.dart';
// Pastikan service ini sudah diperbaiki dengan langkah nomor 1
import '../services/sppg_service.dart';
// Sesuaikan path model
import '../../../models/sppg_model.dart';
import 'add_sppg_screen.dart'; 
// IMPORT INI PENTING (file detail yang kita buat sebelumnya)
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
      // Ini tidak akan merah lagi kalau SppgService sudah diperbaiki
      final data = await _sppgService.getAllSppgs();
      if (!mounted) return;
      setState(() {
        _sppgList = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Master SPPG"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
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
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () {
                            // Navigasi ke Detail
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailSppgScreen(sppg: sppg),
                              ),
                            );
                          },
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
          const Text("Belum ada data SPPG.", style: TextStyle(fontSize: 16, color: Colors.grey)),
          TextButton(onPressed: _fetchData, child: const Text("Refresh")),
        ],
      ),
    );
  }
}