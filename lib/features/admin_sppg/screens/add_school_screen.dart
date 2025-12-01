import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';
import 'dart:convert'; // Need this for JSON encoding/decoding

import '../../pengawas/screens/location_picker_screen.dart';
import '../services/school_service.dart';
import '../services/menu_service.dart';
import '../../../models/school_model.dart';
import '../../../models/menu_model.dart';

// Mapping for days (Mon-Sat)
const List<String> _days = [
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
];

class AddSchoolScreen extends StatefulWidget {
  final School? schoolToEdit;

  const AddSchoolScreen({super.key, this.schoolToEdit});

  @override
  State<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends State<AddSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final MenuService _menuService = MenuService();

  // --- Controllers ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _studentCountController = TextEditingController();
  final TextEditingController _serviceTimeController = TextEditingController(
    text: "10",
  );
  final TextEditingController _toleranceController = TextEditingController(
    text: "45",
  );

  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  // --- State Variables ---
  List<Menu> _availableMenus = [];
  List<String?> _selectedMenuIds = [null, null, null];
  bool _isMenuLoading = true;
  bool _isHighRisk = false;
  bool _isSubmitting = false;

  // --- NEW STATE: Weekly Schedule (Mon-Sat TimePicker) ---
  // Store time as TimeOfDay (HH:mm) or null if day is off
  Map<String, TimeOfDay?> _weeklySchedule = {for (var day in _days) day: null};

  // Single time control for 'Apply to All'
  TimeOfDay? _universalTime;

  @override
  void initState() {
    super.initState();
    _fetchMenusAndInitialize();
  }

  // Parses old string data into the new weekly map structure
  Map<String, TimeOfDay?> _parseSchedule(String? jsonString) {
    Map<String, TimeOfDay?> schedule = {for (var day in _days) day: null};
    if (jsonString == null || jsonString.isEmpty) return schedule;

    try {
      final Map<String, dynamic> data = jsonDecode(jsonString);
      data.forEach((key, value) {
        // We check if it's one of our days and a valid time string
        if (_days.contains(key) && value is String && value.length >= 5) {
          final parts = value.split(':');
          if (parts.length >= 2) {
            schedule[key] = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }
        }
      });
    } catch (_) {
      // Failed to parse JSON, returning default empty schedule
    }
    return schedule;
  }

  // NEW: Fetch Menus and Initialize State
  Future<void> _fetchMenusAndInitialize() async {
    try {
      final menus = await _menuService.getMyMenus();
      _availableMenus = menus;

      List<String?> initialSelections = [];

      if (widget.schoolToEdit != null) {
        final s = widget.schoolToEdit!;
        _nameController.text = s.name;
        _addressController.text = s.address ?? '';
        _studentCountController.text = s.studentCount.toString();
        _serviceTimeController.text = s.serviceTimeMinutes.toString();
        _toleranceController.text = s.toleranceMinutes.toString();
        _isHighRisk = s.isHighRisk;

        if (s.latitude != null) _latController.text = s.latitude.toString();
        if (s.longitude != null) _longController.text = s.longitude.toString();

        // --- NEW SCHEDULE INIT LOGIC (CRITICAL FOR EDIT) ---
        // We reuse the deadlineTime field, assuming it's been updated to JSONB/TEXT
        _weeklySchedule = _parseSchedule(s.deadlineTime);

        // PARSING MENU SET (Same as before)
        if (s.menuDefault != null && s.menuDefault!.isNotEmpty) {
          final storedNames = s.menuDefault!
              .split(', ')
              .map((e) => e.trim())
              .toList();
          final List<String?> idsFromNames = storedNames.map((name) {
            return menus.firstWhereOrNull((m) => m.name == name)?.id;
          }).toList();
          initialSelections = idsFromNames
              .whereType<String>()
              .cast<String?>()
              .toList();
          if (initialSelections.length > 5) {
            initialSelections = initialSelections.sublist(0, 5);
          }
        }
      }

      while (initialSelections.length < 3) {
        initialSelections.add(null);
      }

      if (mounted) {
        setState(() {
          _selectedMenuIds = initialSelections;
          _isMenuLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("BASTARD! Gagal tarik data: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isMenuLoading = false);
      }
    }
  }

  // Function to save the full weekly schedule as a JSON string
  String _serializeWeeklySchedule() {
    Map<String, String> data = {};
    _weeklySchedule.forEach((day, time) {
      if (time != null) {
        data[day] =
            "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
      }
    });
    return jsonEncode(data);
  }

  // --- 1. Fungsi Pilih Jam Universal ---
  Future<void> _pickUniversalTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _universalTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _universalTime = picked;
        _weeklySchedule = {for (var day in _days) day: picked};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Waktu diterapkan untuk semua hari!")),
      );
    }
  }

