import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../autentikasi/screens/login_screen.dart';
import '../services/receiving_service.dart';

class DashboardKoordinatorScreen extends StatefulWidget {
  const DashboardKoordinatorScreen({super.key});

  @override
  State<DashboardKoordinatorScreen> createState() => _DashboardKoordinatorScreenState();
}

class _DashboardKoordinatorScreenState extends State<DashboardKoordinatorScreen> {
  final ReceivingService _service = ReceivingService();
  
  Map<String, dynamic>? _deliveryData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getTodayDelivery();
      if (mounted) setState(() => _deliveryData = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- DIALOG KONFIRMASI ---
  void _showConfirmationDialog(String stopId) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Penerimaan"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Jumlah Diterima (Box)", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Catatan (Jika ada kerusakan)", border: OutlineInputBorder()),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _service.confirmReception(
                stopId: stopId,
                receivedQty: int.tryParse(qtyController.text) ?? 0,
                notes: noteController.text,
                recipientName: "Koordinator Sekolah", // Nanti ambil dari profile
              );
              _fetchData(); // Refresh dashboard
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Penerimaan Dikonfirmasi!")));
            },
            child: const Text("Terima Barang"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Portal Sekolah"),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _deliveryData == null
            ? const Center(child: Text("Tidak ada jadwal pengiriman hari ini."))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatusCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatusCard() {
    final status = _deliveryData!['status'];
    final vehicle = _deliveryData!['delivery_routes']['vehicles'];
    final plat = vehicle != null ? vehicle['plate_number'] : '-';
    final driver = vehicle != null ? vehicle['driver_name'] : '-';
    
    Color statusColor = Colors.grey;
    String statusText = "Menunggu";
    
    if (status == 'completed') { // 'completed' dari sisi kurir artinya sudah sampai
      statusColor = Colors.orange;
      statusText = "Barang Tiba - Perlu Konfirmasi";
    } else if (status == 'received') {
      statusColor = Colors.green;
      statusText = "Selesai - Diterima";
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, size: 40, color: statusColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pengiriman Hari Ini", style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text("Mobil: $plat ($driver)", style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            
            // TOMBOL AKSI (Hanya muncul jika kurir sudah 'completed' tapi sekolah belum 'received')
            if (status == 'completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmationDialog(_deliveryData!['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("KONFIRMASI PENERIMAAN"),
                ),
              )
          ],
        ),
      ),
    );
  }
}