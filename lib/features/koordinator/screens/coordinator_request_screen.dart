// === FILE: lib\features\koordinator\screens\coordinator_request_screen.dart ===

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/services/request_service.dart'; // Diperlukan RequestDetail

class CoordinatorRequestScreen extends StatefulWidget {
  const CoordinatorRequestScreen({super.key});

  @override
  State<CoordinatorRequestScreen> createState() =>
      _CoordinatorRequestScreenState();
}

class _CoordinatorRequestScreenState extends State<CoordinatorRequestScreen> {
  final RequestService _service = RequestService();
  final _notesController =
      TextEditingController(); // [UBAH] Ganti details jadi notes umum

  String _selectedType = 'Perubahan Jadwal';
  bool _isLoading = false;

  // --- STATE BARU UNTUK FORM TERSTRUKTUR ---
  List<Map<String, dynamic>> _availableMenus = [];
  bool _isMenuLoading = true;

  // State untuk Perubahan Jadwal:
  DateTime _newDate = DateTime.now();
  TimeOfDay _newTime = const TimeOfDay(hour: 12, minute: 0);
  String? _selectedScheduleMenuId; // Menu yang mau dijadwalkan ulang

  // State untuk Perubahan Porsi/Menu:
  Map<String, int> _menuQuantities = {}; // {menuId: quantity}
  String? _selectedPortionMenuId;
  final TextEditingController _portionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMenus();
  }

  Future<void> _fetchMenus() async {
    try {
      final menus = await _service.getSppgMenus();
      setState(() {
        _availableMenus = menus;
        _isMenuLoading = false;

        // Set default menu ID untuk dropdown
        if (_availableMenus.isNotEmpty) {
          _selectedScheduleMenuId = _availableMenus.first['id'];
          _selectedPortionMenuId = _availableMenus.first['id'];
        }
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal load menu: $e")));
      setState(() => _isMenuLoading = false);
    }
  }

  // --- FUNGSI SUBMIT UTAMA ---
  Future<void> _submit() async {
    setState(() => _isLoading = true);

    List<RequestDetail> details = [];
    String? error;

    // 1. Validasi dan Konversi Data Sesuai Tipe
    if (_selectedType == 'Perubahan Jadwal') {
      if (_selectedScheduleMenuId == null) {
        error = "Pilih menu untuk perubahan jadwal.";
      } else {
        details.add(
          RequestDetail(
            menuId: _selectedScheduleMenuId!,
            menuName: _availableMenus.firstWhere(
              (m) => m['id'] == _selectedScheduleMenuId,
            )['name'],
            newDate: _newDate,
            newTime: _newTime,
          ),
        );
      }
    } else if (_selectedType == 'Tambah/Kurang Porsi') {
      final qty = int.tryParse(_portionController.text);
      if (_selectedPortionMenuId == null || qty == null || qty < 0) {
        error = "Jumlah porsi tidak valid.";
      } else {
        details.add(
          RequestDetail(
            menuId: _selectedPortionMenuId!,
            menuName: _availableMenus.firstWhere(
              (m) => m['id'] == _selectedPortionMenuId,
            )['name'],
            newQuantity: qty,
          ),
        );
      }
    } else if (_selectedType == 'Perubahan Menu') {
      // Untuk perubahan menu, kita asumsikan Koordinator memilih menu yang dia inginkan hari itu.
      // Kita hanya catat menu yang dipilih.
      if (_selectedPortionMenuId == null) {
        error = "Pilih menu yang diminta.";
      } else {
        details.add(
          RequestDetail(
            menuId: _selectedPortionMenuId!,
            menuName: _availableMenus.firstWhere(
              (m) => m['id'] == _selectedPortionMenuId,
            )['name'],
          ),
        );
      }
    }

    if (error != null) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error!)));
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 2. Kirim Request Terstruktur
      await _service.submitStructuredRequest(
        type: _selectedType,
        notes: _notesController.text,
        details: details,
      );

      // 3. Sukses & Reset
      _notesController.clear();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Pengajuan Terkirim!")));
      setState(() {}); // Refresh history
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      ),
      body: Column(
        children: [
          // --- FORM PENGAJUAN ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (val) => setState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 15),

                    // --- ISI FORM BERDASARKAN TIPE ---
                    _isMenuLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _buildDynamicForm(),

                    const SizedBox(height: 15),

                    // CATATAN UMUM
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Catatan Tambahan (Opsional)",
                        hintText: "Contoh: Mohon konfirmasi sebelum jam 9.",
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

          const Divider(),

          // --- LIST RIWAYAT ---
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "Riwayat Pengajuan",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
          ),
          Expanded(child: _buildHistoryList()),
        ],
      ),
    );
  }

  // --- WIDGET DINAMIS (UC 51, 52) ---
  Widget _buildDynamicForm() {
    if (_availableMenus.isEmpty) {
      return const Text(
        "❌ Tidak ada menu terdaftar di SPPG Anda.",
        style: TextStyle(color: Colors.red),
      );
    }

    if (_selectedType == 'Perubahan Jadwal') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Pilih Menu (FIX TIPE DI SINI)
          DropdownButtonFormField<String>(
            // <-- HARUS JELAS TIPE DI SINI
            value: _selectedScheduleMenuId,
            decoration: const InputDecoration(
              labelText: "Menu yang Dijadwal Ulang",
              prefixIcon: Icon(Icons.restaurant),
            ),
            items: _availableMenus
                // PASTIKAN .map BERJENIS String
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(m['name']),
                  ),
                )
                .toList(), // <-- INI YANG HARUS JADI List<DropdownMenuItem<String>>
            onChanged: (val) => setState(() => _selectedScheduleMenuId = val),
          ),
          const SizedBox(height: 15),

          // 2. Pilih Tanggal
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _newDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) setState(() => _newDate = date);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Tanggal Baru",
                prefixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_newDate),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // 3. Pilih Jam
          InkWell(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _newTime,
              );
              if (time != null) setState(() => _newTime = time);
            },
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: "Waktu Kedatangan Baru",
                prefixIcon: Icon(Icons.access_time),
              ),
              child: Text(_newTime.format(context)),
            ),
          ),
        ],
      );
    } else if (_selectedType == 'Perubahan Menu') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Pilih Menu Baru yang Diminta Hari Ini:",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            // <-- HARUS JELAS TIPE DI SINI
            value: _selectedPortionMenuId,
            decoration: const InputDecoration(
              labelText: "Menu Pengganti",
              prefixIcon: Icon(Icons.swap_horiz),
            ),
            items: _availableMenus
                // PASTIKAN .map BERJENIS String
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(m['name']),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() => _selectedPortionMenuId = val),
          ),
        ],
      );
    } else if (_selectedType == 'Tambah/Kurang Porsi') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Tentukan Porsi Baru:",
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            // <-- HARUS JELAS TIPE DI SINI
            value: _selectedPortionMenuId,
            decoration: const InputDecoration(
              labelText: "Pilih Menu",
              prefixIcon: Icon(Icons.restaurant),
            ),
            items: _availableMenus
                // PASTIKAN .map BERJENIS String
                .map(
                  (m) => DropdownMenuItem<String>(
                    value: m['id'] as String,
                    child: Text(m['name']),
                  ),
                )
                .toList(),
            onChanged: (val) => setState(() {
              _selectedPortionMenuId = val;
              _portionController.clear();
            }),
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _portionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Jumlah Porsi (Total Akhir)",
              prefixIcon: Icon(Icons.numbers),
              hintText: "Contoh: 550",
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink(); // Default kosong
  }

  // --- WIDGET HISTORY ---
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
          itemCount: data.length,
          itemBuilder: (ctx, i) {
            final item = data[i];
            Color statusColor = Colors.orange;
            if (item.status == 'approved') statusColor = Colors.green;
            if (item.status == 'rejected') statusColor = Colors.red;

            return ListTile(
              title: Text(
                item.type,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                // [UBAH] Menampilkan oldNotes sebagai catatan umum
                "Catatan: ${item.oldNotes}\nRespon: ${item.adminResponse ?? '-'}",
                style: const TextStyle(fontSize: 12),
              ),
              trailing: Chip(
                label: Text(
                  item.status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                backgroundColor: statusColor,
              ),
            );
          },
        );
      },
    );
  }
}
