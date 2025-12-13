// FILE: lib/features/admin_sppg/screens/dashboard_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Import untuk jsonDecode
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
import 'statistics_screen.dart';
import 'production_calendar_screen.dart';
import '../../../core/screens/profile_screen.dart';
import 'edit_account_screen.dart';
import 'edit_route_screen.dart';
import 'center_info_screen.dart';
import 'route_calendar_screen.dart';

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

  // [BARU] State untuk Filter Sekolah
  String? _selectedSchoolFilterId;
  List<School> _allSppgSchools = []; // Cache semua sekolah SPPG ini

  // State untuk tombol Generate Otomatis
  bool _isGenerating = false;
  // [BARU] State untuk Tanggal Generate Otomatis
  DateTime _generateDate = DateTime.now(); // Default hari ini

  // [BARU] State untuk Filter Rute
  DateTime _selectedRouteFilterDate = DateTime.now(); // <--- BARU
  String?
  _selectedRouteFilterVehicleId; // <--- BARU ('all' jika tidak ada filter)
  List<Vehicle> _allVehicles = []; // <--- Cache kendaraan (sudah ada)

  @override
  void initState() {
    super.initState();
    // Inisialisasi tanggal filter
    _selectedRouteFilterDate = DateTime(
      _selectedRouteFilterDate.year,
      _selectedRouteFilterDate.month,
      _selectedRouteFilterDate.day,
    );

    _loadInitialFilters(); // Load sekolah untuk filter
    // Tambahkan inisialisasi _generateDate ke midnight
    _generateDate = DateTime(
      _generateDate.year,
      _generateDate.month,
      _generateDate.day,
    );
  }

  // ... (perlu modifikasi _loadInitialFilters untuk memuat vehicles)
  Future<void> _loadInitialFilters() async {
    try {
      final results = await Future.wait([
        _schoolService.getMySchools(),
        _vehicleService.getMyVehicles(), // Load Vehicles
      ]);
      final schools = results[0] as List<School>;
      final vehicles = results[1] as List<Vehicle>; // Ambil data kendaraan

      if (mounted) {
        setState(() {
          _allSppgSchools = schools;
          _allVehicles = vehicles; // Set data kendaraan
          _selectedRouteFilterVehicleId = 'all'; // Default filter mobil
        });
      }
    } catch (e) {
      print("Gagal load daftar sekolah untuk filter: $e");
    }
  }

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
        return "Koordinator";
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
          "Menghapus rute akan menghapus semua perhentian dan jadwal produksi terkait. Yakin?",
        ),
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
        await _routeService.deleteRoute(
          routeId,
        ); // Panggil service yang sudah di-update
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rute dan Jadwal Produksi Dihapus!")),
        );
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

  // [FUNGSI LAIN UNTUK DELETE]
  Future<void> _deleteSchool(String schoolId) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Sekolah?"),
        content: const Text(
          "Yakin mau hapus lokasi ini? Semua data terkait (koordinator/wali) mungkin kena imbas.",
        ),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Sekolah Dihapus!")));
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
          ),

          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _vehicleService.deleteVehicle(vehicleId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Mobil Dihapus!")));
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
        if (roleName == 'Kurir')
          await _courierService.deleteCourierAccount(userId);
        if (roleName == 'Koordinator')
          await _coordinatorService.deleteCoordinatorAccount(userId);
        if (roleName == 'Wali Kelas')
          await _teacherService.deleteTeacherAccount(userId);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Akun $roleName Dihapus!")));
        setState(() {});
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
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

  // --- HELPER METHODS ---

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

  // [BARU] Helper untuk memformat deadline time JSON
  String _formatScheduleDisplay(String? deadlineJson) {
    if (deadlineJson == null || deadlineJson.isEmpty)
      return "Jadwal Belum Diset";

    try {
      final Map<String, dynamic> data = jsonDecode(deadlineJson);
      final List<String> scheduleEntries = [];

      // Urutan hari yang diinginkan
      const List<String> days = [
        'Senin',
        'Selasa',
        'Rabu',
        'Kamis',
        'Jumat',
        'Sabtu',
      ];

      for (var day in days) {
        if (data.containsKey(day) && data[day] != null) {
          final timeStr = (data[day] as String).substring(0, 5); // Ambil HH:mm
          scheduleEntries.add("$day $timeStr");
        }
      }

      if (scheduleEntries.isEmpty) return "Tidak ada jadwal aktif";

      // Gabungkan entry (misal: Senin 09:40, Selasa 09:40)
      return scheduleEntries.join(', ');
    } catch (_) {
      return "Format Jadwal Rusak";
    }
  }

  // [BARU] Helper Sorting Kelas (Angka dulu, baru Huruf)
  int _sortClasses(String? a, String? b) {
    if (a == null || b == null) return 0;
    final exp = RegExp(r'^(\d+)([a-zA-Z]*)');
    final matchA = exp.firstMatch(a.toUpperCase());
    final matchB = exp.firstMatch(b.toUpperCase());

    if (matchA == null || matchB == null) return a.compareTo(b);

    final numA = int.tryParse(matchA.group(1)!) ?? 0;
    final numB = int.tryParse(matchB.group(1)!) ?? 0;
    final charA = matchA.group(2) ?? '';
    final charB = matchB.group(2) ?? '';

    // 1. Sort by Number (Class Level: 7 < 8 < 9)
    if (numA != numB) return numA.compareTo(numB);

    // 2. Sort by Character (Class Sub-Division: A < B < C)
    return charA.compareTo(charB);
  }

  // [BARU] Fungsi Generate Routes Otomatis
  // [MODIFIKASI] Fungsi Generate Routes Otomatis (Sekarang bisa memilih tanggal)
  Future<void> _generateRoutesForToday() async {
    // 1. Tampilkan Date Picker
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _generateDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'Pilih Tanggal Generate Rute',
    );

    if (pickedDate == null) return;

    final targetDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
    );

    // 2. Konfirmasi setelah tanggal dipilih
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Konfirmasi Generate Rute"),
        content: Text(
          "Anda yakin ingin membuat rute otomatis untuk tanggal ${DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(targetDate)}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "GENERATE SEKARANG",
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isGenerating = true;
      _generateDate = targetDate; // Simpan tanggal yang dipilih
    });

    try {
      // Memanggil logika routing di RouteService DENGAN TANGGAL YANG DIPILIH
      final routesCreated = await _routeService.generateDailyRoutes(
        date: targetDate,
      ); // <--- KIRIM TANGGAL

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Berhasil membuat $routesCreated rute pengiriman otomatis untuk ${DateFormat('d MMM').format(targetDate)}!",
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
      setState(() {}); // Refresh list rute
    } catch (e) {
      // <--- TAMBAHKAN 'e' DI SINI
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Gagal Generate Rute: ${e.toString().replaceAll('Exception:', '')}",
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 7),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
  // --- END HELPER METHODS ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          // [BARU] TOMBOL REFRESH DATA AKTIF
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh Data",
            onPressed: () {
              setState(() {}); // Memaksa rebuild FutureBuilders di IndexStack
            },
          ),
          // Tombol Daily Batch (Hanya muncul di tab Rute)
          if (_selectedIndex == 5)
            _isGenerating
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  )
                : // END _isGenerating
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 1. CALENDAR ICON (Routes/Jadwal Rutin Calendar)
                      IconButton(
                        icon: const Icon(Icons.calendar_today, size: 24),
                        tooltip: "Jadwal Rutin Mingguan",
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RouteCalendarScreen(),
                            ),
                          );
                        },
                      ),
                      // [BARU] TOMBOL GENERATE OTOMATIS (Di sebelah kanan)
                      IconButton(
                        icon: const Icon(
                          Icons.auto_awesome,
                          color: Colors.amber,
                        ), // Icon yang menarik
                        tooltip: "Generate Rute Otomatis Hari Ini",
                        onPressed:
                            _generateRoutesForToday, // Panggil fungsi baru
                      ),
                    ],
                  ),

          // 2. HAMBURGER MENU (Consolidated Options)
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'production') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProductionCalendarScreen(),
                  ),
                );
              } else if (value == 'menu') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MenuManagementScreen(),
                  ),
                );
              } else if (value == 'reports') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CenterInfoScreen()),
                );
              } else if (value == 'stats') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StatisticsScreen()),
                );
              } else if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                _logout();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'production',
                child: Text("Kalender Produksi"),
              ),
              const PopupMenuItem<String>(
                value: 'menu',
                child: Text("Manajemen Menu"),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'reports',
                child: Text("Pusat Informasi"),
              ),

              const PopupMenuItem<String>(
                value: 'stats',
                child: Text("Laporan"),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'profile',
                child: Text("Profil Saya"),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text("LOGOUT", style: TextStyle(color: Colors.red)),
              ),
            ],
            icon: const Icon(Icons.menu, color: Colors.white),
          ),
        ],
      ),
      // Konten Body: IndexedStack + Tombol Fixed
      body: Column(
        // Column membungkus IndexedStack dan tombol fixed
        children: [
          Expanded(
            // IndexedStack harus dibungkus Expanded
            child: IndexedStack(
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
          ),

          // Tombol Fixed (berada di bawah Expanded IndexStack)
          _buildFixedAddButton(context),
        ],
      ),
      // Navigasi Bawah tetap ada
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
            label: "Koordinator",
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

  // Widget Tambahan: Tombol Fixed (Dipindahkan dari _buildFixedAddButton)
  Widget _buildFixedAddButton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.add),
          label: Text(
            "TAMBAH ${_getFabLabel().toUpperCase()}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
      ),
    );
  }

  // Widget List Sekolah (Diperbarui dengan format jadwal baru)
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
          padding: const EdgeInsets.fromLTRB(
            10,
            10,
            10,
            80,
          ), // Tambahkan padding bawah agar tombol tidak tertutup
          itemCount: schools.length,
          itemBuilder: (ctx, i) {
            final school = schools[i];

            // Format Jadwal Deadline
            final formattedSchedule = _formatScheduleDisplay(
              school.deadlineTime,
            );

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
                  // [FIX DI SINI] Gunakan helper function yang baru
                  "Siswa: ${school.studentCount} | Deadline: $formattedSchedule",
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
                            builder: (_) =>
                                AddSchoolScreen(schoolToEdit: school),
                          ),
                        ).then((val) {
                          if (val == true)
                            setState(
                              () {},
                            ); // <-- THIS IS THE CORRECT REFRESH CALL
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
          return _buildEmptyState(
            "Belum ada kendaraan.",
            Icons.local_shipping_outlined,
          );
        return ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: vehicles.length,
          itemBuilder: (ctx, i) {
            final vehicle = vehicles[i];

            // [BARU]: Info Asisten
            String assistantText = vehicle.assistantCourierName != null
                ? "Asisten: ${vehicle.assistantCourierName}"
                : "Tidak ada Asisten";

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
                // [UPDATE SUBTITLE]: Tampilkan Asisten
                subtitle: Text(
                  "Supir: ${vehicle.driverName ?? '-'} | Kap.: ${vehicle.capacityLimit}\n$assistantText",
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true, // Ubah ke 3 baris
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
                            builder: (_) =>
                                AddTransportScreen(vehicleToEdit: vehicle),
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
          return _buildEmptyState(
            "Belum ada akun kurir.",
            Icons.person_off_outlined,
          );
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
                // [UPDATE SUBTITLE] Tampilkan email dan nomor telepon
                subtitle: Text(
                  "${courier.email}\nTelp: ${courier.phoneNumber ?? '-'}",
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true, // Ubah ke 3 baris
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // EDIT Button (UC31)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _navigateToEditAccount(courier.id, 'kurir', {
                            'name': courier.name,
                            'email': courier.email,
                            'schoolId': null,
                            'className': null,
                            'phoneNumber': courier.phoneNumber,
                          }),
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
    // Siapkan list untuk Dropdown Filter
    final List<DropdownMenuItem<String?>> schoolItems = [
      const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
      ..._allSppgSchools.map(
        (school) =>
            DropdownMenuItem(value: school.id, child: Text(school.name)),
      ),
    ];

    return Column(
      children: [
        // Dropdown Filter Sekolah
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: "Filter Berdasarkan Sekolah",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.filter_list),
            ),
            value: _selectedSchoolFilterId,
            items: schoolItems,
            onChanged: (String? newValue) {
              setState(() {
                _selectedSchoolFilterId = newValue;
              });
            },
          ),
        ),
        // List Koordinator
        Expanded(
          child: FutureBuilder<List<CoordinatorModel>>(
            future: _coordinatorService.getMyCoordinators(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];

              // [FILTERING LOGIC]
              final filteredData = data.where((coord) {
                if (_selectedSchoolFilterId == null) return true;
                return coord.schoolId == _selectedSchoolFilterId;
              }).toList();

              // [SORTING LOGIC BARU] Sort berdasarkan Nama Sekolah (Ascending)
              filteredData.sort((a, b) {
                return a.schoolName.toLowerCase().compareTo(
                  b.schoolName.toLowerCase(),
                );
              });

              if (filteredData.isEmpty)
                return _buildEmptyState(
                  "Belum ada koordinator di sekolah yang dipilih.",
                  Icons.supervised_user_circle,
                );
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(
                  10,
                  0,
                  10,
                  80,
                ), // Padding bawah agar tombol tidak tertutup
                itemCount: filteredData.length,
                itemBuilder: (ctx, i) {
                  final coord = filteredData[i];
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
                      // [UPDATE SUBTITLE] Tampilkan sekolah, email, dan nomor telepon
                      subtitle: Text(
                        "${coord.schoolName}\n${coord.email}\nTelp: ${coord.phoneNumber ?? '-'}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // EDIT Button (UC31)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditAccount(
                              coord.id,
                              'koordinator',
                              {
                                'name': coord.name,
                                'email': coord.email,
                                'schoolId': coord.schoolId,
                                'className': null,
                                'phoneNumber': coord.phoneNumber,
                                'schoolName':
                                    coord.schoolName, // <--- KRITIS: TAMBAH INI
                              },
                            ),
                          ),
                          // DELETE Button (UC32)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteUser(coord.id, 'Koordinator'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherList() {
    // Siapkan list untuk Dropdown Filter (Sama dengan Koordinator)
    final List<DropdownMenuItem<String?>> schoolItems = [
      const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
      ..._allSppgSchools.map(
        (school) =>
            DropdownMenuItem(value: school.id, child: Text(school.name)),
      ),
    ];

    return Column(
      children: [
        // Dropdown Filter Sekolah (Wajib di dalam Column)
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButtonFormField<String?>(
            decoration: const InputDecoration(
              labelText: "Filter Berdasarkan Sekolah",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.filter_list),
            ),
            value: _selectedSchoolFilterId,
            items: schoolItems,
            onChanged: (String? newValue) {
              setState(() {
                _selectedSchoolFilterId = newValue;
              });
            },
          ),
        ),
        // List Wali Kelas
        Expanded(
          // Harus dibungkus Expanded
          child: FutureBuilder<List<TeacherModel>>(
            future: _teacherService.getMyTeachers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());
              final data = snapshot.data ?? [];

              // [FILTERING LOGIC]
              final filteredData = data.where((teacher) {
                if (_selectedSchoolFilterId == null) return true;
                return teacher.schoolId == _selectedSchoolFilterId;
              }).toList();

              // [SORTING LOGIC]
              filteredData.sort((a, b) {
                // 1. Sort by School Name (Ascending)
                final schoolCompare = a.schoolName.toLowerCase().compareTo(
                  b.schoolName.toLowerCase(),
                );
                if (schoolCompare != 0) return schoolCompare;

                // 2. Sort by Class Name (Custom Alphanumeric)
                return _sortClasses(a.className, b.className);
              });

              if (filteredData.isEmpty)
                return _buildEmptyState(
                  "Belum ada wali kelas di sekolah yang dipilih.",
                  Icons.class_,
                );

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 80),
                itemCount: filteredData.length,
                itemBuilder: (ctx, i) {
                  final teacher = filteredData[i];
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
                      // [UPDATE SUBTITLE] Tampilkan sekolah, kelas, email, dan nomor telepon
                      subtitle: Text(
                        // [FIX 1]: Tampilkan jumlah penerima kelas
                        "${teacher.schoolName} - Kelas ${teacher.className} (${teacher.studentCountClass} Siswa)\n${teacher.email}\nTelp: ${teacher.phoneNumber ?? '-'}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // EDIT Button (UC31)
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _navigateToEditAccount(
                              teacher.id,
                              'walikelas',
                              {
                                'name': teacher.name,
                                'email': teacher.email,
                                'schoolId': teacher.schoolId,
                                'className': teacher.className,
                                'phoneNumber': teacher.phoneNumber,
                                'schoolName': teacher.schoolName,
                                // [FIX 2]: Tambahkan data kuota kelas ke initialData
                                'studentCountClass': teacher.studentCountClass,
                              },
                            ),
                          ), // DELETE Button (UC32)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteUser(teacher.id, 'Wali Kelas'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper untuk format waktu
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr;
    }
  }

  Widget _buildRouteList() {
    final List<DropdownMenuItem<String?>> vehicleItems = [
      const DropdownMenuItem(value: 'all', child: Text("Semua Armada")),
      ..._allVehicles
          .map(
            (vehicle) => DropdownMenuItem(
              value: vehicle.id,
              child: Text(vehicle.plateNumber),
            ),
          )
          .toList(),
    ];

    return Column(
      children: [
        // --- FILTER SECTION ---
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Filter Tanggal
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                  ),
                  title: Text(
                    DateFormat(
                      'd MMMM yyyy',
                      'id_ID',
                    ).format(_selectedRouteFilterDate),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedRouteFilterDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedRouteFilterDate = picked;
                      });
                    }
                  },
                ),
              ),
              // Filter Mobil
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedRouteFilterVehicleId,
                  decoration: const InputDecoration(labelText: "Filter Mobil"),
                  items: vehicleItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedRouteFilterVehicleId = newValue;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // --- LIST RUTE HASIL FILTER ---
        Expanded(
          child: FutureBuilder<List<DeliveryRoute>>(
            future: _routeService.getMyRoutes(
              date: _selectedRouteFilterDate,
              vehicleId: _selectedRouteFilterVehicleId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              final routes = snapshot.data ?? [];
              if (routes.isEmpty)
                return _buildEmptyState(
                  "Tidak ada rute yang cocok dengan filter.",
                  Icons.map_outlined,
                );

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: routes.length,
                itemBuilder: (context, index) {
                  final route = routes[index];
                  final status = route.status;
                  final date = DateTime.tryParse(route.date) ?? DateTime.now();
                  final dateStr = DateFormat('dd MMM yy', 'id_ID').format(date);
                  final isPending = status == 'pending';

                  Color statusColor = _getStatusColor(status);

                  // **INNER FUTURE BUILDER untuk mendapatkan Tujuan Pertama**
                  return FutureBuilder<Map<String, dynamic>?>(
                    future: _routeService.getNextPendingStop(route.id),
                    builder: (context, stopSnapshot) {
                      final nextStop = stopSnapshot.data;

                      String tujuanInfo = "Semua Stop Selesai";
                      String jamInfo = _formatTime(
                        route.departureTime,
                      ); // Default: Jam Berangkat

                      if (route.status == 'completed' ||
                          route.status == 'received' ||
                          route.status == 'issue_reported') {
                        tujuanInfo = "Rute Selesai Total";
                        jamInfo = _formatTime(route.departureTime);
                      } else if (nextStop != null &&
                          (route.status == 'active' ||
                              route.status == 'pending')) {
                        tujuanInfo = "Tujuan 1: ${nextStop['schools']['name']}";
                        jamInfo = _formatTime(
                          nextStop['estimated_arrival_time'],
                        ); // ETA ke Stop 1
                      }

                      return Card(
                        elevation: 3,
                        color:
                            status == 'received' || status == 'issue_reported'
                            ? Colors.green[50]
                            : Colors.grey[100],
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => EditRouteScreen(route: route),
                              ),
                            ).then((val) {
                              if (val == true) setState(() {});
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // BARIS 1: TANGGAL & STATUS
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$dateStr - ${route.vehiclePlate ?? '-'}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      route.status.toUpperCase(),
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 10),

                                // BARIS 2: KURIR & TUJUAN
                                Text(
                                  "Kurir: ${route.courierName ?? 'N/A'}",
                                  style: const TextStyle(fontSize: 14),
                                ),
                                const SizedBox(height: 5),

                                // BARIS 3: TUJUAN DAN JAM KRITIS
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on,
                                      size: 16,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        tujuanInfo,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 10),
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      jamInfo,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),

                                // Tombol Hapus (Hanya muncul jika Pending)
                                if (isPending)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      tooltip: "Hapus Rute",
                                      onPressed: () => _deleteRoute(route.id),
                                    ),
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
            },
          ),
        ),
      ],
    );
  }
}
