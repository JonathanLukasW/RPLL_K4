import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../models/production_schedule_model.dart';
import '../../../models/menu_model.dart';
import '../services/schedule_service.dart';
import '../services/menu_service.dart';

class ProductionCalendarScreen extends StatefulWidget {
  const ProductionCalendarScreen({super.key});

  @override
  State<ProductionCalendarScreen> createState() =>
      _ProductionCalendarScreenState();
}

class _ProductionCalendarScreenState extends State<ProductionCalendarScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final MenuService _menuService = MenuService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<ProductionSchedule>> _schedules = {};
  List<Menu> _availableMenus = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final menus = await _menuService.getMyMenus();
      _availableMenus = menus;
      _fetchSchedules();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      // THIS NOW CALLS THE CORRECTLY DEFINED METHOD
      final data = await _scheduleService.getSchedulesByMonth(_focusedDay);

      Map<DateTime, List<ProductionSchedule>> newMap = {};
      for (var item in data) {
        final dateKey = DateTime(
          item.date.year,
          item.date.month,
          item.date.day,
        );
        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(item);
      }
      if (mounted) {
        setState(() {
          _schedules = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<ProductionSchedule> _getSchedulesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _schedules[dateKey] ?? [];
  }

  // --- DIALOG CRUD (TAMBAH KHUSUS / EDIT) ---
  void _showScheduleDialog({ProductionSchedule? scheduleToEdit}) {
    String? selectedMenuId = scheduleToEdit?.menuId;
    final portionController = TextEditingController(
      text: scheduleToEdit?.totalPortions.toString() ?? "100",
    );
    final noteController = TextEditingController(
      text: scheduleToEdit?.notes ?? "Tambahan Khusus",
    );

    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    if (scheduleToEdit?.targetFinishTime != null) {
      final parts = scheduleToEdit!.targetFinishTime!.split(':');
      selectedTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final currentMenu = _availableMenus.isNotEmpty
              ? _availableMenus.firstWhere(
                  (m) => m.id == selectedMenuId,
                  orElse: () => _availableMenus.first,
                )
              : null;

          String startTimeString = "--:--";
          if (currentMenu != null) {
            startTimeString = _scheduleService
                .calculateStartTime(
                  selectedTime,
                  selectedMenuId != null
                      ? currentMenu.cookingDurationMinutes
                      : 0,
                )
                .substring(0, 5);
          }

          return AlertDialog(
            title: Text(
              scheduleToEdit == null ? "Jadwal Khusus" : "Edit Jadwal",
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scheduleToEdit == null)
                    const Text(
                      "Gunakan ini HANYA untuk pesanan tambahan di luar rute rutin.",
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Pilih Menu",
                      border: OutlineInputBorder(),
                    ),
                    value: selectedMenuId,
                    items: _availableMenus
                        .map(
                          (m) => DropdownMenuItem(
                            value: m.id,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedMenuId = val),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: portionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Jumlah Porsi",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),

                  ListTile(
                    title: const Text("Target Selesai Jam:"),
                    subtitle: Text(
                      selectedTime.format(context),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: selectedTime,
                      );
                      if (t != null) setDialogState(() => selectedTime = t);
                    },
                  ),

                  if (selectedMenuId != null && currentMenu != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.blue[50],
                        child: Text(
                          "MULAI MASAK: $startTimeString (Durasi: ${currentMenu.cookingDurationMinutes} mnt)",
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: "Catatan",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (selectedMenuId == null) return;
                  Navigator.pop(ctx);
                  final menu = _availableMenus.firstWhere(
                    (m) => m.id == selectedMenuId,
                  );

                  if (scheduleToEdit == null) {
                    // TAMBAH KHUSUS
                    await _scheduleService.addSchedule(
                      date: _selectedDay!,
                      menuId: selectedMenuId!,
                      portions: int.parse(portionController.text),
                      deliverTime: selectedTime,
                      cookingDuration: menu.cookingDurationMinutes,
                      notes: noteController.text,
                    );
                  } else {
                    // EDIT JADWAL (Rutin/Khusus)
                    await _scheduleService.updateSchedule(
                      id: scheduleToEdit.id,
                      menuId: selectedMenuId!,
                      portions: int.parse(portionController.text),
                      deliverTime: selectedTime,
                      cookingDuration: menu.cookingDurationMinutes,
                      notes: noteController.text,
                    );
                  }
                  _fetchSchedules();
                },
                child: const Text("Simpan"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Jadwal?"),
        content: const Text("Jadwal produksi ini akan dihapus."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _scheduleService.deleteSchedule(id);
              _fetchSchedules();
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kalender Produksi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          TableCalendar<ProductionSchedule>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            eventLoader: _getSchedulesForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _fetchSchedules();
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(thickness: 1),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Jadwal Masak Hari Ini:",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDayList(),
          ),
        ],
      ),
      // Tombol Khusus
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        label: const Text("Jadwal Khusus"),
        icon: const Icon(Icons.add_alert),
        onPressed: () => _showScheduleDialog(),
      ),
    );
  }

  Widget _buildDayList() {
    final events = _getSchedulesForDay(_selectedDay!);
    if (events.isEmpty)
      return const Center(child: Text("Tidak ada jadwal masak."));

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final schedule = events[index];

        // Check if the related route is already ACTIVE/COMPLETED to prevent accidental deletion!
        // NOTE: For now, we assume deleting the schedule is allowed by the admin, but a safer check
        // would involve querying the associated route status first!
        final isDeletable =
            true; // Simplified for now. Should check related route status.

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: const Icon(Icons.restaurant, color: Colors.orange),
            ),
            title: Text(
              schedule.menuName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Target: ${schedule.totalPortions} Porsi"),
                Text(
                  "Masak: ${schedule.startCookingTime?.substring(0, 5)} -> Selesai: ${schedule.targetFinishTime?.substring(0, 5)}",
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (schedule.notes != null)
                  Text(
                    schedule.notes!,
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            // REPLACING POPUP MENU WITH DIRECT ACTION BUTTONS (Edit and Delete)
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // EDIT Button
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showScheduleDialog(
                    scheduleToEdit: schedule,
                  ), // Mode Edit
                ),
                // DELETE Button
                if (isDeletable) // Show delete button if allowed
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _confirmDelete(schedule.id),
                  ),
              ],
            ),
            // NOTE: If you want to keep the PopupMenuButton approach, use the one below.
            /*
          trailing: PopupMenuButton(
            onSelected: (value) {
              if (value == 'edit') _showScheduleDialog(scheduleToEdit: schedule);
              if (value == 'delete') _confirmDelete(schedule.id);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text("Edit")),
              const PopupMenuItem(value: 'delete', child: Text("Hapus", style: TextStyle(color: Colors.red))),
            ],
          ),
          */
          ),
        );
      },
    );
  }
}
