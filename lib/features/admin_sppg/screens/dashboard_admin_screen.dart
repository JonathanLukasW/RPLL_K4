import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 

// Import Auth & Login
import '../../../features/autentikasi/services/auth_service.dart';
import '../../../features/autentikasi/screens/login_screen.dart';

// Import Model
import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/route_model.dart';
import '../../../models/courier_model.dart';

// Import Services
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart';
// Note: CoordinatorModel ada di dalam file service ini berdasarkan langkah sebelumnya
import '../services/coordinator_service.dart'; 

// Import Forms (Halaman Tambah)
import 'add_school_screen.dart';
import 'add_transport_screen.dart';
import 'add_courier_screen.dart';
import 'add_coordinator_screen.dart'; // Import Form Koordinator
import 'create_route_screen.dart';
import 'menu_management_screen.dart'; 

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  int _selectedIndex = 0; 
  // Index: 0=Sekolah, 1=Armada, 2=Kurir, 3=Koordinator, 4=Rute

  // Inisialisasi Service
  final SchoolService _schoolService = SchoolService();
  final VehicleService _vehicleService = VehicleService();
  final CourierService _courierService = CourierService();
  final CoordinatorService _coordinatorService = CoordinatorService();
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
      case 3: return "Kelola Koordinator";
      case 4: return "Jadwal & Rute";
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
          // Tombol Manajemen Menu
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
      
      // --- ISI BODY (5 TAB) ---
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSchoolList(),      // 0
          _buildTransportList(),   // 1
          _buildCourierList(),     // 2
          _buildCoordinatorList(), // 3 (BARU)
          _buildRouteList(),       // 4
        ],
      ),

      // --- TOMBOL TAMBAH (+) PINTAR ---
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        // Label dinamis sesuai tab
        label: Text(_getFabLabel()),
        onPressed: () {
          Widget nextPage;
          // Tentukan halaman tujuan berdasarkan tab
          if (_selectedIndex == 0) {
            nextPage = const AddSchoolScreen();
          } else if (_selectedIndex == 1) {
            nextPage = const AddTransportScreen();
          } else if (_selectedIndex == 2) {
            nextPage = const AddCourierScreen();
          } else if (_selectedIndex == 3) {
            nextPage = const AddCoordinatorScreen(); // Halaman Tambah Koordinator
          } else {
            nextPage = const CreateRouteScreen();
          }

          // Navigasi & Refresh setelah kembali
          Navigator.push(context, MaterialPageRoute(builder: (_) => nextPage))
              .then((val) { if (val == true) setState(() {}); });
        },
      ),

      // --- MENU BAWAH (5 ITEM) ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed, 
        selectedItemColor: Colors.orange[800],
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Sekolah"),
          BottomNavigationBarItem(icon: Icon(Icons.local_shipping), label: "Armada"),
          BottomNavigationBarItem(icon: Icon(Icons.person_pin_circle), label: "Kurir"),
          BottomNavigationBarItem(icon: Icon(Icons.supervisor_account), label: "Koord"),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: "Rute"),
        ],
      ),
    );
  }

  String _getFabLabel() {
    switch (_selectedIndex) {
      case 0: return "Sekolah";
      case 1: return "Mobil";
      case 2: return "Kurir";
      case 3: return "Koord";
      case 4: return "Buat Rute";
      default: return "Tambah";
    }
  }

  // ===========================================================================
  // TAB 1: DAFTAR SEKOLAH
  // ===========================================================================
  Widget _buildSchoolList() {
    return FutureBuilder<List<School>>(
      future: _schoolService.getMySchools(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final schools = snapshot.data ?? [];
        if (schools.isEmpty) return _buildEmptyState("Belum ada sekolah.", Icons.school_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: schools.length,
          itemBuilder: (ctx, i) {
            final school = schools[i];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.school, color: Colors.white)),
                title: Text(school.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Siswa: ${school.studentCount} | Deadline: ${school.deadlineTime}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (school.isHighRisk) const Padding(padding: EdgeInsets.only(right:8), child: Icon(Icons.warning, color: Colors.red)),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => AddSchoolScreen(schoolToEdit: school)))
                            .then((val) { if (val == true) setState(() {}); });
                      },
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

  // ===========================================================================
  // TAB 2: DAFTAR TRANSPORTASI
  // ===========================================================================
  Widget _buildTransportList() {
    return FutureBuilder<List<Vehicle>>(
      future: _vehicleService.getMyVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final vehicles = snapshot.data ?? [];
        if (vehicles.isEmpty) return _buildEmptyState("Belum ada kendaraan.", Icons.local_shipping_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: vehicles.length,
          itemBuilder: (ctx, i) {
            final vehicle = vehicles[i];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: Icon(Icons.directions_car, color: vehicle.isActive ? Colors.green : Colors.grey, size: 32),
                title: Text(vehicle.plateNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Supir: ${vehicle.driverName ?? '-'} | Kap.: ${vehicle.capacityLimit}"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                         Navigator.push(context, MaterialPageRoute(builder: (_) => AddTransportScreen(vehicleToEdit: vehicle)))
                            .then((val) { if (val == true) setState(() {}); });
                      },
                    ),
                    Switch(
                      value: vehicle.isActive,
                      activeColor: Colors.green,
                      onChanged: (val) async {
                        await _vehicleService.toggleStatus(vehicle.id, vehicle.isActive);
                        setState(() {}); 
                      },
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

  // ===========================================================================
  // TAB 3: DAFTAR KURIR
  // ===========================================================================
  Widget _buildCourierList() {
    return FutureBuilder<List<CourierModel>>(
      future: _courierService.getMyCouriers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final couriers = snapshot.data ?? [];
        if (couriers.isEmpty) return _buildEmptyState("Belum ada akun kurir.", Icons.person_off_outlined);

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: couriers.length,
          itemBuilder: (ctx, i) {
            final courier = couriers[i];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)),
                title: Text(courier.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(courier.email), 
              ),
            );
          },
        );
      },
    );
  }

  // ===========================================================================
  // TAB 4: DAFTAR KOORDINATOR (BARU)
  // ===========================================================================
  Widget _buildCoordinatorList() {
    return FutureBuilder<List<CoordinatorModel>>(
      future: _coordinatorService.getMyCoordinators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty) return _buildEmptyState("Belum ada koordinator.", Icons.supervised_user_circle);

        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: data.length,
          itemBuilder: (ctx, i) => Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
              title: Text(data[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("${data[i].schoolName}\n${data[i].email}"),
              isThreeLine: true,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // TAB 5: DAFTAR RUTE PENGIRIMAN
  // ===========================================================================
  Widget _buildRouteList() {
    return FutureBuilder<List<DeliveryRoute>>(
      future: _routeService.getMyRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        final routes = snapshot.data ?? [];
        if (routes.isEmpty) return _buildEmptyState("Belum ada jadwal rute.", Icons.map_outlined);

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
                            style: TextStyle(color: _getStatusColor(route.status), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
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