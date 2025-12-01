import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart'; // Untuk firstWhereOrNull
import '../../shared/services/request_service.dart'; // Diperlukan RequestDetail

class CoordinatorRequestScreen extends StatefulWidget {
  const CoordinatorRequestScreen({super.key});

  @override
  State<CoordinatorRequestScreen> createState() =>
      _CoordinatorRequestScreenState();
}

class _CoordinatorRequestScreenState extends State<CoordinatorRequestScreen> {
  // [PERBAIKAN] Deklarasi form key yang hilang
  final _formKey = GlobalKey<FormState>(); 
  
  final RequestService _service = RequestService();
  final _notesController = TextEditingController();
  String _selectedType = 'Perubahan Jadwal';
  bool _isLoading = false;

  // --- STATE DATA ---
  List<Map<String, dynamic>> _availableMenus = [];
  bool _isMenuLoading = true;

  // State Perubahan Jadwal:
  DateTime _newDate = DateTime.now().add(const Duration(days: 1)); // Default besok
  TimeOfDay _newTime = const TimeOfDay(hour: 12, minute: 0);

  // State Perubahan Menu (Set Menu):
  List<String?> _selectedMenuIds = [null, null, null]; // Minimal 3 menu item

  // State untuk Tambah/Kurang Porsi
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
        if (_availableMenus.isNotEmpty) {
          _selectedPortionMenuId = _availableMenus.first['id'];
        }
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal load menu: $e")));
      setState(() => _isMenuLoading = false);
    }
  }

  Future<void> _submit() async {
    // Pengecekan validasi form key
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    List<RequestDetail> details = [];
    String? error;

    // 1. LOGIKA PERUBAHAN JADWAL (HANYA TANGGAL & WAKTU)
    if (_selectedType == 'Perubahan Jadwal') {
      details.add(
        RequestDetail(
          menuId: "N/A", // Mengirim N/A karena Menu tidak relevan di sini
          menuName: "Perubahan Jadwal",
          newDate: _newDate,
          newTime: _newTime,
        ),
      );
    }
    // 2. LOGIKA PERUBAHAN MENU (MULTI SELECT SET MENU)
    else if (_selectedType == 'Perubahan Menu') {
      final validMenuIds = _selectedMenuIds.whereType<String>().toList();

      if (validMenuIds.length < 3) {
        error = "Wajib memilih minimal 3 item menu set.";
      } else {
        // Tambahkan semua menu yang dipilih ke detail request
        for (var id in validMenuIds) {
          final menu = _availableMenus.firstWhereOrNull((m) => m['id'] == id);
          if (menu != null) {
            details.add(
              RequestDetail(
                menuId: id,
                menuName: menu['name'],
                newDate: _newDate, // Tanggal Menu baru ini akan diterapkan
              ),
            );
          }
        }
      }
    }
    // 3. LOGIKA PORSI (SINGLE MENU)
    else if (_selectedType == 'Tambah/Kurang Porsi') {
      final qty = int.tryParse(_portionController.text);
      if (_selectedPortionMenuId == null || qty == null || qty < 0) {
        error = "Jumlah porsi tidak valid atau menu belum dipilih.";
      } else {
        details.add(
          RequestDetail(
            menuId: _selectedPortionMenuId!,
            menuName: _availableMenus.firstWhere((m) => m['id'] == _selectedPortionMenuId)['name'],
            newQuantity: qty,
          ),
        );
      }
    }

    if (error != null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error!)));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _service.submitStructuredRequest(
        type: _selectedType,
        notes: _notesController.text,
        details: details,
      );

      // Sukses & Reset
      _notesController.clear();
      _portionController.clear();
      setState(() {
        _selectedMenuIds = [null, null, null];
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Pengajuan Terkirim!")));
      setState(() {}); // Refresh history
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _portionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text("Pengajuan Perubahan"),
          backgroundColor: Colors.teal),
      body: Column(
        children: [
          // --- FORM PENGAJUAN ---
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey, // <-- Kunci Form di sini
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Buat Pengajuan Baru",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                      // DROPDOWN TIPE REQUEST
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                            labelText: "Jenis Pengajuan",
                            border: OutlineInputBorder()),
                        items: [
                          'Perubahan Jadwal',
                          'Perubahan Menu',
                          'Tambah/Kurang Porsi',
                        ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedType = val!;
                            // Reset date/time to tomorrow by default when changing type
                            _newDate = DateTime.now().add(const Duration(days: 1)); 
                            _newTime = const TimeOfDay(hour: 12, minute: 0);
                          });
                        },
                      ),
                      const SizedBox(height: 15),

                      // --- ISI FORM BERDASARKAN TIPE ---
                      _isMenuLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _buildDynamicForm(),
                      const SizedBox(height: 15),

                      // CATATAN UMUM
                      TextFormField(
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

  // --- WIDGET DINAMIS ---
  Widget _buildDynamicForm() {
    if (_availableMenus.isEmpty) {
      return const Text(
        "❌ Tidak ada menu terdaftar di SPPG Anda.",
        style: TextStyle(color: Colors.red),
      );
    }

    // 1. PERUBAHAN JADWAL (Hanya Tanggal & Waktu)
    if (_selectedType == 'Perubahan Jadwal') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ajukan Waktu Kedatangan Baru:",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Tanggal Baru
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
                border: OutlineInputBorder(),
              ),
              child: Text(
                DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_newDate),
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Waktu Baru
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
                border: OutlineInputBorder(),
              ),
              child: Text(_newTime.format(context)),
            ),
          ),
        ],
      );
    }
    // 2. PERUBAHAN MENU (Set Menu: 3-5 Menu)
    else if (_selectedType == 'Perubahan Menu') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ajukan Set Menu Pengganti (Min 3, Max 5):",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          // Tanggal Menu Baru Diterapkan
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
                labelText: "Tanggal Menu Diterapkan",
                prefixIcon: Icon(Icons.calendar_today),
                border: OutlineInputBorder(),
              ),
              child: Text(
                DateFormat('EEEE, d MMM yyyy', 'id_ID').format(_newDate),
              ),
            ),
          ),
          const SizedBox(height: 15),

          // LIST DROP DOWN MENU (Min 3, Max 5)
          ...List.generate(_selectedMenuIds.length, (index) {
            final availableItems = _availableMenus.map((menu) {
              final menuId = menu['id'] as String;
              return DropdownMenuItem<String>(
                value: menuId,
                // Logika agar menu yang sama tidak bisa dipilih dua kali
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
                // Validasi minimal 3 item
                validator: (v) => (index < 3 && v == null)
                    ? "Menu #${index + 1} wajib diisi."
                    : null,
              ),
            );
          }),
          // Tombol Tambah/Kurang Slot
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_selectedMenuIds.length < 5)
                TextButton.icon(
                  icon: const Icon(Icons.add_circle, color: Colors.blue),
                  label: const Text("Tambah Slot"),
                  onPressed: () =>
                      setState(() => _selectedMenuIds.add(null)),
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Tentukan Porsi Baru:",
              style: TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _selectedPortionMenuId,
            decoration: const InputDecoration(
                labelText: "Pilih Menu", prefixIcon: Icon(Icons.restaurant)),
            items: _availableMenus
                .map((m) => DropdownMenuItem(
                    value: m['id'].toString(), child: Text(m['name'])))
                .toList(),
            onChanged: (val) => setState(() => _selectedPortionMenuId = val),
          ),
          const SizedBox(height: 15),
          TextFormField(
            controller: _portionController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Jumlah Porsi (Total Akhir)",
              prefixIcon: Icon(Icons.numbers),
              hintText: "Contoh: 550",
            ),
            validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
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
                "Tanggal: ${item.requestDate}\nCatatan: ${item.oldNotes}\nRespon: ${item.adminResponse ?? '-'}",
                style: const TextStyle(fontSize: 12),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
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