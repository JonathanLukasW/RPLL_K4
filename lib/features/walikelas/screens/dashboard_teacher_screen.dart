import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../autentikasi/screens/login_screen.dart';
import '../services/teacher_reception_service.dart';

class DashboardTeacherScreen extends StatefulWidget {
  const DashboardTeacherScreen({super.key});

  @override
  State<DashboardTeacherScreen> createState() => _DashboardTeacherScreenState();
}

class _DashboardTeacherScreenState extends State<DashboardTeacherScreen> {
  final TeacherReceptionService _service = TeacherReceptionService();
  
  Map<String, dynamic>? _deliveryData;
  bool _isLoading = true;
  bool _alreadyReceived = false;
  String _className = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getSchoolDeliveryStatus();
      if (mounted) {
        setState(() {
          _deliveryData = data;
          if (data != null) {
            _alreadyReceived = data['already_received'] ?? false;
            _className = data['my_class_name'] ?? "-";
          }
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  void _showReceiveDialog() {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Konfirmasi Kelas $_className"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Pastikan jumlah sesuai dan makanan dalam kondisi baik."),
            const SizedBox(height: 15),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Jumlah Diterima", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Catatan (Opsional)", border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.submitClassReception(
                stopId: _deliveryData!['id'],
                className: _className,
                qty: int.tryParse(qtyController.text) ?? 0,
                notes: noteController.text,
              );
              _fetchData(); // Refresh
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil dikonfirmasi!")));
            },
            child: const Text("Simpan"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Wali Kelas $_className"), // Tampilkan nama kelas di header
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _deliveryData == null
              ? const Center(child: Text("Belum ada jadwal pengiriman."))
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Status Pengiriman (dari tabel delivery_stops)
    // pending -> active -> completed (Kurir Tiba) -> received (Koord Terima)
    final String status = _deliveryData!['status'];
    
    String message = "Makanan sedang diproses.";
    Color color = Colors.grey;
    bool canReceive = false;

    if (status == 'completed') {
      message = "Makanan sudah tiba di Sekolah.\nMenunggu Koordinator cek.";
      color = Colors.orange;
    } else if (status == 'received') {
      message = "Makanan SIAP DIAMBIL / DIBAGIKAN.";
      color = Colors.green;
      canReceive = true; // Tombol aktif
    }

    if (_alreadyReceived) {
      message = "Anda sudah mengonfirmasi penerimaan hari ini.";
      color = Colors.blue;
      canReceive = false;
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: color.withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: color)
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _alreadyReceived ? Icons.check_circle : Icons.local_dining, 
                    size: 50, color: color
                  ),
                  const SizedBox(height: 10),
                  Text(message, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          
          if (canReceive)
            ElevatedButton.icon(
              onPressed: _showReceiveDialog,
              icon: const Icon(Icons.inventory),
              label: const Text("KONFIRMASI TERIMA DI KELAS"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            )
        ],
      ),
    );
  }
}