import 'package:flutter/material.dart';
import '../services/sppg_service.dart';
import '../../../models/sppg_model.dart';

class ListSppgScreen extends StatefulWidget {
  const ListSppgScreen({super.key});

  @override
  State<ListSppgScreen> createState() => _ListSppgScreenState();
}

class _ListSppgScreenState extends State<ListSppgScreen> {
  final SppgService _sppgService = SppgService();
  
  // Variabel untuk menampung data
  List<Sppg> _sppgList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData(); // Ambil data pas halaman dibuka
  }

  Future<void> _fetchData() async {
    try {
      final data = await _sppgService.getAllSppgs();
      setState(() {
        _sppgList = data;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() => _isLoading = false);
    }
  }

  // Fungsi menampilkan Dialog Tambah SPPG
  void _showAddDialog() {
    final nameController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tambah SPPG Baru"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Nama SPPG"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(labelText: "Alamat"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                // Panggil Service untuk simpan ke Supabase
                await _sppgService.createSppg(
                  nameController.text,
                  addressController.text,
                );
                Navigator.pop(context); // Tutup dialog
                _fetchData(); // Refresh data
              }
            },
            child: const Text("Simpan"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Data Master SPPG")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _sppgList.isEmpty
              ? const Center(child: Text("Belum ada data SPPG. Tambahkan baru!"))
              : ListView.builder(
                  itemCount: _sppgList.length,
                  itemBuilder: (context, index) {
                    final sppg = _sppgList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.kitchen)),
                        title: Text(sppg.name),
                        subtitle: Text(sppg.address ?? "-"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        onTap: () {
                          // Nanti di sini kita buat fitur Lihat Detail / Tambah Admin SPPG
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}