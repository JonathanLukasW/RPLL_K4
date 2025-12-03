// === FILE: lib/features/admin_sppg/screens/route_calendar_screen.dart ===

import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../services/school_service.dart';
import '../../../models/school_model.dart';

// Mapping for days (Mon-Sat)
const List<String> _days = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

class RouteCalendarScreen extends StatefulWidget {
  const RouteCalendarScreen({super.key});

  @override
  State<RouteCalendarScreen> createState() => _RouteCalendarScreenState();
}

class _RouteCalendarScreenState extends State<RouteCalendarScreen> {
  final SchoolService _schoolService = SchoolService();

  // Define today at midnight for accurate comparison
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  CalendarFormat _calendarFormat = CalendarFormat.month;
  bool _isLoading = true;

  Map<DateTime, List<Map<String, String>>> _dailySchedules = {};
  List<School>? _allSchools;

  @override
  void initState() {
    super.initState();
    // Initialize selected day to today
    _selectedDay = _today;
    _focusedDay = _today;
    _fetchSchoolSchedules();
  }

  String _mapDayToLocal(int day) {
    switch (day) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      default:
        return 'Minggu';
    }
  }

  Future<void> _fetchSchoolSchedules() async {
    setState(() => _isLoading = true);
    try {
      _allSchools = await _schoolService.getMySchools();

      // VITAL CHANGE: Define the 30-day window (Start from today, end 30 days later)
      final start = _today;
      final end = _today.add(const Duration(days: 30));

      Map<DateTime, List<Map<String, String>>> newSchedules = {};

      for (
        var day = start;
        day.isBefore(end.add(const Duration(days: 1)));
        day = day.add(const Duration(days: 1))
      ) {
        final localDayName = _mapDayToLocal(day.weekday);
        final dateKey = DateTime(day.year, day.month, day.day);

        List<Map<String, String>> dailyList = [];

        for (var school in _allSchools!) {
          try {
            // NOTE: We assume the JSON string is in school.deadlineTime
            final Map<String, dynamic> scheduleMap = jsonDecode(
              school.deadlineTime!,
            );

            if (scheduleMap.containsKey(localDayName)) {
              final deadline = scheduleMap[localDayName]; // e.g., "10:00:00"

              // Calculate Expected Arrival (Deadline - Tolerance)
              final tolerance = school.toleranceMinutes;
              final deadlineParts = deadline.split(':');
              final deadlineTime = TimeOfDay(
                hour: int.parse(deadlineParts[0]),
                minute: int.parse(deadlineParts[1]),
              );

              final arrivalDt = DateTime(
                day.year,
                day.month,
                day.day,
                deadlineTime.hour,
                deadlineTime.minute,
              ).subtract(Duration(minutes: tolerance));

              dailyList.add({
                'schoolName': school.name,
                'deadline': deadline,
                'arrival': DateFormat('HH:mm:ss').format(arrivalDt),
                'isHighRisk': school.isHighRisk.toString(),
              });
            }
          } catch (_) {
            // Ignore schools with malformed or missing schedule JSON
          }
        }

        // --- SORTING: Sort the daily list by Deadline Time (HH:mm:ss) ---
        dailyList.sort((a, b) => a['deadline']!.compareTo(b['deadline']!));

        newSchedules[dateKey] = dailyList;
      }

      if (mounted) {
        setState(() {
          _dailySchedules = newSchedules;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal load jadwal rutin: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, String>> _getEventsForDay(DateTime day) {
    // Access schedule map using the passed 'day' object (at midnight)
    final dateKey = DateTime(day.year, day.month, day.day);
    return _dailySchedules[dateKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    // Define today at midnight and the end of the 30-day window
    final DateTime calendarStart = _today;
    final DateTime calendarEnd = _today.add(const Duration(days: 30));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal Pengiriman Rutin (30 Hari)"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                TableCalendar(
                  // VITAL FIX 1: Set firstDay to today's date (calendarStart)
                  firstDay: calendarStart,
                  // VITAL FIX 2: Set lastDay to 30 days from today
                  lastDay: calendarEnd,
                  // VITAL FIX 3: Ensure focusedDay starts at calendarStart if it somehow drifts backwards
                  focusedDay: _focusedDay.isBefore(calendarStart)
                      ? calendarStart
                      : _focusedDay,

                  // VITAL FIX: Use selectedDayPredicate to highlight selected day
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  calendarFormat: _calendarFormat,
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  calendarStyle: const CalendarStyle(
                    markerDecoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    // Highlight days outside the 30-day range differently (or disable)
                    disabledDecoration: BoxDecoration(),
                  ),
                  eventLoader: _getEventsForDay,
                  onDaySelected: (selectedDay, focusedDay) {
                    // Only allow selection within the 30-day window
                    if (selectedDay.isBefore(calendarStart) ||
                        selectedDay.isAfter(calendarEnd))
                      return;

                    if (!isSameDay(_selectedDay, selectedDay)) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    }
                  },
                  onPageChanged: (focusedDay) {
                    // VITAL FIX 4: Prevent focusedDay from going before calendarStart
                    if (focusedDay.isBefore(calendarStart)) {
                      _focusedDay = calendarStart;
                    } else {
                      _focusedDay = focusedDay;
                    }
                    _fetchSchoolSchedules();

                    // We only load data for a tight window now, so reloading monthly data is less critical, but kept for robustness if month changes significantly.
                    // _fetchSchoolSchedules();
                  },
                  onFormatChanged: (format) {
                    setState(() => _calendarFormat = format);
                  },
                ),
                const Divider(thickness: 1),
                // VITAL FIX: Display list for the selected day (_selectedDay)
                Expanded(
                  child: ListView(
                    children: _getEventsForDay(_selectedDay).map((schedule) {
                      final isHighRisk = schedule['isHighRisk'] == 'true';

                      // Display friendly time format (HH:mm)
                      final deadlineDisplay = schedule['deadline']!.substring(
                        0,
                        5,
                      );
                      final arrivalDisplay = schedule['arrival']!.substring(
                        0,
                        5,
                      );

                      return Card(
                        color: isHighRisk ? Colors.red[50] : Colors.white,
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: Icon(
                            Icons.school,
                            color: isHighRisk ? Colors.red : Colors.indigo,
                          ),
                          title: Text(
                            schedule['schoolName']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Deadline Konsumsi: $deadlineDisplay"),
                              Text(
                                "Est. Tiba Kurir: $arrivalDisplay",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: isHighRisk
                              ? const Text(
                                  'HIGH RISK',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
    );
  }
}
