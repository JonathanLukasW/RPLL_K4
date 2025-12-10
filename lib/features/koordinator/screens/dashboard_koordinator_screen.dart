// === FILE: lib/features/koordinator/screens/dashboard_koordinator_screen.dart ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:collection/collection.dart'; // <--- HARUS ADA DAN KE-LOAD!

import '../../autentikasi/screens/login_screen.dart';
import '../services/receiving_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/screens/profile_screen.dart';
import 'coordinator_request_screen.dart';
// FIX KRITIS: Ganti import model yang salah. DeliveryRoute ada di route_model.dart
import '../../../models/route_model.dart';
import '../../shared/screens/notification_screen.dart';
import '../../shared/services/notification_service.dart';

// Model untuk menampung satu item masalah
class IssueItem {
  String type; // e.g., 'Jumlah Tidak Sesuai', 'Kemasan Rusak'
  TextEditingController qtyController =
      TextEditingController(); // Jumlah terdampak atau menit terlambat
  TextEditingController notesController =
      TextEditingController(); // Detail masalah tambahan

  IssueItem({required this.type});
}

class DashboardKoordinatorScreen extends StatefulWidget {
  const DashboardKoordinatorScreen({super.key});

  @override
  State<DashboardKoordinatorScreen> createState() =>
      _DashboardKoordinatorScreenState();
}

