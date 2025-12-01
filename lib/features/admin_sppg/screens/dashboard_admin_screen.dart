// === FILE: lib\features\admin_sppg\screens\dashboard_admin_screen.dart ===
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
// Import Auth
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
import 'create_route_screen.dart'; // <<< FIX: Ini yang harus ada
import 'menu_management_screen.dart';
import 'complaint_list_screen.dart';
import 'statistics_screen.dart';
import 'production_calendar_screen.dart';
import '../../../core/screens/profile_screen.dart';
import 'edit_account_screen.dart';
import 'edit_route_screen.dart';
import 'admin_request_list_screen.dart';

class DashboardAdminScreen extends StatefulWidget {
  const DashboardAdminScreen({super.key});

  @override
  State<DashboardAdminScreen> createState() => _DashboardAdminScreenState();
}

class _DashboardAdminScreenState extends State<DashboardAdminScreen> {
  int _selectedIndex = 0;
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

  // --- ACTIONS UTILITIES ---
  Future<void> _deleteSchool(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Sekolah?"),
        content: const Text(
            "Semua data terkait, termasuk akun koordinator/wali kelas, akan terpengaruh."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () async {
                await _schoolService.deleteSchool(id);
                if (!mounted) return;
                Navigator.pop(ctx, true);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Sekolah berhasil dihapus!")));
                setState(() {});
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) setState(() {});
  }

  Future<void> _deleteVehicle(String id) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Kendaraan?"),
        content: const Text(
            "Kendaraan ini tidak akan bisa digunakan lagi untuk rute baru."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () async {
                await _vehicleService.deleteVehicle(id);
                if (!mounted) return;
                Navigator.pop(ctx, true);
                setState(() {});
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) setState(() {});
  }

  Future<void> _deleteUser(String id, String role) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Hapus Akun $role?"),
        content: Text("Akun $role ini akan dihapus permanen."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Batal")),
          TextButton(
              onPressed: () async {
                if (role == 'Kurir') {
                  await _courierService.deleteCourierAccount(id);
                } else if (role == 'Koordinator') {
                  await _coordinatorService.deleteCoordinatorAccount(id);
                } else if (role == 'Wali Kelas') {
                  await _teacherService.deleteTeacherAccount(id);
                }
                if (!mounted) return;
                Navigator.pop(ctx, true);
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text("Akun $role berhasil dihapus!"),
                    backgroundColor: Colors.green));
              },
              child: const Text("Hapus", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) setState(() {});
  }

