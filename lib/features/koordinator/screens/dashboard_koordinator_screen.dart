// === FILE: lib/features/koordinator/screens/dashboard_koordinator_screen.dart ===

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  // [BARU] Function untuk memunculkan dialog konfirmasi penerimaan
  void _showReceptionDialog(Map<String, dynamic> stopData) {
    final stopId = stopData['id'];
    // FIX SAFE ACCESS: Gunakan null check pada sub-map
    final schoolData = stopData['schools'];
    final schoolName = schoolData?['name'] ?? 'Sekolah Tidak Dikenal';
    final currentQty = schoolData?['student_count'] ?? 0;

    final qtyController = TextEditingController(text: currentQty.toString());
    final notesController = TextEditingController();
    final recipientController = TextEditingController();
    String? issueType; // null = aman, string = ada masalah
    File? photoFile;
    bool isSubmitting = false;

    // List jenis masalah untuk dropdown (Paket/Kuantitas)
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
          return AlertDialog(
            title: Text("Konfirmasi Penerimaan: $schoolName"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Kuantitas Diterima ---
                  TextFormField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Kuantitas Diterima (Porsi)",
                      hintText: "Target: $currentQty",
                    ),
                    validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                  ),
                  const SizedBox(height: 15),

                  // --- Nama Penerima ---
                  TextFormField(
                    controller: recipientController,
                    decoration: const InputDecoration(
                      labelText: "Nama Penerima",
                    ),
                    validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                  ),
                  const SizedBox(height: 15),

                  // --- Dropdown Masalah ---
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: "Laporkan Masalah (Opsional)",
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
                    onChanged: (val) => setDialogState(() => issueType = val),
                  ),

                  if (issueType != null) ...[
                    const SizedBox(height: 15),
                    // --- Catatan Komplain (Jika Ada Masalah) ---
                    TextFormField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Detail Masalah (Wajib Diisi)",
                      ),
                      validator: (v) => (issueType != null && v!.isEmpty)
                          ? "Detail masalah wajib diisi."
                          : null,
                    ),
                    const SizedBox(height: 15),

                    // --- Foto Bukti (Wajib Jika Ada Masalah) ---
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
                          border: Border.all(color: Colors.grey),
                        ),
                        child: photoFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt, size: 30),
                                  Text("Ambil Foto Bukti"),
                                ],
                              )
                            : Image.file(photoFile!, fit: BoxFit.cover),
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Batal"),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (issueType != null &&
                            (notesController.text.isEmpty ||
                                photoFile == null)) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Masalah butuh detail dan foto bukti, TOLOL!",
                              ),
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

                          // Panggil service untuk konfirmasi
                          await _service.confirmReception(
                            stopId: stopId,
                            receivedQty: int.tryParse(qtyController.text) ?? 0,
                            notes: notesController.text.trim(),
                            recipientName: recipientController.text.trim(),
                            issueType: issueType,
                            proofUrl: uploadedUrl,
                          );

                          if (!mounted) return;
                          Navigator.pop(ctx);
                          await _fetchDeliveries(); // Refresh jadwal
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                issueType == null
                                    ? "Konfirmasi Selesai!"
                                    : "Keluhan Terkirim ke Admin SPPG!",
                              ),
                              backgroundColor: issueType == null
                                  ? Colors.green
                                  : Colors.red,
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
                          if (mounted)
                            setDialogState(() => isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: issueType == null ? Colors.teal : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        issueType == null ? "KONFIRMASI AMAN" : "LAPOR MASALAH",
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

        // [LOGIC BARU]
        // 1. Sudah di-Finalisasi Koord/Client? (received/issue_reported) -> Cuma Icon Check
        final isFinalizedByKoord =
            status == 'received' || status == 'issue_reported';
        // 2. Kurir Sudah Tiba di Lokasi? (completed) -> Buka Tombol Konfirmasi Koord
        final isCourierArrived = status == 'completed';

        // Ambil info pengirim dari tabel vehicles (join melalui routes)
        final vehiclePlate = route['vehicles']?['plate_number'] ?? 'N/A';

        return Card(
          color: isFinalizedByKoord
              ? Colors.green[50]
              : (status == 'issue_reported' ? Colors.red[50] : Colors.white),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
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
                ? const Icon(Icons.check_circle_outline, color: Colors.green)
                // HANYA TAMPILKAN KONFIRMASI JIKA KURIR SUDAH ARRIVED (STATUS='completed')
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
