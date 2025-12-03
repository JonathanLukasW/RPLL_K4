import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../shared/services/request_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart'; // Ensure TimeOfDay is imported

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
  final _formKey = GlobalKey<FormState>();
  final RequestService _service = RequestService();
  final _notesController = TextEditingController();

  String _selectedType = 'Perubahan Jadwal';
  bool _isLoading = false;
  bool _isInitLoading = true;
  bool _isSubmitting = false;

  // --- DATA ---
  List<Map<String, dynamic>> _availableMenus = [];
  Map<String, dynamic>? _schoolData;

  // --- FORM STATE ---
  Map<String, TimeOfDay?> _weeklySchedule = {
    for (var day in _daysCo) day: null,
  };
  TimeOfDay? _universalTime;
  List<String?> _selectedMenuIds = [null, null, null];
  final TextEditingController _portionController = TextEditingController();
  final TextEditingController _toleranceController = TextEditingController(
    text: '45',
  );

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // --- FIX 1: Make sure _schoolData is checked before using it ---
  Future<void> _loadInitialData() async {
    try {
      final results = await Future.wait([
        _service.getSppgMenus(),
        _service.getMySchoolDetails(),
      ]);

      _availableMenus = results[0] as List<Map<String, dynamic>>;

      // Safely cast result, ensuring _schoolData is only updated if fetch succeeded
      Map<String, dynamic>? fetchedSchoolData =
          results[1] as Map<String, dynamic>?;

      // If successful fetch, initialize all fields
      if (fetchedSchoolData != null) {
        _schoolData = fetchedSchoolData;

        // 1. Porsi, Tolerance
        // Use null-aware operators where feasible, relying on fallback '0' or '45'
        _portionController.text = (_schoolData!['student_count'] ?? 0)
            .toString();
        _toleranceController.text = (_schoolData!['tolerance_minutes'] ?? 45)
            .toString();

        // 2. Load Routine Weekly Schedule from JSON
        final dlJsonStr = _schoolData!['deadline_time'] as String?;
        if (dlJsonStr != null && dlJsonStr.startsWith('{')) {
          final Map<String, dynamic> scheduleMap = jsonDecode(dlJsonStr);
          Map<String, TimeOfDay?> initialSchedule = {};

          for (var day in _daysCo) {
            if (scheduleMap.containsKey(day)) {
              final parts = scheduleMap[day].split(':');
              initialSchedule[day] = TimeOfDay(
                hour: int.parse(parts[0]),
                minute: int.parse(parts[1]),
              );
            } else {
              initialSchedule[day] = null;
            }
          }
          _weeklySchedule = initialSchedule;
        }

        // 3. Menu Default Parsing
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
      } else {
        // If initial school data failed to fetch, set a default non-null state for controllers
        _portionController.text = '0';
        _toleranceController.text = '45';
        // _schoolData remains null, forcing subsequent use of _schoolData! to throw.
      }

      setState(() => _isInitLoading = false);
    } catch (e) {
      setState(() => _isInitLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching initial data: $e")),
        );
    }
  }

  // --- HELPER METHODS RESTORED ---

  String _calculateArrivalTime(TimeOfDay deadline, int toleranceMinutes) {
    final now = DateTime.now();
    final deadlineDt = DateTime(
      now.year,
      now.month,
      now.day,
      deadline.hour,
      deadline.minute,
    );
    final arrival = deadlineDt.subtract(Duration(minutes: toleranceMinutes));
    if (arrival.isBefore(DateTime(now.year, now.month, now.day))) {
      return "00:00 (Error)";
    }
    return DateFormat('HH:mm').format(arrival);
  }

  Future<void> _pickUniversalTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _universalTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _universalTime = picked;
        _weeklySchedule = {for (var day in _daysCo) day: picked};
      });
    }
  }

  // --- CANCELLATION LOGIC RESTORED (FIXES THE NULL CHECK ERROR) ---
  Future<void> _confirmCancel(String requestId, String type) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Batalkan Pengajuan?"),
        content: Text("Anda yakin ingin membatalkan pengajuan '$type'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("TIDAK"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "YA, BATALKAN",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await _service.cancelRequest(requestId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Pengajuan Dibatalkan."),
              backgroundColor: Colors.green,
            ),
          );
        }
        setState(() {});
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Gagal Batal: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }
  // --- END RESTORED METHODS ---

  // --- END RESTORED METHODS ---
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // PENTING: Jika schoolData null, berarti inisialisasi gagal. Tolak pengiriman.
      if (_schoolData == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Data sekolah gagal dimuat. Tidak bisa kirim pengajuan.",
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        String summaryData = _notesController.text.trim();
        List<RequestDetail> details = [];
        String schoolId = _schoolData!['id'];

        // --- 1. LOGIC PERUBAHAN JADWAL (Weekly Routine + Tolerance) ---
        if (_selectedType == 'Perubahan Jadwal') {
          // A. Serialize Weekly Schedule ke JSON String
          final Map<String, String> scheduleMap = {};
          _weeklySchedule.forEach((day, time) {
            if (time != null) {
              scheduleMap[day] =
                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00";
            }
          });

          final String scheduleJson = jsonEncode(scheduleMap);
          final int newTolerance =
              int.tryParse(_toleranceController.text) ?? 45;

          // B. Masukkan data ke summary: REQ_JADWAL: {JSON_SCHEDULE} | REQ_TOLERANCE: 45
          // Kita simpan FULL JSON schedule di kolom notes, dan tolerance di newQuantity field.
          summaryData =
              "REQ_JADWAL: $scheduleJson | REQ_TOLERANCE: $newTolerance | Note: $summaryData";

          // C. Buat RequestDetail dummy untuk membawa NEW QUANTITY (Tolerance)
          // HACK: Kita pakai newQuantity di RequestDetail untuk membawa data tolerance.
          details.add(
            RequestDetail(
              menuId: '', // Dummy
              menuName: '', // Dummy
              newQuantity: newTolerance, // <-- Simpan Tolerance di sini!
            ),
          );
        }
        // --- 2. LOGIC PERUBAHAN MENU SET ---
        else if (_selectedType == 'Perubahan Menu') {
          final validMenuIds = _selectedMenuIds.whereType<String>().toList();
          if (validMenuIds.length < 3)
            throw Exception("Wajib pilih minimal 3 item Menu Set.");

          // Buat string nama menu untuk admin
          final menuNames = validMenuIds
              .map(
                (id) =>
                    _availableMenus.firstWhereOrNull(
                      (m) => m['id'] == id,
                    )?['name'] ??
                    "Menu Hilang",
              )
              .join(', ');

          // Masukkan data ke summary
          summaryData = "REQ_MENU: $menuNames | Note: $summaryData";

          // Buat RequestDetail dummy
          details.add(
            RequestDetail(
              menuId: validMenuIds.join(','), // Simpan ID menu di sini
              menuName: menuNames,
            ),
          );
        }
        // --- 3. LOGIC TAMBAH/KURANG PORSI ---
        else if (_selectedType == 'Tambah/Kurang Porsi') {
          final int newPortion = int.tryParse(_portionController.text) ?? 0;
          if (newPortion <= 0)
            throw Exception("Jumlah porsi baru harus lebih dari 0.");

          // Masukkan data ke summary
          summaryData = "REQ_PORSI: $newPortion | Note: $summaryData";

          // Buat RequestDetail untuk membawa NEW QUANTITY (Porsi)
          details.add(
            RequestDetail(
              menuId: '', // Dummy
              menuName: '', // Dummy
              newQuantity: newPortion, // <-- Simpan Porsi di sini!
            ),
          );
        }

        // --- FINAL: SUBMIT KE SERVICE ---
        await _service.submitStructuredRequest(
          type: _selectedType,
          notes: summaryData, // <-- Mengirim data terstruktur di sini
          details: details,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Pengajuan Terkirim! Menunggu Review Admin."),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh list history setelah kirim
        setState(() {});
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal Kirim Pengajuan: $e"),
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
    _notesController.dispose();
    _portionController.dispose();
    _toleranceController.dispose();
    super.dispose();
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
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Buat Pengajuan Baru",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),
                              // DROPDOWN TIPE REQUEST
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
                                onChanged: (val) =>
                                    setState(() => _selectedType = val!),
                              ),
                              const SizedBox(height: 15),

                              // --- ISI FORM BERDASARKAN TIPE ---
                              _buildDynamicForm(),

                              const SizedBox(height: 15),
                              // CATATAN UMUM
                              TextFormField(
                                controller: _notesController,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: "Catatan Tambahan (Opsional)",
                                  hintText:
                                      "Contoh: Mohon konfirmasi sebelum jam 9.",
                                  border: OutlineInputBorder(),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _submit,
                                  icon: const Icon(Icons.send),
                                  label: const Text("Kirim Pengajuan"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Divider(),
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      "Riwayat Pengajuan",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  // --- WIDGET DINAMIS (REWRITING JADWAL TO ROUTINE SETTING) ---
  Widget _buildDynamicForm() {
    if (_availableMenus.isEmpty && _selectedType != 'Perubahan Jadwal') {
      return const Text(
        "Tidak ada menu terdaftar di SPPG Anda.",
        style: TextStyle(color: Colors.red),
      );
    }

    // 1. PERUBAHAN JADWAL (Weekly Routine)
    if (_selectedType == 'Perubahan Jadwal') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Atur Deadline Rutin Mingguan (Mon-Sat):",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickUniversalTime,
              icon: const Icon(Icons.schedule, color: Colors.blue),
              label: Text(
                "Apply Jam: ${_universalTime?.format(context) ?? 'Terapkan ke Semua Hari'}",
              ),
            ),
          ),
          const SizedBox(height: 15),

          // Daily Time Pickers
          ..._daysCo.map((day) {
            final time = _weeklySchedule[day];
            final currentTolerance =
                int.tryParse(_toleranceController.text) ?? 45;
            final String expectedArrival = time != null
                ? _calculateArrivalTime(time, currentTolerance)
                : "--:--";

            return Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.calendar_view_day,
                    color: time != null ? Colors.orange[800] : Colors.grey,
                  ),
                  title: Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: time != null ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    "Est. Tiba Kurir: $expectedArrival",
                    style: const TextStyle(color: Colors.blue),
                  ),
                  trailing: IconButton(
                    icon: Icon(time != null ? Icons.close : Icons.access_time),
                    onPressed: () async {
                      if (time != null) {
                        setState(() => _weeklySchedule[day] = null);
                      } else {
                        final TimeOfDay? picked = await showTimePicker(
                          context: context,
                          initialTime:
                              time ??
                              _universalTime ??
                              const TimeOfDay(hour: 12, minute: 0),
                        );
                        if (picked != null) {
                          setState(() => _weeklySchedule[day] = picked);
                        }
                      }
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
            );
          }).toList(),

          const SizedBox(height: 20),
          const Text(
            "Toleransi Pengiriman:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _toleranceController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Toleransi Awal (Menit)",
              hintText: "45",
              border: OutlineInputBorder(),
            ),
            validator: (v) => v!.isEmpty ? "Wajib" : null,
          ),
        ],
      );
    }
    // 2. PERUBAHAN MENU (Set Menu: 3-5 Menu - Same as before, now permanent change)
    else if (_selectedType == 'Perubahan Menu') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ajukan Set Menu Pengganti Rutin (Min 3, Max 5):",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          // ... (Menu Dropdowns and Add/Remove buttons remain the same)
          ...List.generate(_selectedMenuIds.length, (index) {
            final availableItems = _availableMenus.map((menu) {
              final menuId = menu['id'] as String;
              return DropdownMenuItem<String>(
                value: menuId,
                enabled: !_selectedMenuIds.whereType<String>().any(
                  (id) => id == menuId && id != _selectedMenuIds[index],
                ),
                child: Text(menu['name']),
              );
            }).toList();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: "Menu #${index + 1}",
                  prefixIcon: const Icon(Icons.restaurant_menu),
                  border: const OutlineInputBorder(),
                ),
                value: _selectedMenuIds[index],
                items: [
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text("--- Pilih Menu ---"),
                  ),
                  ...availableItems,
                ],
                onChanged: (String? newValue) =>
                    setState(() => _selectedMenuIds[index] = newValue),
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
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  label: const Text("Tambah Slot"),
                  onPressed: () => setState(() => _selectedMenuIds.add(null)),
                ),
              if (_selectedMenuIds.length > 3)
                TextButton.icon(
                  icon: const Icon(Icons.remove_circle, color: Colors.red),
                  label: const Text("Hapus Slot"),
                  onPressed: () =>
                      setState(() => _selectedMenuIds.removeLast()),
                ),
            ],
          ),
        ],
      );
    }
    // 3. TAMBAH/KURANG PORSI
    else if (_selectedType == 'Tambah/Kurang Porsi') {
      final currentCount = _schoolData?['student_count'] ?? 'Unknown';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Jumlah Penerima Rutin Saat Ini: $currentCount",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _portionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Jumlah Porsi Baru",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.people),
            ),
            validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHistoryList() {
    return FutureBuilder<List<ChangeRequestModel>>(
      future: _service.getMyRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data ?? [];
        if (data.isEmpty)
          return const Center(child: Text("Belum ada riwayat pengajuan."));
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            Color statusColor = item.status == 'pending'
                ? Colors.orange
                : (item.status == 'approved' ? Colors.green : Colors.red);

            final bool canCancel = item.status == 'pending';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                title: Text(
                  item.type,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  "Tanggal: ${item.requestDate}\nCatatan: ${item.oldNotes}\nRespon: ${item.adminResponse ?? '-'}",
                  style: const TextStyle(fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canCancel)
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red),
                        tooltip: "Batalkan Pengajuan",
                        onPressed: _isLoading
                            ? null
                            : () => _confirmCancel(item.id, item.type),
                      ),
                    Chip(
                      label: Text(
                        item.status.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                      ),
                      backgroundColor: statusColor,
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
}