  void _navigateToEditAccount(
      String id, String role, Map<String, dynamic> data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditAccountScreen(
          userId: id,
          initialRole: role,
          initialData: data,
        ),
      ),
    ).then((val) {
      if (val == true) setState(() {});
    });
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
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProductionCalendarScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: "Profil",
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'inbox') {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdminRequestListScreen()));
              } else if (value == 'complaint') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ComplaintListScreen()));
              } else if (value == 'stats') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const StatisticsScreen()));
              } else if (value == 'menu') {
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const MenuManagementScreen()));
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'inbox',
                child: ListTile(
                    leading: Icon(Icons.mail, color: Colors.orange),
                    title: Text('Kotak Masuk Pengajuan')),
              ),
              const PopupMenuItem<String>(
                value: 'complaint',
                child: ListTile(
                    leading: Icon(Icons.warning, color: Colors.red),
                    title: Text('Laporan Masalah')),
              ),
              const PopupMenuItem<String>(
                value: 'stats',
                child: ListTile(
                    leading: Icon(Icons.bar_chart, color: Colors.blue),
                    title: Text('Statistik Kinerja')),
              ),
              const PopupMenuItem<String>(
                value: 'menu',
                child: ListTile(
                    leading: Icon(Icons.restaurant_menu, color: Colors.green),
                    title: Text('Manajemen Menu')),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                    leading: Icon(Icons.logout, color: Colors.grey),
                    title: Text('Logout')),
              ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSchoolList(),
          _buildTransportList(),
          _buildCourierList(),
          _buildCoordinatorList(),
          _buildTeacherList(),
          _buildRouteList(), // 5. Rute
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_getFabLabel()),
        onPressed: () {
          Widget nextPage;
          if (_selectedIndex == 0) nextPage = const AddSchoolScreen();
          else if (_selectedIndex == 1) nextPage = const AddTransportScreen();
          else if (_selectedIndex == 2) nextPage = const AddCourierScreen();
          else if (_selectedIndex == 3) nextPage = const AddCoordinatorScreen();
          else if (_selectedIndex == 4) nextPage = const AddTeacherScreen();
          else
            nextPage =
                const CreateRouteScreen(); // <<< FIX 2: CREATE ROUTE (Sesuai dengan file aslinya, ini diarahkan ke screen, tapi di file sebelumnya ini adalah service)
          Navigator.push(context, MaterialPageRoute(builder: (_) => nextPage))
              .then((val) {
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
              icon: Icon(Icons.local_shipping), label: "Armada"),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_pin_circle), label: "Kurir"),
          BottomNavigationBarItem(
              icon: Icon(Icons.supervisor_account), label: "Koord"),
          BottomNavigationBarItem(icon: Icon(Icons.class_), label: "Wali"),
          BottomNavigationBarItem(
              icon: Icon(Icons.map_outlined), label: "Rute"),
        ],
      ),
    );
  }

  // --- WIDGET LIST BUILDERS ---
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
                    child: Icon(Icons.school, color: Colors.white)),
                title: Text(school.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                // [PERBAIKAN] Menghapus tampilan deadlineTime yang berisi JSON string
                subtitle: Text("Siswa: ${school.studentCount} | Risiko: ${school.isHighRisk ? 'Tinggi' : 'Normal'}"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    AddSchoolScreen(schoolToEdit: school))).then(
                            (val) {
                          if (val == true) setState(() {});
                        });
                      }),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSchool(school.id)),
                ]),
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
          return _buildEmptyState(
              "Belum ada kendaraan.", Icons.local_shipping_outlined);

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
                    size: 32),
                title: Text(vehicle.plateNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    "Supir: ${vehicle.driverName ?? '-'} | Kap.: ${vehicle.capacityLimit}"),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AddTransportScreen(
                                    vehicleToEdit: vehicle))).then((val) {
                          if (val == true) setState(() {});
                        });
                      }),
                  IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteVehicle(vehicle.id)),
                  Switch(
                      value: vehicle.isActive,
                      activeColor: Colors.green,
                      onChanged: (val) async {
                        await _vehicleService.toggleStatus(
                            vehicle.id, vehicle.isActive);
                        setState(() {});
                      }),
                ]),
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
          return _buildEmptyState(
              "Belum ada akun kurir.", Icons.person_off_outlined);

        return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: couriers.length,
            itemBuilder: (ctx, i) {
              final c = couriers[i];
              return Card(
                  child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Colors.blueGrey,
                          child: Icon(Icons.person, color: Colors.white)),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(c.email),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditAccount(c.id, 'kurir',
                                {'name': c.name, 'email': c.email, 'schoolId': null, 'className': null})),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(c.id, 'Kurir')),
                      ])));
            });
      },
    );
  }

  Widget _buildCoordinatorList() {
    return FutureBuilder(
      future: _coordinatorService.getMyCoordinators(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return _buildEmptyState(
              "Belum ada koordinator.", Icons.supervised_user_circle);

        return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: data.length,
            itemBuilder: (ctx, i) {
              final c = data[i];
              return Card(
                  child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.person, color: Colors.white)),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${c.schoolName}\n${c.email}"),
                      isThreeLine: true,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditAccount(c.id, 'koordinator',
                                {'name': c.name, 'email': c.email, 'schoolId': c.schoolId, 'className': null})),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(c.id, 'Koordinator')),
                      ])));
            });
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
              final t = data[i];
              return Card(
                  child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Colors.indigo,
                          child: Icon(Icons.class_, color: Colors.white)),
                      title: Text(t.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          "${t.schoolName} - Kelas ${t.className}\n${t.email}"),
                      isThreeLine: true,
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditAccount(t.id, 'walikelas',
                                {'name': t.name, 'email': t.email, 'schoolId': t.schoolId, 'className': t.className})),
                        IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteUser(t.id, 'Wali Kelas')),
                      ])));
            });
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
          return _buildEmptyState(
              "Belum ada jadwal rute.", Icons.map_outlined);

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

            return Card(
              elevation: 3,
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () {
                  // Buka Layar Edit Rute & Peta
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditRouteScreen(route: route)),
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
                          Text(dateStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(route.status.toUpperCase(),
                              style: TextStyle(
                                  color: _getStatusColor(route.status),
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Divider(),
                      Row(
                        children: [
                          const Icon(Icons.person, size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(route.courierName ?? "Kurir Hapus",
                              style: const TextStyle(fontSize: 14)),
                          const Spacer(),
                          const Icon(Icons.local_shipping,
                              size: 16, color: Colors.grey),
                          const SizedBox(width: 5),
                          Text(route.vehiclePlate ?? "-",
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
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
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 70, color: Colors.grey[300]),
      const SizedBox(height: 10),
      Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600]))
    ]));
  }
}