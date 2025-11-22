import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

// Import Auth & Login
import '../../../features/autentikasi/services/auth_service.dart';
import '../../../features/autentikasi/screens/login_screen.dart';

// Import Model
import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/route_model.dart';
import '../../../models/courier_model.dart'; // Pastikan model ini ada jika dipakai di Kurir list

// Import Services
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart';

// Import Forms
import 'add_school_screen.dart';
import 'add_transport_screen.dart';
import 'add_courier_screen.dart';
import 'create_route_screen.dart';
import 'menu_management_screen.dart'; // Import Halaman Manajemen Menu

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  int _selectedIndex = 0; // 0=Sekolah, 1=Transport, 2=Kurir, 3=Rute

  // Inisialisasi Service
  final SchoolService _schoolService = SchoolService();
  final VehicleService _vehicleService = VehicleService();
  final CourierService _courierService = CourierService();
  final RouteService _routeService = RouteService(); 

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
          // [BARU] Tombol Manajemen Menu
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: "Manajemen Menu",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MenuManagementScreen()),
              );
            },
          ),
          // Tombol Logout
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      
      // --- ISI BODY (4 TAB) ---
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSchoolList(),    // Index 0
          _buildTransportList(), // Index 1
          _buildCourierList(),   // Index 2
          _buildRouteList(),     // Index 3 
        ],
      ),

      // --- TOMBOL TAMBAH (+) PINTAR ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          _selectedIndex == 0 ? "Sekolah" : 
          _selectedIndex == 1 ? "Mobil" : 
          _selectedIndex == 2 ? "Kurir" : "Buat Rute"
        ),
        onPressed: () {
          Widget nextPage;
          if (_selectedIndex == 0) {
            nextPage = const AddSchoolScreen();
          } else if (_selectedIndex == 1) {
            nextPage = const AddTransportScreen();
          } else if (_selectedIndex == 2) {
            nextPage = const AddCourierScreen();
          } else {
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
        type: BottomNavigationBarType.fixed, 
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

  // ===========================================================================
  // TAB 1: DAFTAR SEKOLAH
  // ===========================================================================
  Widget _buildSchoolList() {
    return FutureBuilder<List<School>>(
      future: _schoolService.getMySchools(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final schools = snapshot.data ?? [];
        
        if (schools.isEmpty) {
          return _buildEmptyState("Belum ada sekolah.", Icons.school_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: schools.length,
          itemBuilder: (context, index) {
            final school = schools[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.school, color: Colors.white),
                ),
                title: Text(school.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Siswa: ${school.studentCount} | Deadline: ${school.deadlineTime}"),
                trailing: school.isHighRisk 
                    ? const Icon(Icons.warning, color: Colors.red) 
                    : const Icon(Icons.check_circle, color: Colors.green, size: 16),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 2: DAFTAR TRANSPORTASI
  // ===========================================================================
  Widget _buildTransportList() {
    return FutureBuilder<List<Vehicle>>(
      future: _vehicleService.getMyVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final vehicles = snapshot.data ?? [];

        if (vehicles.isEmpty) {
          return _buildEmptyState("Belum ada kendaraan.", Icons.local_shipping_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: Icon(
                  Icons.directions_car, 
                  color: vehicle.isActive ? Colors.green : Colors.grey,
                  size: 32,
                ),
                title: Text(vehicle.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Supir: ${vehicle.driverName ?? '-'} | Kapasitas: ${vehicle.capacityLimit}"),
                trailing: Switch(
                  value: vehicle.isActive,
                  activeColor: Colors.green,
                  onChanged: (val) async {
                    await _vehicleService.toggleStatus(vehicle.id, vehicle.isActive);
                    setState(() {}); 
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 3: DAFTAR KURIR
  // ===========================================================================
  Widget _buildCourierList() {
    return FutureBuilder<List<CourierModel>>(
      future: _courierService.getMyCouriers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        final couriers = snapshot.data ?? [];

        if (couriers.isEmpty) {
          return _buildEmptyState("Belum ada akun kurir.", Icons.person_off_outlined);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: couriers.length,
          itemBuilder: (context, index) {
            final courier = couriers[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(courier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(courier.email), 
                trailing: const Icon(Icons.edit, size: 20),
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 4: DAFTAR RUTE PENGIRIMAN
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
            final date = DateTime.tryParse(route.date) ?? DateTime.now();
            final dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);

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

  // Widget Helper untuk Tampilan Kosong
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'active': return Colors.blue;
      default: return Colors.orange; // pending
    }
  }
}