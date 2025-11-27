// === FILE: lib/features/admin_sppg/screens/route_read_only_screen.dart ===
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/route_model.dart';
import '../../admin_sppg/services/route_service.dart'; // <--- YOU MISSED THIS IMPORT!

class RouteReadOnlyScreen extends StatelessWidget {
  final DeliveryRoute route;

  // Create an instance of the service here, or call the method statically if appropriate
  // Since deleteRoute is NOT static, we must create an instance:
  final RouteService _routeService =
      RouteService(); // <--- INSTANTIATE THE SERVICE

  RouteReadOnlyScreen({super.key, required this.route});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    String dateStr = DateFormat(
      'EEEE, d MMMM yyyy',
      'id_ID',
    ).format(DateTime.parse(route.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Rute (Read-Only)"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: _getStatusColor(route.status).withOpacity(0.1),
              child: ListTile(
                leading: Icon(Icons.info, color: _getStatusColor(route.status)),
                title: Text("Status: ${route.status.toUpperCase()}"),
                subtitle: const Text(
                  "Rute ini masih dalam status perencanaan (PENDING) dan hanya dapat Dihapus atau Dijalankan.",
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Detail Tugas",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(Icons.calendar_today, "Tanggal", dateStr),
            _buildDetailRow(Icons.person, "Kurir", route.courierName ?? '-'),
            _buildDetailRow(
              Icons.local_shipping,
              "Kendaraan",
              route.vehiclePlate ?? '-',
            ),

            const SizedBox(height: 30),

            const Text(
              "Daftar Sekolah Tujuan (Akses Read-Only)",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            const Text(
              "Anda perlu memuat data Delivery Stops untuk melihat detail per sekolah.",
              style: TextStyle(color: Colors.grey),
            ),

            const SizedBox(height: 40),

            // Add Delete Button if Pending
            if (route.status == 'pending')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _confirmDelete(context, route.id),
                  icon: const Icon(Icons.delete),
                  label: const Text("HAPUS RUTE INI"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey, size: 24),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  // Duplicated Delete function from Dashboard for immediacy on this screen
  Future<void> _confirmDelete(BuildContext context, String routeId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Rute?"),
        content: const Text(
          "Ini akan menghapus total rute, termasuk semua perhentian. HANYA LAKUKAN JIKA BATAL TOTAL.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx, true);
              try {
                // CALL THE INSTANTIATED SERVICE!
                await _routeService.deleteRoute(routeId);

                if (!context.mounted) return;
                Navigator.pop(
                  context,
                  true,
                ); // Go back to dashboard and signal success
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Rute Dihapus!")));
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("Error Hapus Rute: $e"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
