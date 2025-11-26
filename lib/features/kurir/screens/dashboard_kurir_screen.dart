import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; 
import 'package:table_calendar/table_calendar.dart'; 

import '../../admin_sppg/services/route_service.dart';
import '../../autentikasi/screens/login_screen.dart';
import '../../../models/route_model.dart';
import 'route_detail_screen.dart';
import '../../../core/screens/profile_screen.dart';

class DashboardKurirScreen extends StatefulWidget {
  const DashboardKurirScreen({super.key});

  @override
  State<DashboardKurirScreen> createState() => _DashboardKurirScreenState();
}

class _DashboardKurirScreenState extends State<DashboardKurirScreen> {
  final RouteService _routeService = RouteService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  
  // Format Kalender Default
  CalendarFormat _calendarFormat = CalendarFormat.month; 
  
  Map<DateTime, List<DeliveryRoute>> _routes = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    setState(() => _isLoading = true);
    try {
      final data = await _routeService.getRoutesByMonth(_focusedDay);
      
      Map<DateTime, List<DeliveryRoute>> newMap = {};
      for (var route in data) {
        final date = DateTime.parse(route.date);
        final dateKey = DateTime(date.year, date.month, date.day);
        
        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(route);
      }

      if (mounted) {
        setState(() {
          _routes = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<DeliveryRoute> _getRoutesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _routes[dateKey] ?? [];
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Pengiriman"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- HEADER CUSTOM: DROPDOWN FORMAT ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Tampilan Kalender:", style: TextStyle(fontWeight: FontWeight.bold)),
                
                // DROPDOWN MENU
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<CalendarFormat>(
                      value: _calendarFormat,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.blue),
                      items: const [
                        DropdownMenuItem(
                          value: CalendarFormat.month, 
                          child: Text("Bulan (Full)"),
                        ),
                        DropdownMenuItem(
                          value: CalendarFormat.twoWeeks, 
                          child: Text("2 Minggu"),
                        ),
                        DropdownMenuItem(
                          value: CalendarFormat.week, 
                          child: Text("1 Minggu"),
                        ),
                      ],
                      onChanged: (format) {
                        if (format != null) {
                          setState(() {
                            _calendarFormat = format;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // --- KALENDER ---
          TableCalendar<DeliveryRoute>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            
            // Gunakan variable state yang diubah oleh Dropdown
            calendarFormat: _calendarFormat, 
            
            // Matikan tombol format bawaan karena kita sudah punya dropdown
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, 
              titleCentered: true,
            ),
            
            eventLoader: _getRoutesForDay,
            
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _fetchRoutes(); 
            },
            
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            ),
          ),
          
          const Divider(thickness: 1, height: 1),
          
          // --- LIST RUTE HARI INI ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildDayList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayList() {
    final routes = _getRoutesForDay(_selectedDay);

    if (routes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 10),
            Text(
              "Tidak ada pengiriman tgl ${DateFormat('d MMM').format(_selectedDay)}",
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const Icon(Icons.local_shipping, color: Colors.blue, size: 32),
            title: Text(
              "Armada: ${route.vehiclePlate ?? '-'}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("Status: ${route.status.toUpperCase()}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => RouteDetailScreen(route: route)),
              ).then((val) { 
                _fetchRoutes();
              });
            },
          ),
        );
      },
    );
  }
}