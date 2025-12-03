import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart'; // Import untuk firstWhereOrNull
import '../../autentikasi/screens/login_screen.dart';
import '../services/teacher_reception_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/screens/profile_screen.dart';
// === FILE: lib/features/walikelas/screens/dashboard_teacher_screen.dart ===

// [BARU] Import untuk Screen Notifikasi
import '../../shared/screens/notification_screen.dart';
import '../../shared/services/notification_service.dart';

class DashboardTeacherScreen extends StatefulWidget {
  const DashboardTeacherScreen({super.key});

  @override
  State<DashboardTeacherScreen> createState() => _DashboardTeacherScreenState();
}

class _DashboardTeacherScreenState extends State<DashboardTeacherScreen> {
  final TeacherReceptionService _service = TeacherReceptionService();
  final StorageService _storageService = StorageService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat =
      CalendarFormat.week; // Default Minggu biar ringkas
  // Map menyimpan tanggal (hanya date, tanpa time) dengan list of deliveries (stops)
  Map<DateTime, List<Map<String, dynamic>>> _deliveries = {};
  bool _isLoading = true;
  String _myClassName = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    _fetchDeliveries();
  }

  // Ambil data pengiriman untuk bulan yang sedang fokus
  Future<void> _fetchDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getMonthlyDeliveries(_focusedDay);
      Map<DateTime, List<Map<String, dynamic>>> newMap = {};

      for (var item in data) {
        final dateStr = item['delivery_routes']['date'];
        final date = DateTime.parse(dateStr);
        final dateKey = DateTime(date.year, date.month, date.day);

        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(item);

        // Ambil nama kelas dari data pertama
        if (_myClassName.isEmpty) {
          _myClassName = item['my_class_name'] ?? 'Kelas Lain';
        }
      }

      if (mounted) {
        setState(() {
          _deliveries = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal load jadwal: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _deliveries[dateKey] ?? [];
  }

  // Event Handler untuk konfirmasi penerimaan
  void _showReceptionDialog(Map<String, dynamic> stopData) {
    // ... (Your existing reception dialog logic will go here. I'm stubbing it for brevity)
  }

  // Helper untuk mendapatkan icon status
  IconData _getStatusIcon(bool alreadyReceived, String stopStatus) {
    if (alreadyReceived) return Icons.check_box;
    if (stopStatus == 'received' || stopStatus == 'completed')
      return Icons.delivery_dining;
    return Icons.pending_actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Wali Kelas - ${_myClassName.isNotEmpty ? _myClassName : 'Loading...'}",
        ),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<int>(
            future: NotificationService().getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications),
                ),
                tooltip: "Notifikasi",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  ).then((value) => setState(() {}));
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: "Profil & Password",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- KALENDER ---
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _fetchDeliveries(); // Refresh data saat bulan berubah
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.indigo, // Warna untuk hari ada jadwal
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange, // Warna untuk hari yang dipilih
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(thickness: 1),
          // --- LIST PENGIRIMAN HARI INI ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Jadwal Penerimaan Kelas (${_myClassName.isNotEmpty ? _myClassName : '...'}), Tgl ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDay)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDayList(),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan daftar pengiriman di hari yang dipilih
  Widget _buildDayList() {
    final deliveries = _getEventsForDay(_selectedDay);
    if (deliveries.isEmpty) {
      return const Center(
        child: Text("Tidak ada jadwal pengiriman untuk sekolah Anda hari ini."),
      );
    }

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final stop = deliveries[index];
        final bool isSchoolReceived =
            stop['status'] == 'received' || stop['status'] == 'issue_reported';
        final bool isClassReceived = stop['already_received'] == true;
        final String menuName =
            stop['schools']['menu_default'] ?? 'Menu Default Belum Diset';
        final int portions = stop['schools']['student_count'] ?? 0;

        return Card(
          color: isClassReceived
              ? Colors.green[50]
              : (isSchoolReceived ? Colors.orange[50] : Colors.white),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              _getStatusIcon(isClassReceived, stop['status']),
              color: isClassReceived
                  ? Colors.green
                  : (isSchoolReceived ? Colors.orange : Colors.indigo),
            ),
            title: Text(
              "Status Sekolah: ${isSchoolReceived ? 'SUDAH DITERIMA' : 'PENDING'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Menu: $menuName (Total: $portions Porsi)\nKelas Anda: ${isClassReceived ? 'Sudah Konfirmasi' : 'BELUM KONFIRMASI'}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isSchoolReceived && !isClassReceived
                ? ElevatedButton(
                    onPressed: () => _showReceptionDialog(stop),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text(
                      "Konfirmasi",
                      style: TextStyle(color: Colors.white),
                    ),
                  )
                : (isClassReceived
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : null),
          ),
        );
      },
    );
  }
}
