import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../services/route_service.dart';
import '../../../models/route_model.dart';
import 'create_route_screen.dart';

class RouteCalendarScreen extends StatefulWidget {
  const RouteCalendarScreen({super.key});

  @override
  State<RouteCalendarScreen> createState() => _RouteCalendarScreenState();
}

class _RouteCalendarScreenState extends State<RouteCalendarScreen> {
  final RouteService _service = RouteService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  Map<DateTime, List<DeliveryRoute>> _routes = {};

  @override
  void initState() {
    super.initState();
    _fetchRoutes();
  }

  Future<void> _fetchRoutes() async {
    try {
      final data = await _service.getRoutesByMonth(_focusedDay);
      Map<DateTime, List<DeliveryRoute>> newMap = {};
      for (var r in data) {
        final d = DateTime.parse(r.date);
        final k = DateTime(d.year, d.month, d.day);
        if (newMap[k] == null) newMap[k] = [];
        newMap[k]!.add(r);
      }
      setState(() => _routes = newMap);
    } catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kalender Pengiriman"), backgroundColor: Colors.orange[800]),
      body: Column(
        children: [
          TableCalendar<DeliveryRoute>(
            firstDay: DateTime(2024), lastDay: DateTime(2030),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            eventLoader: (d) => _routes[DateTime(d.year, d.month, d.day)] ?? [],
            onDaySelected: (sel, foc) {
              setState(() { _selectedDay = sel; _focusedDay = foc; });
            },
            onPageChanged: (foc) { _focusedDay = foc; _fetchRoutes(); },
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: (_routes[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)] ?? []).length,
              itemBuilder: (ctx, i) {
                final route = _routes[DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day)]![i];
                return ListTile(
                  leading: const Icon(Icons.local_shipping, color: Colors.blue),
                  title: Text(route.vehiclePlate ?? '-'),
                  subtitle: Text("Kurir: ${route.courierName}"),
                  trailing: Text(route.status.toUpperCase()),
                );
              },
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRouteScreen())).then((_) => _fetchRoutes()),
      ),
    );
  }
}