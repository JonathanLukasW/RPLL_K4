import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart'; // Import untuk firstWhereOrNull
import '../../autentikasi/screens/login_screen.dart';
import '../services/teacher_reception_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/screens/profile_screen.dart';
// === FILE: lib/features/walikelas/screens/dashboard_teacher_screen.dart ===

// [BARU] Import untuk Screen Notifikasi
import '../../shared/screens/notification_screen.dart';
import '../../shared/services/notification_service.dart';

class DashboardTeacherScreen extends StatefulWidget {
  const DashboardTeacherScreen({super.key});

  @override
  State<DashboardTeacherScreen> createState() => _DashboardTeacherScreenState();
}

// Helper untuk model masalah dinamis
class IssueDetail {
  String? qtyImpacted; // Jumlah item/porsi rusak/kurang/telat
  String? notes; // Detail keterangan

  IssueDetail({this.qtyImpacted, this.notes});
}

class _DashboardTeacherScreenState extends State<DashboardTeacherScreen> {
  final TeacherReceptionService _service = TeacherReceptionService();
  final StorageService _storageService = StorageService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat =
      CalendarFormat.week; // Default Minggu biar ringkas
  // Map menyimpan tanggal (hanya date, tanpa time) dengan list of deliveries (stops)
  Map<DateTime, List<Map<String, dynamic>>> _deliveries = {};
  bool _isLoading = true;
  String _myClassName = '';

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime(
      _focusedDay.year,
      _focusedDay.month,
      _focusedDay.day,
    );
    _fetchDeliveries();
  }

  // Ambil data pengiriman untuk bulan yang sedang fokus
  Future<void> _fetchDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getMonthlyDeliveries(_focusedDay);
      Map<DateTime, List<Map<String, dynamic>>> newMap = {};

      for (var item in data) {
        final dateStr = item['delivery_routes']['date'];
        final date = DateTime.parse(dateStr);
        final dateKey = DateTime(date.year, date.month, date.day);

        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(item);

        // Ambil nama kelas dari data pertama
        if (_myClassName.isEmpty) {
          _myClassName = item['my_class_name'] ?? 'Kelas Lain';
        }
      }

      if (mounted) {
        setState(() {
          _deliveries = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal load jadwal: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _deliveries[dateKey] ?? [];
  }

  // Event Handler untuk konfirmasi penerimaan
  void _showReceptionDialog(Map<String, dynamic> stopData) {
    final stopId = stopData['id'];
    final schoolName = stopData['schools']['name'] ?? 'Sekolah?';
    final menuRef = stopData['schools']['menu_default'] ?? 'Menu Belum Diset';

    // [BARU]: Ambil kuantitas yang diharapkan untuk kelas ini
    final expectedClassPortions = stopData['expected_class_portions'] ?? 0;
    final className = stopData['my_class_name'];

    // [FIX KRITIS 1]: Defaultkan qtyController ke kuantitas KELAS
    final qtyController = TextEditingController(
      text: expectedClassPortions.toString(),
    );

    // Kontroler untuk input dinamis
    final notesController = TextEditingController();
    final dynamicQtyController =
        TextEditingController(); // Untuk porsi kurang / rusak / basi

    String? issueType; // null = aman, string = ada masalah
    File? photoFile;
    bool isSubmitting = false;

    // [FIX KRITIS 2]: Update List Jenis Masalah
    const List<String> issueOptions = [
      'Makanan Basi/Berbau',
      'Kemasan Rusak', // Dulu Kualitas Buruk
      'Porsi Kurang',
      'Lain-lain',
    ];
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final formKey = GlobalKey<FormState>();

          // Helper untuk menampilkan input dinamis
          Widget _buildDynamicIssueFields() {
            if (issueType == null) return const SizedBox.shrink();

            // [FIX: Logic Porsi Kurang]
            if (issueType == 'Porsi Kurang') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: dynamicQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Jumlah Porsi yang Kurang",
                      hintText: "Contoh: 5",
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty || int.tryParse(v)! <= 0)
                        ? "Wajib isi jumlah kekurangan."
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Detail Masalah (Opsional)",
                    ),
                  ),
                ],
              );
            }
            // [FIX: Logic Makanan Basi/Kemasan Rusak]
            else if (issueType == 'Makanan Basi/Berbau' ||
                issueType == 'Kemasan Rusak') {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: dynamicQtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                          "Jumlah Porsi/Kotak yang ${issueType == 'Makanan Basi/Berbau' ? 'Basi/Rusak' : 'Rusak Kemasan'}",
                      hintText: "Total yang terdampak",
                    ),
                    validator: (v) =>
                        (v == null || v.isEmpty || int.tryParse(v)! < 0)
                        ? "Wajib isi jumlah yang terdampak (0 jika tidak tahu)"
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Keterangan Detail (Wajib Diisi)",
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Keterangan wajib diisi." : null,
                  ),
                ],
              );
            }
            // [FIX: Logic Lain-lain]
            else if (issueType == 'Lain-lain') {
              return Column(
                children: [
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: "Keterangan Detail (Wajib Diisi)",
                    ),
                    validator: (v) =>
                        v!.isEmpty ? "Keterangan wajib diisi." : null,
                  ),
                ],
              );
            }

            return const SizedBox.shrink(); // Default jika tidak ada
          }

          // Logika Submission
          Future<void> _handleSubmission() async {
            if (!formKey.currentState!.validate()) return;

            // Validasi Foto Bukti (selalu wajib jika issueType != null)
            if (issueType != null && photoFile == null) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Semua laporan masalah butuh foto bukti!"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            setDialogState(() => isSubmitting = true);
            String? uploadedUrl;

            try {
              // Upload foto
              if (photoFile != null) {
                uploadedUrl = await _storageService.uploadEvidence(
                  photoFile!,
                  'teacher_reception',
                );
              }

              // Gabungkan notes dan dynamic input untuk dikirim ke DB
              String finalNotes = notesController.text.trim();
              if (issueType != null) {
                final String qtyInfo = dynamicQtyController.text.isNotEmpty
                    ? " (Terdampak: ${dynamicQtyController.text})"
                    : "";
                finalNotes = "[$issueType$qtyInfo] $finalNotes";
              }

              // Panggil service untuk konfirmasi
              await _service.submitClassReception(
                stopId: stopId,
                className: className,
                qty: int.tryParse(qtyController.text) ?? 0,
                notes: finalNotes, // Mengirim catatan gabungan
                issueType: issueType,
                proofUrl: uploadedUrl,
              );

              if (!mounted) return;
              Navigator.pop(ctx);
              await _fetchDeliveries();
              // ... (feedback messages)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    issueType == null
                        ? "Konfirmasi Kelas Berhasil!"
                        : "Keluhan Kualitas Terkirim ke Admin SPPG!",
                  ),
                  backgroundColor: issueType == null
                      ? Colors.green
                      : Colors.red,
                ),
              );
            } catch (e) {
              // ... (error handling)
            } finally {
              if (mounted) setDialogState(() => isSubmitting = false);
            }
          }

          return AlertDialog(
            title: Text("Konfirmasi Kelas $className: $schoolName"),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [FIX TAMPILAN]: Porsi yang Diharapkan
                    const Text("Kuantitas Seharusnya:"),
                    Text(
                      "$expectedClassPortions Porsi",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // --- Kuantitas Diterima ---
                    TextFormField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Jumlah Porsi yang Diterima Kelas",
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),

                    // --- Dropdown Masalah ---
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Laporkan Masalah Kualitas (Opsional)",
                      ),
                      value: issueType,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text("✅ Aman, Tidak Ada Masalah"),
                        ),
                        ...issueOptions.map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(
                              e,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          issueType = val;
                          // Clear dynamic inputs saat tipe berubah
                          dynamicQtyController.clear();
                          notesController.clear();
                          photoFile =
                              null; // Reset foto saat masalah dipilih/dibatalkan
                        });
                      },
                    ),

                    // --- INPUT DINAMIS MASALAH ---
                    _buildDynamicIssueFields(),

                    // --- FOTO BUKTI ---
                    if (issueType != null) ...[
                      const SizedBox(height: 15),
                      const Text(
                        "Foto Bukti (Wajib jika ada masalah):",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 5),
                      GestureDetector(
                        onTap: () async {
                          final file = await _storageService.pickImage(
                            ImageSource.camera,
                          );
                          if (file != null)
                            setDialogState(() => photoFile = file);
                        },
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            border: Border.all(color: Colors.red),
                          ),
                          child: photoFile == null
                              ? const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 30,
                                      color: Colors.red,
                                    ),
                                    Text("Ambil Foto Bukti"),
                                  ],
                                )
                              : Image.file(photoFile!, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: isSubmitting ? null : _handleSubmission,
                style: ElevatedButton.styleFrom(
                  backgroundColor: issueType == null
                      ? Colors.indigo
                      : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        issueType == null
                            ? "KONFIRMASI TERIMA"
                            : "LAPOR MASALAH",
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper untuk mendapatkan icon status
  IconData _getStatusIcon(bool alreadyReceived, String stopStatus) {
    if (alreadyReceived) return Icons.check_box;
    if (stopStatus == 'received' || stopStatus == 'completed')
      return Icons.delivery_dining;
    return Icons.pending_actions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Wali Kelas - ${_myClassName.isNotEmpty ? _myClassName : 'Loading...'}",
        ),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
        actions: [
          FutureBuilder<int>(
            future: NotificationService().getUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text('$unreadCount'),
                  child: const Icon(Icons.notifications),
                ),
                tooltip: "Notifikasi",
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationScreen(),
                    ),
                  ).then((value) => setState(() {}));
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30),
            tooltip: "Profil & Password",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // --- KALENDER ---
          TableCalendar<Map<String, dynamic>>(
            firstDay: DateTime.utc(2024, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: _getEventsForDay,
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            onPageChanged: (focused) {
              _focusedDay = focused;
              _fetchDeliveries(); // Refresh data saat bulan berubah
            },
            calendarStyle: const CalendarStyle(
              markerDecoration: BoxDecoration(
                color: Colors.indigo, // Warna untuk hari ada jadwal
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: Colors.orange, // Warna untuk hari yang dipilih
                shape: BoxShape.circle,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
          ),
          const Divider(thickness: 1),
          // --- LIST PENGIRIMAN HARI INI ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Jadwal Penerimaan Kelas (${_myClassName.isNotEmpty ? _myClassName : '...'}), Tgl ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDay)}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildDayList(),
          ),
        ],
      ),
    );
  }

  // Widget untuk menampilkan daftar pengiriman di hari yang dipilih
  Widget _buildDayList() {
    final deliveries = _getEventsForDay(_selectedDay);
    if (deliveries.isEmpty) {
      return const Center(
        child: Text("Tidak ada jadwal pengiriman untuk sekolah Anda hari ini."),
      );
    }

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final stop = deliveries[index];
        final stopId = stop['id'];
        final bool isSchoolReceived =
            stop['status'] == 'received' || stop['status'] == 'issue_reported';
        final bool isClassReceived = stop['already_received'] == true;
        final String menuName =
            stop['schools']['menu_default'] ?? 'Menu Default Belum Diset';

        // [FIX KRITIS 1]: Gunakan porsi kelas yang sudah dihitung di service
        final int classPortions = stop['expected_class_portions'] ?? 0;

        // --- STATUS CHECK ---
        // Status ini mencerminkan aksi terakhir di delivery_stops (Kurir/Koordinator)
        final bool
        isSchoolFinalized = // Renaming the confusing isSchoolReceived
            stop['status'] == 'received' || stop['status'] == 'issue_reported';

        // --- DYNAMIC CONTENT FROM NESTED FUTUREBUILDER ---
        return FutureBuilder<Map<String, dynamic>?>(
          future: _service.getClassReceptionForStop(stopId),
          builder: (context, snapshot) {
            final receptionData = snapshot.data;
            final hasIssue = receptionData?['issue_type'] != null;
            final issueDetail = receptionData?['notes'] ?? 'Aman.';
            final receptionStatusText = isClassReceived
                ? (hasIssue
                      ? '⚠️ Ada Keluhan: ${receptionData!['issue_type']}'
                      : '✅ Sudah Konfirmasi')
                : 'BELUM KONFIRMASI';

            return Card(
              color: isClassReceived
                  ? (hasIssue ? Colors.red[50] : Colors.green[50])
                  : (isSchoolFinalized ? Colors.orange[50] : Colors.white),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: Icon(
                  _getStatusIcon(isClassReceived, stop['status']),
                  color: isClassReceived
                      ? (hasIssue ? Colors.red : Colors.green)
                      : (isSchoolReceived ? Colors.orange : Colors.indigo),
                ),
                title: Text(
                  "Status Penerimaan Awal: ${isSchoolFinalized ? 'SUDAH DITERIMA' : 'PENDING'}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // [FIX KRITIS 2]: Tampilkan porsi kelas
                    Text("Menu: $menuName (Kelas: $classPortions Porsi)"),
                    // FIX TAMPILAN: Status kelas dan detail keluhan
                    Text(
                      "Kelas Anda: $receptionStatusText",
                      style: TextStyle(
                        fontSize: 12,
                        color: hasIssue ? Colors.red[800] : Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (hasIssue)
                      Text(
                        "Detail: $issueDetail",
                        style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                      ),
                  ],
                ),
                trailing: isSchoolReceived && !isClassReceived
                    ? ElevatedButton(
                        onPressed: () => _showReceptionDialog(stop),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text(
                          "Konfirmasi",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                    : (isClassReceived
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null),
              ),
            );
          },
        );
      },
    );
  }
}