class _DashboardKoordinatorScreenState
    extends State<DashboardKoordinatorScreen> {
  final ReceivingService _service = ReceivingService();
  final StorageService _storageService = StorageService();
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat =
      CalendarFormat.week; // Default Minggu biar ringkas
  // Map menyimpan tanggal (hanya date, tanpa time) dengan list of deliveries (stops)
  Map<DateTime, List<Map<String, dynamic>>> _deliveries = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDeliveries();
  }

  // Ambil data pengiriman untuk bulan yang sedang fokus
  Future<void> _fetchDeliveries() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getMonthlyDeliveries(_focusedDay);
      Map<DateTime, List<Map<String, dynamic>>> newMap = {};

      for (var item in data) {
        // Ambil tanggal dari delivery_routes (join)
        final dateStr = item['delivery_routes']['date'];
        final date = DateTime.parse(dateStr);
        final dateKey = DateTime(date.year, date.month, date.day);

        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(item);
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

  // Event Loader untuk Calendar
  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _deliveries[dateKey] ?? [];
  }

  // Helper untuk mendapatkan warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'received':
        return Colors.green;
      case 'issue_reported':
        return Colors.red;
      case 'completed':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // Format waktu dari HH:mm:ss ke HH:mm
  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "--:--";
    try {
      // Ambil 5 karakter pertama (HH:mm)
      return timeStr.substring(0, 5);
    } catch (_) {
      return timeStr;
    }
  }

  // Helper untuk mendapatkan nama Koordinator (asumsi profile data sudah di cache atau bisa di-fetch)
  // Karena kita tidak punya data profiles di state, kita akan gunakan nama default untuk demo
  String _getDefaultRecipientName() {
    // Dalam aplikasi nyata, ini diambil dari shared preference atau state user profile
    return "Koordinator Sekolah";
  }

  // [BARU] Function untuk memunculkan dialog konfirmasi penerimaan
  void _showReceptionDialog(Map<String, dynamic> stopData) {
    final stopId = stopData['id'];
    final schoolData = stopData['schools'];
    final schoolName = schoolData?['name'] ?? 'Sekolah Tidak Dikenal';
    final currentQty = schoolData?['student_count'] ?? 0;

    final recipientController = TextEditingController(
      text: _getDefaultRecipientName(),
    );

    // State untuk form utama
    final formKey = GlobalKey<FormState>();
    final receivedQtyController = TextEditingController(
      text: currentQty.toString(),
    );

    // State untuk Multi-Masalah
    List<IssueItem> currentIssues = [];
    File? photoFile;
    bool isSubmitting = false;

    const List<String> issueOptions = [
      'Jumlah Tidak Sesuai',
      'Kemasan Rusak',
      'Terlambat',
      'Lain-lain',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Helper untuk me-render input dinamis berdasarkan tipe masalah
          Widget _buildIssueInput(IssueItem issue, int currentQty) {
            // <-- Tambahkan currentQty
            switch (issue.type) {
              case 'Jumlah Tidak Sesuai':
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5), // Gap di dalam Card
                    Text(
                      "Kuantitas Target: $currentQty Porsi",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: issue.qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText:
                            "Kekurangan Total (Porsi)", // Mengacu pada jumlah yang kurang
                        hintText: "Contoh: 10",
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Wajib isi jumlah kekurangan"
                          : null,
                    ),
                    const SizedBox(height: 10), // Gap antar fields
                    TextFormField(
                      controller: issue.notesController,
                      decoration: const InputDecoration(
                        labelText: "Detail Masalah (Opsional)",
                      ),
                      maxLines: 2,
                    ),
                  ],
                );

              case 'Kemasan Rusak':
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: issue.qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Jumlah Kotak yang Rusak (Total)",
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Wajib isi jumlah kotak rusak"
                          : null,
                    ),
                    const SizedBox(height: 10), // Gap antar fields
                    TextFormField(
                      controller: issue.notesController,
                      decoration: const InputDecoration(
                        labelText: "Detail Kerusakan (Wajib Diisi)",
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Detail kerusakan wajib diisi."
                          : null,
                    ),
                  ],
                );

              case 'Terlambat':
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: issue.qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Keterlambatan (Menit)",
                        hintText: "Contoh: 30",
                      ),
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Wajib isi durasi keterlambatan"
                          : null,
                    ),
                    const SizedBox(height: 10), // Gap antar fields
                    TextFormField(
                      controller: issue.notesController,
                      decoration: const InputDecoration(
                        labelText: "Alasan Terlambat (Opsional)",
                      ),
                      maxLines: 2,
                    ),
                  ],
                );

              case 'Lain-lain':
              default:
                return Column(
                  children: [
                    const SizedBox(height: 5),
                    TextFormField(
                      controller: issue.notesController,
                      decoration: const InputDecoration(
                        labelText: "Detail Masalah Lainnya (Wajib Diisi)",
                      ),
                      maxLines: 3,
                      validator: (v) => (v == null || v.isEmpty)
                          ? "Detail masalah wajib diisi."
                          : null,
                    ),
                  ],
                );
            }
          }

          // Fungsi untuk menambahkan masalah baru
          void _addIssue(String type) {
            if (currentIssues.length >= 3) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Maksimal 3 jenis masalah!")),
              );
              return;
            }
            setDialogState(() {
              currentIssues.add(IssueItem(type: type));
            });
          }

          // Logic Simpan
          Future<void> _handleSubmission() async {
            if (!formKey.currentState!.validate()) return;

            final hasIssue = currentIssues.isNotEmpty;

            if (hasIssue && photoFile == null) {
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
              // Upload foto jika ada masalah
              if (photoFile != null) {
                uploadedUrl = await _storageService.uploadEvidence(
                  photoFile!,
                  'coordinator_reception',
                );
              }

              // Format List Issues ke JSON payload
              List<Map<String, dynamic>> issuePayload = currentIssues.map((
                issue,
              ) {
                final quantity = int.tryParse(issue.qtyController.text) ?? 0;

                // Hitung Quantity Defisit jika Jumlah Tidak Sesuai
                int deficit = 0;
                if (issue.type == 'Jumlah Tidak Sesuai') {
                  final received =
                      int.tryParse(receivedQtyController.text) ?? 0;
                  // Simpan selisih (kurangnya) di payload
                  deficit = currentQty - received;
                }

                return {
                  'type': issue.type,
                  'notes': issue.notesController.text.trim(),
                  'qty_impacted': (issue.type == 'Jumlah Tidak Sesuai')
                      ? deficit
                      : quantity,
                  'received_qty': (issue.type == 'Jumlah Tidak Sesuai')
                      ? quantity
                      : null, // Kuantitas Diterima (untuk rekonsiliasi)
                  'expected_qty': currentQty,
                };
              }).toList();

              // Panggil service untuk konfirmasi
              await _service.confirmReception(
                stopId: stopId,
                receivedQty: int.tryParse(receivedQtyController.text) ?? 0,
                recipientName: recipientController.text.trim(),
                issues: issuePayload,
                proofUrl: uploadedUrl,
              );

              if (!mounted) return;
              Navigator.pop(ctx);
              await _fetchDeliveries(); // Refresh jadwal
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    hasIssue
                        ? "Keluhan Terkirim ke Admin SPPG!"
                        : "Konfirmasi Selesai!",
                  ),
                  backgroundColor: hasIssue ? Colors.red : Colors.green,
                ),
              );
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Gagal Simpan: $e"),
                  backgroundColor: Colors.red,
                ),
              );
            } finally {
              if (mounted) setDialogState(() => isSubmitting = false);
            }
          }

          return AlertDialog(
            title: Text("Konfirmasi Penerimaan: $schoolName"),
            content: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Kuantitas Seharusnya:"),
                    Text(
                      "$currentQty Porsi",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.teal,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ), // Margin setelah Kuantitas Seharusnya
                    // --- Kuantitas Diterima ---
                    TextFormField(
                      controller: receivedQtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Kuantitas Diterima (Porsi)",
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                      onChanged: (v) {
                        final received = int.tryParse(v) ?? 0;
                        if (received < currentQty &&
                            currentIssues
                                .where((i) => i.type == 'Jumlah Tidak Sesuai')
                                .isEmpty) {
                          setDialogState(() {
                            _addIssue('Jumlah Tidak Sesuai');
                          });
                        }
                      },
                    ),
                    const SizedBox(
                      height: 15,
                    ), // Margin setelah Kuantitas Diterima
                    // --- Nama Penerima (Default Koordinator) ---
                    TextFormField(
                      controller: recipientController,
                      decoration: const InputDecoration(
                        labelText: "Nama Penerima",
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(
                      height: 25,
                    ), // Margin sebelum Section Masalah
                    // --- SECTION LAPOR MASALAH HEADER ---
                    const Text(
                      "Laporkan Masalah Kualitas/Kuantitas:",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Divider(), // Divider sudah cukup sebagai pemisah visual.
                    // Daftar Masalah yang Ditambahkan
                    ...currentIssues.mapIndexed((index, issue) {
                      return Padding(
                        // <-- PADDING DI SINI!
                        padding: const EdgeInsets.only(
                          bottom: 10,
                        ), // Margin antar Card Masalah
                        child: Card(
                          color: Colors.red[50],
                          margin: EdgeInsets
                              .zero, // Hapus margin default Card jika pakai Padding
                          child: Padding(
                            padding: const EdgeInsets.all(
                              12.0,
                            ), // Padding di dalam Card
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "⚠️ ${issue.type}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.red,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () => setDialogState(
                                        () => currentIssues.removeAt(index),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(
                                  height: 8,
                                ), // Margin sebelum input dinamis
                                _buildIssueInput(
                                  issue,
                                  currentQty,
                                ), // Panggil helper dengan currentQty
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),

                    // Dropdown Tambah Masalah Baru
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: "Tambah Jenis Masalah",
                      ),
                      value: null,
                      items: issueOptions
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          _addIssue(val);
                        }
                      },
                    ),
                    if (currentIssues.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      // ... (Foto Bukti section remains the same)
                      const Text(
                        "Foto Bukti (Wajib):",
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
                                    Text("Ambil Foto Bukti Masalah"),
                                  ],
                                )
                              : Image.file(photoFile!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 5),
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
                  backgroundColor: currentIssues.isEmpty
                      ? Colors.teal
                      : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        currentIssues.isEmpty
                            ? "KONFIRMASI AMAN"
                            : "LAPOR MASALAH",
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Koordinator Dashboard"),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
        actions: [
          // TOMBOL PENGAJUAN (REQUEST)
          IconButton(
            icon: const Icon(Icons.mail_outline),
            tooltip: "Pengajuan Perubahan",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CoordinatorRequestScreen(),
                ),
              );
            },
          ),
          // [BARU] TOMBOL NOTIFIKASI
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
                  ).then(
                    (value) => setState(() {}),
                  ); // Refresh dashboard setelah kembali
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
                color: Colors.teal, // Warna untuk hari ada jadwal
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
              "Jadwal Penerimaan Tgl ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDay)}",
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

  // Helper untuk menampilkan detail pengaduan dari JSON
  String _formatIssueDetails(List<dynamic> issues) {
    if (issues.isEmpty) return "Tidak ada masalah dilaporkan.";

    return issues
        .map((issue) {
          final type = issue['type'];
          final notes = issue['notes'] ?? '-';
          final qty = issue['qty_impacted'] ?? 0;

          if (type == 'Jumlah Tidak Sesuai') {
            return "• Kekurangan: $qty Porsi. Catatan: $notes";
          } else if (type == 'Kemasan Rusak') {
            return "• Rusak: $qty Kotak. Detail: $notes";
          } else if (type == 'Terlambat') {
            return "• Terlambat: $qty Menit. Alasan: $notes";
          } else {
            return "• $type: $notes";
          }
        })
        .join('\n');
  }

  void _showHistoryDetailDialog(Map<String, dynamic> stopData) {
    final schoolName = stopData['schools']['name'] ?? 'N/A';
    final receivedQty = stopData['received_qty'] ?? 0;
    final recipient = stopData['recipient_name'] ?? 'N/A';
    final isIssue = stopData['status'] == 'issue_reported';

    // Masalah tersimpan di issue_details (JSONB)
    List<dynamic> issueDetails = [];
    final issueJson = stopData['issue_details'];
    if (issueJson != null) {
      try {
        // Supabase mengembalikan JSONB sebagai String atau Map<String, dynamic>
        if (issueJson is String) {
          issueDetails = jsonDecode(issueJson);
        } else if (issueJson is List) {
          issueDetails = issueJson;
        }
      } catch (_) {
        // Fail silently
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Riwayat Penerimaan: $schoolName"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow(
                Icons.check_circle_outline,
                "Status Akhir",
                isIssue ? "MASALAH DILAPORKAN" : "DITERIMA AMAN",
                color: isIssue ? Colors.red : Colors.green,
              ),
              _buildInfoRow(Icons.person, "Penerima", recipient),
              _buildInfoRow(
                Icons.inventory,
                "Kuantitas Diterima",
                "$receivedQty Porsi",
              ),

              const Divider(height: 20),

              Text(
                isIssue ? "DETAIL MASALAH:" : "RINCIAN PENERIMAAN:",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // Tampilkan Detail Masalah / Notes
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isIssue ? Colors.red[50] : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isIssue
                      ? _formatIssueDetails(issueDetails)
                      : stopData['reception_notes'] ??
                            "Penerimaan dicatat aman.",
                  style: TextStyle(
                    color: isIssue ? Colors.red[900] : Colors.green[900],
                  ),
                ),
              ),

              // Bukti Foto Penerimaan (jika ada)
              if (stopData['proof_photo_url'] != null) ...[
                const SizedBox(height: 15),
                const Text(
                  "Foto Bukti Penerimaan:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageDialog(
                    ctx,
                    stopData['proof_photo_url'],
                    "Foto Bukti Penerimaan",
                  ),
                  child: Image.network(
                    stopData['proof_photo_url'],
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
          ),
        ],
      ),
    );
  }

  // Helper untuk info row (diperlukan di dalam dialog)
  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    Color color = Colors.black87,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Text("$title: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(
            child: Text(value, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }

  // Helper untuk menampilkan dialog gambar (pindah dari EditRouteScreen)
  void _showImageDialog(BuildContext context, String url, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.7,
          child: Image.network(url, fit: BoxFit.contain),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Tutup"),
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
        child: Text(
          "Tidak ada jadwal pengiriman atau masalah terdeteksi hari ini.",
        ),
      );
    }

    // Urutkan berdasarkan waktu kedatangan yang terestimasi (estimated_arrival_time)
    deliveries.sort(
      (a, b) => _formatTime(
        a['estimated_arrival_time'],
      ).compareTo(_formatTime(b['estimated_arrival_time'])),
    );

    return ListView.builder(
      itemCount: deliveries.length,
      itemBuilder: (context, index) {
        final stop = deliveries[index];
        final route = stop['delivery_routes'];
        final status = stop['status'] ?? 'pending';
        final estimatedArrival = _formatTime(stop['estimated_arrival_time']);

        final isFinalizedByKoord =
            status == 'received' || status == 'issue_reported';
        final isCourierArrived = status == 'completed';

        // Ambil info pengirim dari tabel vehicles (join melalui routes)
        final vehiclePlate = route['vehicles']?['plate_number'] ?? 'N/A';

        return Card(
          color: isFinalizedByKoord
              ? (status == 'issue_reported' ? Colors.red[50] : Colors.green[50])
              : (status == 'completed' ? Colors.orange[50] : Colors.white),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            // [FIX KRITIS]: Tambahkan onTap di sini
            onTap: () {
              // Hanya aktif jika sudah Final (received / issue_reported)
              if (isFinalizedByKoord) {
                _showHistoryDetailDialog(stop);
              }
            },
            leading: Icon(
              isFinalizedByKoord
                  ? Icons.check_circle
                  : (status == 'issue_reported' ? Icons.warning : Icons.timer),
              color: _getStatusColor(status),
            ),
            title: Text(
              "Est. Tiba: $estimatedArrival",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "Armada: $vehiclePlate\nStatus: ${status.toUpperCase()}",
              style: const TextStyle(fontSize: 12),
            ),
            trailing: isFinalizedByKoord
                ? const Icon(
                    Icons.info,
                    color: Colors.blueGrey,
                  ) // Ganti icon check/etc. menjadi info
                : (isCourierArrived
                      ? ElevatedButton(
                          onPressed: () => _showReceptionDialog(stop),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            "Konfirmasi",
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : Text(
                          status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        )),
          ),
        );
      },
    );
  }
}
