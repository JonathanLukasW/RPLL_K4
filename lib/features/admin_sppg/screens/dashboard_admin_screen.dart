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
import '../services/coordinator_service.dart';
import '../services/teacher_service.dart';
// Import Services
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart';
// Import Forms & Screens
import 'add_school_screen.dart';
import 'add_transport_screen.dart';
import 'add_courier_screen.dart';
import 'add_coordinator_screen.dart';
import 'add_teacher_screen.dart';
import 'create_route_screen.dart';
import 'menu_management_screen.dart';
import 'complaint_list_screen.dart';
import 'statistics_screen.dart';
import 'production_calendar_screen.dart';
import '../../../core/screens/profile_screen.dart';
import 'edit_account_screen.dart'; // Pastikan ini ada jika digunakan untuk edit user
import 'edit_route_screen.dart'; // Import Screen Edit Rute

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  int _selectedIndex = 0;
// Inisialisasi Service
  final SchoolService _schoolService = SchoolService();
  final VehicleService _vehicleService = VehicleService();
  final CourierService _courierService = CourierService();
  final CoordinatorService _coordinatorService = CoordinatorService();
  final TeacherService _teacherService = TeacherService();
  final RouteService _routeService = RouteService();

  Future<void> _logout() async {
    await AuthService().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return "Kelola Sekolah";
      case 1:
        return "Kelola Armada";
      case 2:
        return "Kelola Kurir";
      case 3:
        return "Kelola Koordinator";
      case 4:
        return "Kelola Wali Kelas";
      case 5:
        return "Jadwal & Rute";
      default:
        return "Admin SPPG";
    }
  }

  String _getFabLabel() {
    switch (_selectedIndex) {
      case 0:
        return "Sekolah";
      case 1:
        return "Mobil";
      case 2:
        return "Kurir";
      case 3:
        return "Koord";
      case 4:
        return "Wali";
      case 5:
        return "Buat Rute";
      default:
        return "Tambah";
    }
  }
  
  // [BARU] Fungsi Delete Rute (UC18)
  Future<void> _deleteRoute(String routeId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Rute?"),
        content: const Text(
            "Menghapus rute akan menghapus semua perhentian dan jadwal produksi terkait. Yakin?"),
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
      try {
        await _routeService.deleteRoute(routeId); // Panggil service yang sudah di-update
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Rute dan Jadwal Produksi Dihapus!")));
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error Hapus Rute: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // [FUNGSI LAIN UNTUK DELETE (SAMA SEPERTI SEBELUMNYA)]
  Future<void> _deleteSchool(String schoolId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Sekolah?"),
        content: const Text("Yakin mau hapus lokasi ini? Semua data terkait (koordinator/wali) mungkin kena imbas."),
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
      try {
        await _schoolService.deleteSchool(schoolId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sekolah Dihapus!")));
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

 Future<void> _deleteVehicle(String vehicleId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kendaraan?"),
        content: const Text("Hapus plat ini dari armada?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ), // <-- KOMPONEN PERTAMA
          
          TextButton( // <-- KOMPONEN KEDUA
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _vehicleService.deleteVehicle(vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mobil Dihapus!")));
      setState(() {});
    }
  }

  Future<void> _deleteUser(String userId, String roleName) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Hapus Akun $roleName?"),
        content: const Text("Tindakan ini permanen. Akun ini akan hilang."),
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
      try {
        if (roleName == 'Kurir') await _courierService.deleteCourierAccount(userId);
        if (roleName == 'Koordinator') await _coordinatorService.deleteCoordinatorAccount(userId);
        if (roleName == 'Wali Kelas') await _teacherService.deleteTeacherAccount(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Akun $roleName Dihapus!")));
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _navigateToEditAccount(
    String userId,
    String role,
    Map<String, dynamic> data,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountScreen(
          userId: userId,
          initialRole: role,
          initialData: data,
        ),
      ),
    ).then((val) {
      if (val == true) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: "Kalender Produksi",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProductionCalendarScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(
              Icons.notification_important,
              color: Colors.redAccent,
            ),
            tooltip: "Laporan Pengaduan",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ComplaintListScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: "Laporan Kinerja",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StatisticsScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.restaurant_menu),
            tooltip: "Manajemen Menu",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MenuManagementScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: "Profil Saya",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSchoolList(), // 0
          _buildTransportList(), // 1
          _buildCourierList(), // 2
          _buildCoordinatorList(), // 3
          _buildTeacherList(), // 4
          _buildRouteList(), // 5
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_getFabLabel()),
        onPressed: () {
          Widget nextPage;
          if (_selectedIndex == 0)
            nextPage = const AddSchoolScreen();
          else if (_selectedIndex == 1)
            nextPage = const AddTransportScreen();
          else if (_selectedIndex == 2)
            nextPage = const AddCourierScreen();
          else if (_selectedIndex == 3)
            nextPage = const AddCoordinatorScreen();
          else if (_selectedIndex == 4)
            nextPage = const AddTeacherScreen();
          else
            nextPage = const CreateRouteScreen();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => nextPage),
          ).then((val) {
            if (val == true) setState(() {});
          });
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.orange[800],
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.school), label: "Sekolah"),
          BottomNavigationBarItem(
            icon: Icon(Icons.local_shipping),
            label: "Armada",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_pin_circle),
            label: "Kurir",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.supervisor_account),
            label: "Koord",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: "Wali"),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: "Rute",
          ),
        ],
      ),
    );
  }

