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
  State<ProductionCalendarScreen> createState() => _ProductionCalendarScreenState();
}

class _ProductionCalendarScreenState extends State<ProductionCalendarScreen> {
  final ScheduleService _scheduleService = ScheduleService();
  final MenuService _menuService = MenuService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  // Data Jadwal: Map<Tanggal, List<Jadwal>>
  Map<DateTime, List<ProductionSchedule>> _schedules = {};
  List<Menu> _availableMenus = []; // Untuk dropdown saat tambah

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // 1. Ambil Menu (buat dropdown nanti)
      final menus = await _menuService.getMyMenus();
      _availableMenus = menus;

      // 2. Ambil Jadwal
      await _fetchSchedules();
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSchedules() async {
    setState(() => _isLoading = true);
    try {
      final data = await _scheduleService.getSchedulesByMonth(_focusedDay);

      Map<DateTime, List<ProductionSchedule>> newMap = {};
      for (var item in data) {
        // Normalisasi tanggal (hilangkan jam/menit)
        final dateKey = DateTime(item.date.year, item.date.month, item.date.day);
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

  // Helper: Mengambil event/jadwal untuk tanggal tertentu
  List<ProductionSchedule> _getSchedulesForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _schedules[dateKey] ?? [];
  }

  // --- DIALOG TAMBAH / EDIT JADWAL ---
  void _showScheduleDialog({ProductionSchedule? scheduleToEdit}) {
    // Variabel Form
    String? selectedMenuId = scheduleToEdit?.menuId;
    final portionController = TextEditingController(text: scheduleToEdit?.totalPortions.toString() ?? "500");
    final noteController = TextEditingController(text: scheduleToEdit?.notes ?? "");

    // Parsing jam kirim dari data lama (atau default jam 11:00)
    TimeOfDay selectedTime = const TimeOfDay(hour: 11, minute: 0);
    if (scheduleToEdit?.targetFinishTime != null) {
      final parts = scheduleToEdit!.targetFinishTime!.split(':');
      selectedTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Cari object menu yang sedang dipilih untuk hitung durasi
          final currentMenu = _availableMenus.isNotEmpty
              ? _availableMenus.firstWhere(
                  (m) => m.id == selectedMenuId,
                  orElse: () => _availableMenus.first)
              : null;

          // Hitung Mundur Realtime untuk Preview
          String startTimeString = "--:--";
          if (currentMenu != null) {
            startTimeString = _scheduleService
                .calculateStartTime(
                    selectedTime, selectedMenuId != null ? currentMenu.cookingDurationMinutes : 0)
                .substring(0, 5);
          }

          return AlertDialog(
            title: Text(scheduleToEdit == null
                ? "Jadwal ${_selectedDay!.day}/${_selectedDay!.month}"
                : "Edit Jadwal"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_availableMenus.isEmpty)
                    const Text("Belum ada menu. Tambah menu dulu di Manajemen Menu.",
                        style: TextStyle(color: Colors.red)),

                  if (_availableMenus.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Pilih Menu", border: OutlineInputBorder()),
                      value: selectedMenuId,
                      items: _availableMenus
                          .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                          .toList(),
                      onChanged: (val) => setDialogState(() => selectedMenuId = val),
                    ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: portionController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Jumlah Porsi", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),

                  ListTile(
                    title: const Text("Mobil Berangkat Jam:"),
                    subtitle: Text(selectedTime.format(context),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.access_time),
                    tileColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: selectedTime);
                      if (t != null) setDialogState(() => selectedTime = t);
                    },
                  ),

                  // Info Hitung Mundur
                  if (selectedMenuId != null && currentMenu != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue)),
                        child: Column(
                          children: [
                            Text("Durasi Masak: ${currentMenu.cookingDurationMinutes} Menit"),
                            const Divider(),
                            const Text("JADWAL DAPUR:",
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                            Text("MULAI MASAK: $startTimeString",
                                style: const TextStyle(
                                    color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                            const Text("(Termasuk 30 menit loading)",
                                style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                        labelText: "Catatan (Opsional)", border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
              ElevatedButton(
                onPressed: () async {
                  if (selectedMenuId == null) {
                    return;
                  }

                  Navigator.pop(ctx);
                  final menu = _availableMenus.firstWhere((m) => m.id == selectedMenuId);

                  if (scheduleToEdit == null) {
                    // TAMBAH
                    await _scheduleService.addSchedule(
                      date: _selectedDay!,
                      menuId: selectedMenuId!,
                      portions: int.parse(portionController.text),
                      deliverTime: selectedTime,
                      cookingDuration: menu.cookingDurationMinutes,
                      notes: noteController.text,
                    );
                  } else {
                    // UPDATE
                    await _scheduleService.updateSchedule(
                      id: scheduleToEdit.id,
                      menuId: selectedMenuId!,
                      portions: int.parse(portionController.text),
                      deliverTime: selectedTime,
                      cookingDuration: menu.cookingDurationMinutes,
                      notes: noteController.text,
                    );
                  }
                  _fetchSchedules(); // Refresh
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], foregroundColor: Colors.white),
                child: const Text("Simpan"),
              )
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
        content: const Text("Data produksi ini akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
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
              markerDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            ),
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
          ),
          const Divider(thickness: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDayList(),
          ),
        ],
      ),
      // Tombol Tambah di Pojok Bawah
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        label: const Text("Tambah Jadwal"),
        icon: const Icon(Icons.add),
        onPressed: () => _showScheduleDialog(), // Memanggil fungsi tambah tanpa parameter
      ),
    );
  }

  Widget _buildDayList() {
    final events = _getSchedulesForDay(_selectedDay!);

    if (events.isEmpty) {
      return Center(
        child: Text(
          "Tidak ada jadwal masak tgl ${DateFormat('d MMM').format(_selectedDay!)}",
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final schedule = events[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.orange[100],
              child: const Icon(Icons.restaurant, color: Colors.orange),
            ),
            title: Text(schedule.menuName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Target: ${schedule.totalPortions} Porsi"),
                Text(
                    "Mulai Masak: ${schedule.startCookingTime?.substring(0, 5)} -> Selesai: ${schedule.targetFinishTime?.substring(0, 5)}",
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                if (schedule.notes != null && schedule.notes!.isNotEmpty)
                  Text("Note: ${schedule.notes}", style: const TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showScheduleDialog(scheduleToEdit: schedule), // Mode Edit
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDelete(schedule.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}