  // --- 2. Fungsi Buka Peta (RESTORED) ---
  Future<void> _openMapPicker() async {
    double initialLat = double.tryParse(_latController.text) ?? -6.9175;
    double initialLong = double.tryParse(_longController.text) ?? 107.6191;

    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLat: initialLat,
          initialLong: initialLong,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _latController.text = result.latitude.toString();
        _longController.text = result.longitude.toString();
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Lokasi Sekolah terpilih!")));
    }
  }

  // --- 3. Submit ke Database ---
  Future<void> _submitForm() async {
    // Check if at least one day is scheduled
    if (_weeklySchedule.values.every((time) => time == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wajib mengatur jadwal minimal 1 hari, dasar bego!"),
        ),
      );
      return;
    }

    final List<String> validMenuIds = _selectedMenuIds
        .whereType<String>()
        .toList();
    if (validMenuIds.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wajib pilih minimal 3 item menu set, dasar bego!"),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        // --- NEW: SCHEDULE SERIALIZATION ---
        final String scheduleJson = _serializeWeeklySchedule();

        // --- REBUILD MENU_DEFAULT STRING ---
        final menuNames = validMenuIds
            .map(
              (id) =>
                  _availableMenus.firstWhereOrNull((m) => m.id == id)?.name ??
                  "Menu Hilang",
            )
            .where((name) => name != "Menu Hilang")
            .toList()
            .join(', ');

        final Map<String, dynamic> data = {
          'name': _nameController.text,
          'address': _addressController.text,
          'student_count': int.parse(_studentCountController.text),
          'service_time_minutes': int.parse(_serviceTimeController.text),
          'is_high_risk': _isHighRisk,
          'gps_lat': double.tryParse(_latController.text),
          'gps_long': double.tryParse(_longController.text),
          'tolerance_minutes': int.parse(_toleranceController.text),
          'menu_default': menuNames,
          // CRITICAL HACK: Store the JSON in the single column meant for Deadline.
          'deadline_time': scheduleJson,
        };

        if (widget.schoolToEdit == null) {
          await SchoolService().createSchool(data);
        } else {
          await SchoolService().updateSchool(widget.schoolToEdit!.id, data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Data Sekolah berhasil ${widget.schoolToEdit == null ? 'ditambahkan' : 'diperbarui'}!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal Simpan: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _studentCountController.dispose();
    _serviceTimeController.dispose();
    _toleranceController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.schoolToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Sekolah" : "Tambah Sekolah"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _isMenuLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- DATA UMUM (UNCHANGED) ---
                    const Text(
                      "Data Umum",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama Lokasi Penerima",
                        prefixIcon: Icon(Icons.school),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _addressController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: "Alamat Lengkap",
                        prefixIcon: Icon(Icons.home),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _studentCountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Jml Penerima",
                              prefixIcon: Icon(Icons.people),
                            ),
                            validator: (v) => v!.isEmpty ? "Wajib" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _serviceTimeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Waktu Service (Menit)",
                              prefixIcon: Icon(Icons.timer),
                            ),
                            validator: (v) => v!.isEmpty ? "Wajib" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const Divider(thickness: 2),

                    // --- BAGIAN JADWAL MINGGUAN (REWRITE) ---
                    const Text(
                      "Jadwal Pengiriman Rutin (Deadline Konsumsi)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Universal Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickUniversalTime,
                        icon: const Icon(Icons.schedule, color: Colors.blue),
                        label: Text(
                          _universalTime != null
                              ? "Apply Jam: ${_universalTime!.format(context)} ke Semua Hari"
                              : "Atur & Terapkan Jam ke Semua Hari",
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),

                    // Daily Time Pickers (Mon-Sat)
                    ..._days.map((day) {
                      final time = _weeklySchedule[day];
                      return Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.calendar_view_day,
                              color: time != null
                                  ? Colors.orange[800]
                                  : Colors.grey,
                            ),
                            title: Text(
                              day,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: time != null
                                    ? Colors.black
                                    : Colors.grey,
                              ),
                            ),
                            subtitle: Text(
                              time != null
                                  ? time.format(context)
                                  : "Tidak ada pengiriman",
                              style: TextStyle(
                                color: time != null
                                    ? Colors.red
                                    : Colors.grey[600],
                              ),
                            ),
                            trailing: IconButton(
                              icon: Icon(
                                time != null ? Icons.close : Icons.access_time,
                              ),
                              onPressed: () async {
                                if (time != null) {
                                  // Clear time
                                  setState(() => _weeklySchedule[day] = null);
                                } else {
                                  // Pick specific time
                                  final TimeOfDay? picked =
                                      await showTimePicker(
                                        context: context,
                                        initialTime:
                                            time ??
                                            _universalTime ??
                                            const TimeOfDay(
                                              hour: 12,
                                              minute: 0,
                                            ),
                                      );
                                  if (picked != null) {
                                    setState(
                                      () => _weeklySchedule[day] = picked,
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    }).toList(),

                    const SizedBox(height: 25),
                    const Divider(thickness: 2),

                    // --- BAGIAN VRP CONSTRAINTS (TOLERANCE) ---
                    const Text(
                      "Toleransi Pengiriman",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),

                    TextFormField(
                      controller: _toleranceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Toleransi Awal (Menit)",
                        hintText: "45",
                        prefixIcon: Icon(Icons.fast_forward),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib" : null,
                    ),
                    const SizedBox(height: 15),

                    // --- MENU SET (UNCHANGED LOGIC) ---
                    const Text(
                      "Menu Default Set (Min 3, Max 5)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),

                    if (_availableMenus.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: Colors.yellow[100],
                        child: const Text(
                          "TIDAK ADA MENU!.",
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),

                    ...List.generate(_selectedMenuIds.length, (index) {
                      final availableItems = _availableMenus.map((menu) {
                        return DropdownMenuItem<String>(
                          value: menu.id,
                          enabled: !_selectedMenuIds.any(
                            (id) =>
                                id == menu.id && id != _selectedMenuIds[index],
                          ),
                          child: Text("${menu.name} (${menu.category})"),
                        );
                      }).toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Menu #${index + 1}",
                            prefixIcon: const Icon(Icons.restaurant_menu),
                          ),
                          value: _selectedMenuIds[index],
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text("--- Pilih Menu ---"),
                            ),
                            ...availableItems,
                          ],
                          onChanged: (String? newValue) => setState(
                            () => _selectedMenuIds[index] = newValue,
                          ),
                          validator: (v) => (index < 3 && v == null)
                              ? "Menu #${index + 1} wajib diisi."
                              : null,
                        ),
                      );
                    }),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_selectedMenuIds.length < 5)
                          TextButton.icon(
                            icon: const Icon(
                              Icons.add_circle,
                              color: Colors.blue,
                            ),
                            label: const Text("Tambah Menu Set"),
                            onPressed: () =>
                                setState(() => _selectedMenuIds.add(null)),
                          ),
                        if (_selectedMenuIds.length > 3)
                          TextButton.icon(
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                            ),
                            label: const Text("Hapus Menu Set"),
                            onPressed: () =>
                                setState(() => _selectedMenuIds.removeLast()),
                          ),
                      ],
                    ),

                    const Divider(thickness: 2),
                    const SizedBox(height: 10),

                    // --- BAGIAN LOKASI MAP (UNCHANGED) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Titik GPS",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _openMapPicker,
                          icon: const Icon(Icons.map, size: 18),
                          label: const Text("Buka Peta"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[700],
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            decoration: const InputDecoration(
                              labelText: "Lat",
                              hintText: "Wajib dari Peta",
                            ),
                            readOnly: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _longController,
                            decoration: const InputDecoration(
                              labelText: "Long",
                              hintText: "Wajib dari Peta",
                            ),
                            readOnly: true,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isEdit
                                    ? "SIMPAN PERUBAHAN"
                                    : "SIMPAN DATA BARU",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