// --- LIST BUILDERS ---
  Widget _buildSchoolList() {
    return FutureBuilder<List<School>>(
      future: _schoolService.getMySchools(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final schools = snapshot.data ?? [];
        if (schools.isEmpty)
          return _buildEmptyState("Belum ada sekolah.", Icons.school_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: schools.length,
          itemBuilder: (ctx, i) {
            final school = schools[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: Icon(Icons.school, color: Colors.white),
                ),
                title: Text(
                  school.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Siswa: ${school.studentCount} | Deadline: ${school.deadlineTime}",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC25)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddSchoolScreen(schoolToEdit: school),
                          ),
                        ).then((val) {
                          if (val == true) setState(() {});
                        });
                      },
                    ),
                    // DELETE Button (UC26)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSchool(school.id), 
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

  Widget _buildTransportList() {
    return FutureBuilder<List<Vehicle>>(
      future: _vehicleService.getMyVehicles(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final vehicles = snapshot.data ?? [];
        if (vehicles.isEmpty)
          return _buildEmptyState("Belum ada kendaraan.", Icons.local_shipping_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: vehicles.length,
          itemBuilder: (ctx, i) {
            final vehicle = vehicles[i];
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.directions_car,
                  color: vehicle.isActive ? Colors.green : Colors.grey,
                  size: 32,
                ),
                title: Text(
                  vehicle.plateNumber,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Supir: ${vehicle.driverName ?? '-'} | Kap.: ${vehicle.capacityLimit}",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC34)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AddTransportScreen(vehicleToEdit: vehicle),
                          ),
                        ).then((val) {
                          if (val == true) setState(() {});
                        });
                      },
                    ),
                    // DELETE Button (UC35)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteVehicle(vehicle.id),
                    ),
                    // Status Toggle
                    Switch(
                      value: vehicle.isActive,
                      activeColor: Colors.green,
                      onChanged: (val) async {
                        await _vehicleService.toggleStatus(
                          vehicle.id,
                          vehicle.isActive,
                        );
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

  Widget _buildCourierList() {
    return FutureBuilder<List<CourierModel>>(
      future: _courierService.getMyCouriers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final couriers = snapshot.data ?? [];
        if (couriers.isEmpty)
          return _buildEmptyState("Belum ada akun kurir.", Icons.person_off_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: couriers.length,
          itemBuilder: (ctx, i) {
            final courier = couriers[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueGrey,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  courier.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(courier.email),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC31)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _navigateToEditAccount(courier.id, 'kurir',
                          {'name': courier.name, 'email': courier.email, 'schoolId': null, 'className': null}),
                    ),
                    // DELETE Button (UC32)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(courier.id, 'Kurir'),
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

  Widget _buildCoordinatorList() {
    return FutureBuilder<List<CoordinatorModel>>(
      future: _coordinatorService.getMyCoordinators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return _buildEmptyState("Belum ada koordinator.", Icons.supervised_user_circle);
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final coord = data[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, color: Colors.white),
                ),
                title: Text(
                  coord.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("${coord.schoolName}\n${coord.email}"),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC31)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _navigateToEditAccount(coord.id, 'koordinator',
                          {'name': coord.name, 'email': coord.email, 'schoolId': coord.schoolId, 'className': null}),
                    ),
                    // DELETE Button (UC32)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(coord.id, 'Koordinator'),
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

  Widget _buildTeacherList() {
    return FutureBuilder<List<TeacherModel>>(
      future: _teacherService.getMyTeachers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return _buildEmptyState("Belum ada wali kelas.", Icons.class_);
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final teacher = data[i];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.indigo,
                  child: Icon(Icons.class_, color: Colors.white),
                ),
                title: Text(
                  teacher.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${teacher.schoolName} - Kelas ${teacher.className}\n${teacher.email}",
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC31)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _navigateToEditAccount(teacher.id, 'walikelas',
                          {'name': teacher.name, 'email': teacher.email, 'schoolId': teacher.schoolId, 'className': teacher.className}),
                    ),
                    // DELETE Button (UC32)
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteUser(teacher.id, 'Wali Kelas'),
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

  Widget _buildRouteList() {
    return FutureBuilder<List<DeliveryRoute>>(
      future: _routeService.getMyRoutes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final routes = snapshot.data ?? [];
        if (routes.isEmpty)
          return _buildEmptyState("Belum ada jadwal rute.", Icons.map_outlined);
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: routes.length,
          itemBuilder: (context, index) {
            final route = routes[index];
            final date = DateTime.tryParse(route.date) ?? DateTime.now();
            String dateStr = route.date;
            try {
              dateStr = DateFormat('EEEE, d MMM yyyy', 'id_ID').format(date);
            } catch (_) {}
            final isPending = route.status == 'pending'; // Check the status
            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                // [AKSI] Tap opens the Edit/Detail screen
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditRouteScreen(route: route),
                    ),
                  ).then((val) {
                    setState(() {});
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          // Status Text
                          Text(
                            route.status.toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(route.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Added this for spacing
                        children: [
                          // Left Side: Courier & Vehicle Info
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.person, size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Text(
                                  route.courierName ?? "Kurir Hapus",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(width: 15),
                                const Icon(Icons.local_shipping, size: 16, color: Colors.grey),
                                const SizedBox(width: 5),
                                Text(
                                  route.vehiclePlate ?? "-",
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                          // Right Side: DELETE BUTTON
                          if (isPending)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: "Hapus Rute",
                              onPressed: () => _deleteRoute(route.id), // <-- Panggil fungsi delete
                            ),
                        ],
                      ),
                    ],
                  ),
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
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      default:
        return Colors.orange;
    }
  }
}