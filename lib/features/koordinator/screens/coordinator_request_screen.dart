import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import '../../shared/services/request_service.dart';
import 'dart:convert';
import 'package:flutter/material.dart'; // Ensure TimeOfDay is imported
import '../../admin_sppg/services/menu_service.dart'; // [BARU] Import MenuService dan
import '../../admin_sppg/services/menu_service.dart'; // Import AdminMenuSetModelModelnya

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

  // --- DATA ---// --- DATA ---
  List<Map<String, dynamic>> _availableMenus = [];
  List<AdminMenuSetModel> _availableMenuSets = []; // <-- BARU
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

  // Menu Set Customization
  String? _selectedMenuSetId; // ID Set yang dipilih/dimulai
  bool _isCustomizingMenu = false; // Mode edit set
  final TextEditingController _newSetNameController =
      TextEditingController(); // BARU

  // Mapping Menu IDs for Customization (Kategori -> Menu ID)
  Map<String, String?> _customMenuIds = {
    'Karbo': null,
    'Lauk Protein': null,
    'Sayur': null,
    'Buah': null,
    'Lauk Nabati': null,
    'Pelengkap': null,
  };
  final List<String> _requiredCategories = [
    'Karbo',
    'Lauk Protein',
    'Sayur',
    'Buah',
    'Lauk Nabati',
  ];

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
        _service.getMyMenuSets(),
      ]);

      _availableMenus = results[0] as List<Map<String, dynamic>>;
      // [BARU]
      _availableMenuSets = results[2] as List<AdminMenuSetModel>;

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

        // 3. Menu Default Parsing (Sekarang menyimpan NAMA SET)
        String defaultMenuStr = _schoolData!['menu_default'] ?? "";
        if (defaultMenuStr.isNotEmpty && _availableMenuSets.isNotEmpty) {
          final existingSet = _availableMenuSets.firstWhereOrNull(
            (set) => set.setName == defaultMenuStr,
          );
          if (existingSet != null) {
            _selectedMenuSetId = existingSet.id;
          }
        }
        setState(() => _isInitLoading = false);
      }
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
          // --- MODE KUSTOM BARU ---
          if (_isCustomizingMenu) {
            final validMenuIds = _customMenuIds.values
                .whereType<String>()
                .toList();
            if (_newSetNameController.text.isEmpty) {
              throw Exception("Nama Menu Set baru wajib diisi.");
            }
            if (validMenuIds.length < _requiredCategories.length) {
              throw Exception("Semua kategori wajib harus diisi.");
            }

            // Gabungkan semua ID Menu (Karbo_ID, Protein_ID, Sayur_ID, ...)
            final menuIdsJson = jsonEncode(_customMenuIds);
            final newSetName = _newSetNameController.text.trim();

            // Format Summary: REQ_MENU_SET_CUSTOM: {JSON_MENU_IDS} | NEW_NAME: Nama Set Baru
            summaryData =
                "REQ_MENU_SET_CUSTOM: $menuIdsJson | NEW_NAME: $newSetName | Note: $summaryData";

            // Kirim detail Set Menu di RequestDetail (MenuId tidak relevan di sini)
            details.add(
              RequestDetail(
                menuId: menuIdsJson, // Simpan payload JSON di menuId/oldNotes
                menuName: newSetName,
              ),
            );
          }
          // --- MODE PILIH SET LAMA ---
          else {
            if (_selectedMenuSetId == null) {
              throw Exception("Pilih Menu Set yang akan digunakan.");
            }
            // Cari nama set lama (menu_default)
            final oldSetName =
                _schoolData!['menu_default'] ?? "Set Lama Tidak Dikenal";
            final newSetName = _availableMenuSets
                .firstWhere((set) => set.id == _selectedMenuSetId!)
                .setName;

            // Format Summary: REQ_MENU_SET_ID: ID_SET | OLD_NAME: Nama Lama | NEW_NAME: Nama Baru
            summaryData =
                "REQ_MENU_SET_ID: $_selectedMenuSetId | OLD_NAME: $oldSetName | NEW_NAME: $newSetName | Note: $summaryData";

            details.add(
              RequestDetail(menuId: _selectedMenuSetId!, menuName: newSetName),
            );
          }
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

  // [BARU] Memuat Menu Set yang dipilih ke state kustomisasi
  void _loadSetForCustomization(AdminMenuSetModel set) {
    _newSetNameController.text =
        "${_schoolData!['name']} - Custom ${set.setName}";
    setState(() {
      _customMenuIds = {
        'Karbo': set.karboId,
        'Lauk Protein': set.proteinId,
        'Sayur': set.sayurId,
        'Buah': set.buahId,
        'Lauk Nabati': set.nabatiId,
        'Pelengkap': set.pelengkapId,
      };
      _isCustomizingMenu = true;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _portionController.dispose();
    _toleranceController.dispose();
    _newSetNameController.dispose(); // <-- BARU
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
    // 2. PERUBAHAN MENU (Menggunakan Menu Set)
    else if (_selectedType == 'Perubahan Menu') {
      // Mode Customisasi aktif
      if (_isCustomizingMenu) {
        // Widget untuk memilih Menu Item per Kategori
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Ajukan Menu Set Baru (Kustom):",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Input Nama Set Baru
            TextFormField(
              controller: _newSetNameController,
              decoration: const InputDecoration(
                labelText: "Nama Set Menu Kustom",
                hintText: "Cth: SMPN 6 - Set Senin Baru",
              ),
              validator: (v) => v!.isEmpty ? "Nama set wajib diisi" : null,
            ),
            const SizedBox(height: 15),

            // Dropdown per Kategori (menggunakan data menu dari _availableMenus)
            ..._customMenuIds.keys.map((category) {
              final isRequired = _requiredCategories.contains(category);
              final filteredMenus = _availableMenus
                  .where((m) => m['category'] == category)
                  .toList();

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText:
                        "$category ${isRequired ? '(Wajib)' : '(Opsional)'}",
                    prefixIcon: Icon(Icons.restaurant_menu),
                  ),
                  value: _customMenuIds[category],
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        isRequired ? "--- Pilih Menu ---" : "--- Tidak Ada ---",
                      ),
                    ),
                    ...filteredMenus.map(
                      (menu) => DropdownMenuItem(
                        value: menu['id'],
                        child: Text(menu['name']),
                      ),
                    ),
                  ],
                  onChanged: (String? newValue) =>
                      setState(() => _customMenuIds[category] = newValue),
                  validator: (v) => isRequired && v == null
                      ? "$category harus dipilih."
                      : null,
                ),
              );
            }).toList(),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _isCustomizingMenu = false),
                child: const Text("PILIH SET LAIN (Batal Kustom)"),
              ),
            ),
          ],
        );
      }

      // Mode Pilih Set yang Ada (Default)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pilih Set Menu Rutin Baru:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),

          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: "Pilih Menu Set",
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.menu_book),
            ),
            value: _selectedMenuSetId,
            items: _availableMenuSets
                .map(
                  (set) =>
                      DropdownMenuItem(value: set.id, child: Text(set.setName)),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedMenuSetId = val),
            validator: (v) => v == null ? "Wajib pilih Menu Set" : null,
          ),

          const SizedBox(height: 15),

          // Tampilkan tombol Kustomisasi jika ada set yang dipilih
          if (_selectedMenuSetId != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  final selectedSet = _availableMenuSets.firstWhereOrNull(
                    (set) => set.id == _selectedMenuSetId,
                  );
                  if (selectedSet != null) {
                    _loadSetForCustomization(selectedSet);
                  }
                },
                icon: const Icon(Icons.edit, color: Colors.white),
                label: const Text("UBAH SET INI (CUSTOM)"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
              ),
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
