import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../shared/services/request_service.dart';
import 'dart:convert';

class CoordinatorRequestScreen extends StatefulWidget {
  const CoordinatorRequestScreen({super.key});

  @override
  State<CoordinatorRequestScreen> createState() =>
      _CoordinatorRequestScreenState();
}

// Helper array for day names
const List<String> _daysCo = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

class _CoordinatorRequestScreenState extends State<CoordinatorRequestScreen> {
  final RequestService _service = RequestService();
  final _notesController = TextEditingController();

  String _selectedType = 'Perubahan Jadwal';
  bool _isLoading = false;
  bool _isInitLoading = true;

  // --- DATA ---
  List<Map<String, dynamic>> _availableMenus = [];
  Map<String, dynamic>?
  _schoolData; // School Data (Tolerance, Student Count, etc)

  // --- FORM STATE ---
  // A. Jadwal Range/Custom Schedule
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));

  // Custom schedule map for the selected date range: {DayName: TimeOfDay?}
  Map<String, TimeOfDay?> _customDeliveryTimes = {
    for (var day in _daysCo) day: null,
  };

  // B. Menu
  List<String?> _selectedMenuIds = [null, null, null];

  // C. Porsi
  final TextEditingController _portionController = TextEditingController();

  // D. Toleransi (Can be changed in request)
  final TextEditingController _toleranceController = TextEditingController(
    text: '45',
  );

  // E. Deadline (Can be changed in request)
  TimeOfDay? _deadlineTime;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _service.getSppgMenus(),
        _service.getMySchoolDetails(),
      ]);

      _availableMenus = results[0] as List<Map<String, dynamic>>;
      _schoolData = results[1] as Map<String, dynamic>;

      // PRE-FILL DATA
      if (_schoolData != null) {
        // 1. Porsi, Tolerance, Deadline
        _portionController.text = (_schoolData!['student_count'] ?? 0)
            .toString();
        _toleranceController.text = (_schoolData!['tolerance_minutes'] ?? 45)
            .toString();

        // 2. Deadline Time - Try parsing old single time format or setting default
        final dlStr = _schoolData!['deadline_time'] as String;
        try {
          // Try to parse as single time format (fallback for old schools)
          final parts = dlStr.split(':');
          _deadlineTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        } catch (_) {
          // If parsing fails (it's likely the JSON schedule string), use a default time
          _deadlineTime = const TimeOfDay(hour: 12, minute: 0);
        }

        // 3. Menu Default Parsing (Same as before)
        String defaultMenuStr = _schoolData!['menu_default'] ?? "";
        if (defaultMenuStr.isNotEmpty) {
          final names = defaultMenuStr.split(',').map((e) => e.trim()).toList();
          List<String?> ids = [];
          for (var name in names) {
            final match = _availableMenus.firstWhereOrNull(
              (m) => m['name'] == name,
            );
            if (match != null) ids.add(match['id']);
          }
          while (ids.length < 3) ids.add(null);
          if (ids.length > 5) ids = ids.sublist(0, 5);
          _selectedMenuIds = ids;
        }
      }

      // Initialize custom delivery times with the default deadline (for easy selection)
      _customDeliveryTimes = {for (var day in _daysCo) day: _deadlineTime};

      setState(() => _isInitLoading = false);
    } catch (e) {
      setState(() => _isInitLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error init: $e")));
    }
  }

  // Helper to get days in between
  List<DateTime> getDaysInBetween(DateTime startDate, DateTime endDate) {
    List<DateTime> days = [];
    for (int i = 0; i <= endDate.difference(startDate).inDays; i++) {
      days.add(startDate.add(Duration(days: i)));
    }
    return days;
  }

  // Convert TimeOfDay to Expected Arrival Time using Tolerance
  String _calculateArrivalTime(TimeOfDay deadline, int toleranceMinutes) {
    // Convert deadline to DateTime today
    final now = DateTime.now();
    final deadlineDt = DateTime(
      now.year,
      now.month,
      now.day,
      deadline.hour,
      deadline.minute,
    );

    final arrival = deadlineDt.subtract(Duration(minutes: toleranceMinutes));

    // Check for negative time (if deadline is too early or tolerance too high)
    if (arrival.isBefore(DateTime(now.year, now.month, now.day))) {
      return "00:00 (Error)";
    }

    return DateFormat('HH:mm').format(arrival);
  }

  // --- FUNGSI SUBMIT UTAMA ---
  Future<void> _submit() async {
    setState(() => _isLoading = true);

    List<RequestDetail> details = [];
    String? error;

    if (_selectedType == 'Perubahan Jadwal') {
      // 1. Validate schedule is set for selected days
      final activeDays = _customDeliveryTimes.entries.where(
        (e) => e.value != null,
      );
      if (activeDays.isEmpty) {
        error = "Pilih minimal 1 hari dengan jadwal baru.";
      } else {
        // 2. Serialize the change request: Date Range + Schedule JSON + Tolerance + Deadline
        final scheduleJson = jsonEncode({
          'range': {
            'start': DateFormat('yyyy-MM-dd').format(_startDate),
            'end': DateFormat('yyyy-MM-dd').format(_endDate),
          },
          'schedule': activeDays
              .map((e) => {'day': e.key, 'time': e.value!.format(context)})
              .toList(),
          'tolerance': int.tryParse(_toleranceController.text) ?? 45,
          'deadline': _deadlineTime?.format(context) ?? '12:00',
        });

        details.add(
          RequestDetail(
            menuId: 'dummy',
            menuName: 'Schedule Change Request',
            proposedMenuNames:
                scheduleJson, // Store JSON in this field for transfer
          ),
        );
      }
    }
    // ... (Perubahan Menu & Tambah/Kurang Porsi logic remains similar to previous version,
    // ensuring we use the updated RequestDetail structure)
    else if (_selectedType == 'Perubahan Menu') {
      List<String> names = [];
      for (var id in _selectedMenuIds) {
        if (id != null) {
          final m = _availableMenus.firstWhere((e) => e['id'] == id);
          names.add(m['name']);
        }
      }
      if (names.length < 3)
        error = "Pilih minimal 3 menu.";
      else {
        details.add(
          RequestDetail(
            menuId: 'dummy',
            menuName: 'Menu Set Change',
            proposedMenuNames: names.join(', '),
          ),
        );
      }
    } else if (_selectedType == 'Tambah/Kurang Porsi') {
      if (_portionController.text.isEmpty)
        error = "Isi jumlah porsi.";
      else {
        details.add(
          RequestDetail(
            menuId: 'dummy',
            menuName: 'Portion Change',
            newQuantity: int.parse(_portionController.text),
          ),
        );
      }
    }

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _service.submitStructuredRequest(
        type: _selectedType,
        notes: _notesController.text,
        details: details,
      );
      _notesController.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Pengajuan Terkirim!")));
      setState(() {});
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pengajuan Perubahan"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Form Pengajuan",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 15),

                            // Dropdown Type
                            DropdownButtonFormField<String>(
                              value: _selectedType,
                              decoration: const InputDecoration(
                                labelText: "Jenis Pengajuan",
                                border: OutlineInputBorder(),
                              ),
                              items:
                                  [
                                        'Perubahan Jadwal',
                                        'Perubahan Menu',
                                        'Tambah/Kurang Porsi',
                                      ]
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e,
                                          child: Text(e),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedType = val!;
                                  // Reset times when switching type to avoid confusion
                                  _customDeliveryTimes = {
                                    for (var day in _daysCo) day: _deadlineTime,
                                  };
                                });
                              },
                            ),
                            const SizedBox(height: 15),

                            // DYNAMIC FORM
                            _buildDynamicForm(context),

                            const SizedBox(height: 15),
                            TextField(
                              controller: _notesController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: "Catatan Tambahan",
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.teal,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.all(15),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : const Text("KIRIM PENGAJUAN"),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(thickness: 5, color: Colors.grey),
                  const Padding(
                    padding: EdgeInsets.all(10),
                    child: Text(
                      "Riwayat Pengajuan",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  Widget _buildDynamicForm(BuildContext context) {
    if (_selectedType == 'Perubahan Jadwal') {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Pilih Rentang Tanggal:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildDateInput(
                    "Mulai",
                    _startDate,
                    (d) => setState(() => _startDate = d),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildDateInput(
                    "Sampai",
                    _endDate,
                    (d) => setState(() => _endDate = d),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            // Deadline and Tolerance Inputs (for the request)
            const Text(
              "Waktu dan Toleransi yang Diusulkan:",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Expanded(
                  child: _buildTimeInput("Deadline", _deadlineTime, (t) {
                    setState(() {
                      _deadlineTime = t;
                      // Auto-apply this deadline to all selected days
                      _customDeliveryTimes = {for (var day in _daysCo) day: t};
                    });
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _toleranceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Toleransi (Min)",
                      hintText: "45",
                    ),
                    validator: (v) => v!.isEmpty ? "Wajib" : null,
                  ),
                ),
              ],
            ),
            const Divider(height: 25),

            const Text(
              "Ubah Jam Per Hari (Mon-Sat):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ..._daysCo.map((day) {
              final currentTime = _customDeliveryTimes[day];
              final expectedArrival = currentTime != null
                  ? _calculateArrivalTime(
                      currentTime,
                      int.tryParse(_toleranceController.text) ?? 45,
                    )
                  : "--:--";

              return ListTile(
                title: Text(
                  day,
                  style: TextStyle(
                    color: currentTime != null ? Colors.teal : Colors.grey,
                  ),
                ),
                subtitle: Text("Expected Arrival: $expectedArrival"),
                trailing: Text(currentTime?.format(context) ?? 'OFF'),
                onTap: () async {
                  final TimeOfDay? picked = await showTimePicker(
                    context: context,
                    initialTime:
                        currentTime ??
                        _deadlineTime ??
                        const TimeOfDay(hour: 12, minute: 0),
                  );
                  setState(() => _customDeliveryTimes[day] = picked);
                },
              );
            }).toList(),
          ],
        ),
      );
    } else if (_selectedType == 'Tambah/Kurang Porsi') {
      return TextFormField(
        controller: _portionController,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: "Jumlah Porsi Baru",
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.people),
        ),
      );
    } else {
      // MENU SET DROPDOWNS
      return Column(
        children: [
          const Text(
            "Atur Menu Set (Min 3):",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          ...List.generate(_selectedMenuIds.length, (index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Menu #${index + 1}",
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 0,
                  ),
                ),
                value: _selectedMenuIds[index],
                items: _availableMenus
                    .map(
                      (m) => DropdownMenuItem(
                        value: m['id'] as String,
                        child: Text(m['name']),
                      ),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedMenuIds[index] = val),
              ),
            );
          }),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedMenuIds.length < 5)
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  onPressed: () => setState(() => _selectedMenuIds.add(null)),
                ),
              if (_selectedMenuIds.length > 3)
                IconButton(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  onPressed: () =>
                      setState(() => _selectedMenuIds.removeLast()),
                ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildDateInput(
    String label,
    DateTime date,
    Function(DateTime) onSelect,
  ) {
    return InkWell(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime.now().subtract(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null && picked != date) {
          onSelect(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(DateFormat('d MMM yyyy').format(date)),
      ),
    );
  }

  Widget _buildTimeInput(
    String label,
    TimeOfDay? time,
    Function(TimeOfDay) onSelect,
  ) {
    return InkWell(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time ?? const TimeOfDay(hour: 12, minute: 0),
        );
        if (picked != null && picked != time) {
          onSelect(picked);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        child: Text(time?.format(context) ?? 'Pilih Jam'),
      ),
    );
  }

  // --- WIDGET HISTORY (Same as before) ---
  Widget _buildHistoryList() {
    return FutureBuilder<List<ChangeRequestModel>>(
      future: _service.getMyRequests(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          itemBuilder: (ctx, i) {
            final item = snapshot.data![i];
            Color color = item.status == 'pending'
                ? Colors.orange
                : (item.status == 'approved' ? Colors.green : Colors.red);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(
                  item.type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "${item.requestDate}\nStatus: ${item.status.toUpperCase()}\nRespon: ${item.adminResponse ?? '-'}",
                ),
                trailing: Icon(Icons.circle, color: color, size: 15),
              ),
            );
          },
        );
      },
    );
  }
}
