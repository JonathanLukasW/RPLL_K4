import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk format tanggal di list rute

// Import Auth
import '../../../features/autentikasi/services/auth_service.dart';
import '../../../features/autentikasi/screens/login_screen.dart';

// Import Models
import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/route_model.dart'; // Model Rute

// Import Services
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart'; // Service Rute

// Import Forms
import 'add_school_screen.dart';
import 'add_transport_screen.dart';
import 'add_courier_screen.dart';
import 'create_route_screen.dart'; // Layar Buat Rute

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  int _selectedIndex = 0; // 0=Sekolah, 1=Mobil, 2=Kurir, 3=Rute

  // Inisialisasi Semua Service
  final SchoolService _schoolService = SchoolService();
  final VehicleService _vehicleService = VehicleService();
  final CourierService _courierService = CourierService();
  final RouteService _routeService = RouteService(); // Service Rute

  // --- FUNGSI LOGOUT ---
  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- JUDUL APP BAR ---
  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return "Kelola Sekolah";
      case 1: return "Kelola Armada";
      case 2: return "Kelola Kurir";
      case 3: return "Jadwal & Rute";
      default: return "Admin SPPG";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      
      // --- ISI DASHBOARD (4 TAB) ---
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSchoolList(),    // 0
          _buildTransportList(), // 1
          _buildCourierList(),   // 2
          _buildRouteList(),     // 3 (TAB BARU)
        ],
      ),

      // --- TOMBOL TAMBAH (+) PINTAR ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        // Label tombol berubah sesuai tab
        label: Text(
          _selectedIndex == 0 ? "Sekolah" : 
          _selectedIndex == 1 ? "Mobil" : 
          _selectedIndex == 2 ? "Kurir" : "Buat Rute"
        ),
        onPressed: () {
          Widget nextPage;
          // Tentukan mau buka halaman apa
          if (_selectedIndex == 0) {
            nextPage = const AddSchoolScreen();
          } else if (_selectedIndex == 1) {
            nextPage = const AddTransportScreen();
          } else if (_selectedIndex == 2) {
            nextPage = const AddCourierScreen();
          } else {
            // Tab 3: Buka Halaman Buat Rute
            nextPage = const CreateRouteScreen();
          }

          // Navigasi & Refresh setelah kembali
          Navigator.push(context, MaterialPageRoute(builder: (_) => nextPage))
              .then((val) { if (val == true) setState(() {}); });
        },
      ),

      // --- MENU BAWAH (4 ITEM) ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, // Wajib fixed kalau item > 3
        selectedItemColor: Colors.orange[800],
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Sekolah"),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: "Armada"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Kurir"),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: "Rute"),
        ],
      ),
    );
  }

  // ... Widget List Sekolah, Transport, & Kurir SAMA SEPERTI SEBELUMNYA ...
  // (Bisa dicopy dari jawaban sebelumnya, atau biarkan kode lama di bagian ini)
  // Biar hemat tempat, aku tulis ulang yang SchoolList dkk secara ringkas,
  // TAPI YANG PENTING ADALAH FUNGSI _buildRouteList DI BAWAH INI 👇

  Widget _buildSchoolList() {
     return FutureBuilder<List<School>>(
      future: _schoolService.getMySchools(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada sekolah.", Icons.school);
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(data[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Siswa: ${data[i].studentCount}"),
              leading: const Icon(Icons.school, color: Colors.orange),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransportList() {
     return FutureBuilder<List<Vehicle>>(
      future: _vehicleService.getMyVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada kendaraan.", Icons.local_shipping);
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(data[i].plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data[i].driverName ?? "-"),
              leading: const Icon(Icons.directions_car, color: Colors.blueGrey),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCourierList() {
     return FutureBuilder<List<CourierModel>>(
      future: _courierService.getMyCouriers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada kurir.", Icons.person);
        return ListView.builder(
          itemCount: data.length,
          itemBuilder: (ctx, i) => Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            child: ListTile(
              title: Text(data[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(data[i].email),
              leading: const Icon(Icons.person, color: Colors.green),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // [BARU] TAB 4: DAFTAR RUTE PENGIRIMAN
  // ===========================================================================
  Widget _buildRouteList() {
    return FutureBuilder<List<DeliveryRoute>>(
      future: _routeService.getMyRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        
        final routes = snapshot.data ?? [];
        if (routes.isEmpty) {
          return _buildEmptyState("Belum ada jadwal rute.", Icons.map_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            
            // Format Tanggal biar cantik (Misal: Senin, 20 Nov 2025)
            // Kalau 'id_ID' error, hapus parameter locale-nya
            final dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(DateTime.parse(route.date));

            return Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Header Card: Tanggal & Status
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(route.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getStatusColor(route.status)),
                          ),
                          child: Text(
                            route.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(route.status), 
                              fontSize: 10, 
                              fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    // Info Kurir & Mobil
                    Row(
                      children: [
                        const Icon(Icons.person, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(route.courierName ?? "Kurir Hapus", style: const TextStyle(fontSize: 14)),
                        const Spacer(),
                        const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text(route.vehiclePlate ?? "-", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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

  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          const SizedBox(height: 5),
          const Text("Tekan tombol (+) di bawah.", style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}