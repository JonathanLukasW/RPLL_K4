import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 

// Import Services & Models
import '../../admin_sppg/services/route_service.dart';
import '../../autentikasi/screens/login_screen.dart';
import '../../../models/route_model.dart';

class DashboardKurirScreen extends StatelessWidget {
  // [FIX]: Constructor bisa const karena tidak ada final fields non-const
  const DashboardKurirScreen({super.key}); 
  
  // HILANGKAN deklarasi final RouteService _routeService = ... di sini.

  // --- FUNGSI LOGOUT ---
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- LOGIKA AMBIL & TAMPILKAN RUTE ---
  Widget _buildRouteList(BuildContext context) {
    // [FIX UTAMA]: Service dibuat LOKAL di dalam method (bukan final field)
    final RouteService routeService = RouteService();

    // Memanggil fungsi yang memfilter berdasarkan ID Kurir
    return FutureBuilder<List<DeliveryRoute>>(
      future: routeService.getRoutesByCourier(), // Panggil service lokal
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final routes = snapshot.data ?? [];

        if (routes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_outlined, size: 80, color: Colors.blue[100]),
                const SizedBox(height: 16),
                const Text("Belum ada tugas pengiriman hari ini.", style: TextStyle(fontSize: 16)),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            (context as Element).markNeedsBuild(); 
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              final date = DateTime.tryParse(route.date) ?? DateTime.now();
              final dateStr = DateFormat('EEEE, d MMM', 'id_ID').format(date);

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const Icon(Icons.delivery_dining, color: Colors.blue),
                  title: Text(
                    "Tugas Tgl: $dateStr",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Armada: ${route.vehiclePlate ?? '-'}"),
                  trailing: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(route.status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      route.status.toUpperCase(),
                      style: TextStyle(color: _getStatusColor(route.status), fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Fitur Detail Rute akan dibuat!")),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'active': return Colors.blue;
      default: return Colors.orange; // pending
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Pengiriman"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: _buildRouteList(context), 
    );
  }
}