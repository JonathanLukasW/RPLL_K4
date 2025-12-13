// FILE: lib/features/admin_sppg/screens/center_info_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/services/request_service.dart';
import '../services/complaint_service.dart';
import '../services/school_service.dart'; // <--- FIX 1: TAMBAH IMPORT SERVICE
import '../../../models/school_model.dart'; // <--- FIX 2: TAMBAH IMPORT MODEL SCHOOL
import 'dart:convert';
import 'package:collection/collection.dart';

class CenterInfoScreen extends StatefulWidget {
  const CenterInfoScreen({super.key});

  @override
  State<CenterInfoScreen> createState() => _CenterInfoScreenState();
}

class _CenterInfoScreenState extends State<CenterInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RequestService _requestService = RequestService();
  final ComplaintService _complaintService = ComplaintService();

  // [FIX] Definisikan Key untuk memaksa refresh tab Komplain
  Key _complaintKey = UniqueKey();

  // [BARU] State untuk Filter Pengaduan
  final SchoolService _schoolService = SchoolService();
  List<School> _allSppgSchools = [];
  DateTime _selectedComplaintDate = DateTime.now();
  String? _selectedSchoolFilterId; // null = Semua Sekolah
  bool _isLoadingSchools = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchFilterData(); // Load data sekolah
  }

  // [BARU] Load data sekolah untuk filter
  Future<void> _fetchFilterData() async {
    try {
      final schools = await _schoolService.getMySchools();
      if (mounted) {
        setState(() {
          _allSppgSchools = schools;
          _isLoadingSchools = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSchools = false);
      print("Error loading schools for filter: $e");
    }
  }

  void _refreshData() {
    _fetchFilterData(); // Refresh list sekolah
    setState(() {
      _complaintKey = UniqueKey();
    });
  }

  // [BARU HELPER] Fungsi untuk mem-parse oldNotes yang berisi hack data
  String _formatRequestNotes(String type, String notes) {
    if (notes.isEmpty) return 'Tidak ada catatan tambahan.';

    try {
      if (type == 'Perubahan Jadwal') {
        final scheduleMatch = RegExp(r'REQ_JADWAL: ({.*?})').firstMatch(notes);
        final toleranceMatch = RegExp(
          r'REQ_TOLERANCE: (\d+)',
        ).firstMatch(notes);
        final noteMatch = RegExp(r'Note: (.*)').firstMatch(notes);

        String schedule = 'Jadwal Rutin: N/A';
        if (scheduleMatch != null && scheduleMatch.group(1) != null) {
          final Map<String, dynamic> scheduleMap = jsonDecode(
            scheduleMatch.group(1)!,
          );
          final List<String> entries = [];
          scheduleMap.forEach((day, time) {
            entries.add('$day: ${(time as String).substring(0, 5)}');
          });
          schedule = 'Jadwal Baru: ${entries.join(', ')}';
        }

        final tolerance = toleranceMatch?.group(1) ?? 'N/A';
        final userNote = noteMatch?.group(1) ?? '';

        return '$schedule (Toleransi: $tolerance mnt). Catatan: "$userNote"';
      } else if (type == 'Tambah/Kurang Porsi') {
        final portionMatch = RegExp(r'REQ_PORSI: (\d+)').firstMatch(notes);
        final userNote =
            RegExp(r'Note: (.*)').firstMatch(notes)?.group(1) ?? '';
        final newPortion = portionMatch?.group(1) ?? 'N/A';
        return 'Diajukan Porsi Baru: $newPortion Siswa. Catatan: "$userNote"';
      } else if (type == 'Perubahan Menu') {
        if (notes.contains('REQ_MENU_SET_CUSTOM:')) {
          final nameMatch = RegExp(r'NEW_NAME: (.*?) \|').firstMatch(notes);
          final newSetName = nameMatch?.group(1)?.trim() ?? 'Set Kustom Baru';
          return 'Ajuan Set Menu Kustom: "$newSetName" (Akan dibuatkan set baru di DB).';
        } else if (notes.contains('REQ_MENU_SET_ID:')) {
          final newNameMatch = RegExp(r'NEW_NAME: (.*?) \|').firstMatch(notes);
          final newSetName =
              newNameMatch?.group(1)?.trim() ?? 'Set Baru Dipilih';
          return 'Ganti Set Rutin ke: "$newSetName".';
        }
        // Fallback untuk skenario lama (jika masih ada data lama)
        else if (notes.contains('REQ_MENU:')) {
          final menuNames = notes
              .split('|')[0]
              .replaceAll("REQ_MENU:", "")
              .trim();
          final userNote =
              RegExp(r'Note: (.*)').firstMatch(notes)?.group(1) ?? '';
          return 'Ganti Item Menu Lama: $menuNames. Catatan: "$userNote"';
        }
      }
    } catch (e) {
      return 'Gagal memformat catatan (Raw Data: $notes)';
    }
    return notes;
  }

  // --- APPROVAL DIALOG (Untuk Request) ---
  void _showApprovalDialog(ChangeRequestModel request) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Review: ${request.type}"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Sekolah: ${request.schoolName}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              width: double.infinity,
              child: Text(
                _formatRequestNotes(
                  request.type,
                  request.oldNotes,
                ), // <-- GUNAKAN HELPER
              ), // Shows the formatted request data
            ),
            const SizedBox(height: 15),
            const Text("Catatan Admin (Alasan Ditolak/Info):"),
            TextField(
              controller: noteController,
              maxLines: 2,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              if (noteController.text.isEmpty) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wajib isi alasan penolakan!")),
                );
                return;
              }
              Navigator.pop(ctx);
              await _requestService.respondRequest(
                requestId: request.id,
                status: 'rejected',
                adminNote: noteController.text,
                requestData: request, // <--- CRITICAL: Pass the data object
              );
              setState(() {});
            },
            child: const Text("TOLAK", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // "Apply Changes" logic is handled in the service for Menu/Porsi
              await _requestService.respondRequest(
                requestId: request.id,
                status: 'approved',
                adminNote: noteController.text.isEmpty
                    ? "OK"
                    : noteController.text,
                requestData: request, // <--- CRITICAL: Pass the data object
              );
              setState(() {});
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Disetujui & Data Diupdate!")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text("TERIMA & TERAPKAN"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pusat Informasi"), // Renamed from Pusat Pengaduan
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // ADD REFRESH BUTTON
            onPressed: _refreshData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Pengajuan (Request)"),
            Tab(text: "Pengaduan (Complain)"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestList(),
          _buildComplaintList(key: _complaintKey), // Use the dynamic key
        ],
      ),
    );
  }

  // --- WIDGET LIST PENGAJUAN (REQUEST) ---
  Widget _buildRequestList() {
    // Dropdown items untuk filter sekolah
    final List<DropdownMenuItem<String?>> schoolItems = [
      const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
      ..._allSppgSchools.map(
        (school) =>
            DropdownMenuItem(value: school.id, child: Text(school.name)),
      ),
    ];

    // Panggil FutureBuilder dengan filter yang berlaku saat ini
    return Column(
      children: [
        // FILTER Section
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Filter Tanggal
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                  ),
                  title: Text(
                    DateFormat(
                      'd MMMM yyyy',
                      'id_ID',
                    ).format(_selectedComplaintDate),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedComplaintDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedComplaintDate = picked;
                        _refreshData();
                      });
                    }
                  },
                ),
              ),
              // Filter Sekolah
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedSchoolFilterId,
                  decoration: const InputDecoration(
                    labelText: "Filter Sekolah",
                  ),
                  items: schoolItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSchoolFilterId = newValue;
                      _refreshData();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List Pengajuan
        Expanded(
          child: FutureBuilder<List<ChangeRequestModel>>(
            // Panggil service dengan filter
            future: _requestService.getIncomingRequests(
              date: _selectedComplaintDate,
              schoolId: _selectedSchoolFilterId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting)
                return const Center(child: CircularProgressIndicator());

              final data = snapshot.data ?? [];
              if (data.isEmpty)
                return const Center(
                  child: Text("Tidak ada pengajuan masuk sesuai filter."),
                );

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (ctx, i) {
                  final item = data[i];
                  bool isPending = item.status == 'pending';
                  final formattedNotes = _formatRequestNotes(
                    item.type,
                    item.oldNotes,
                  );

                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: ListTile(
                      leading: Icon(
                        item.type.contains("Menu")
                            ? Icons.restaurant_menu
                            : (item.type.contains("Porsi")
                                  ? Icons.pie_chart
                                  : Icons.calendar_today),
                        color: Colors.indigo,
                      ),
                      title: Text(
                        item.schoolName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("[${item.type}]"),
                          Text(
                            formattedNotes, // <-- GUNAKAN FORMAT BARU
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isPending)
                            Text(
                              "Status: ${item.status.toUpperCase()} (${item.adminResponse})",
                              style: TextStyle(
                                color: item.status == 'approved'
                                    ? Colors.green
                                    : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ],
                      ),
                      trailing: isPending
                          ? ElevatedButton(
                              onPressed: () => _showApprovalDialog(item),
                              child: const Text("Review"),
                            )
                          : const Icon(Icons.check_circle, color: Colors.grey),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- WIDGET LIST PENGADUAN (COMPLAINT) ---
  Widget _buildComplaintList({required Key key}) {
    if (_isLoadingSchools) {
      return const Center(child: CircularProgressIndicator());
    }

    // Dropdown items untuk filter sekolah
    final List<DropdownMenuItem<String?>> schoolItems = [
      const DropdownMenuItem(value: null, child: Text("Semua Sekolah")),
      ..._allSppgSchools.map(
        (school) =>
            DropdownMenuItem(value: school.id, child: Text(school.name)),
      ),
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Filter Tanggal
              Expanded(
                child: ListTile(
                  leading: const Icon(
                    Icons.calendar_today,
                    color: Colors.indigo,
                  ),
                  title: Text(
                    DateFormat(
                      'd MMMM yyyy',
                      'id_ID',
                    ).format(_selectedComplaintDate),
                  ),
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedComplaintDate,
                      firstDate: DateTime(2024),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedComplaintDate = picked;
                        _refreshData();
                      });
                    }
                  },
                ),
              ),
              // Filter Sekolah
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _selectedSchoolFilterId,
                  decoration: const InputDecoration(
                    labelText: "Filter Sekolah",
                  ),
                  items: schoolItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedSchoolFilterId = newValue;
                      _refreshData();
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // List Pengaduan
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            key: key,
            // Panggil service dengan filter
            future: _complaintService.getSppgComplaints(
              date: _selectedComplaintDate,
              schoolId: _selectedSchoolFilterId,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              final data = snapshot.data ?? [];
              if (data.isEmpty) {
                return const Center(
                  child: Text("Tidak ada keluhan masuk sesuai filter."),
                );
              }

              return ListView.builder(
                itemCount: data.length,
                itemBuilder: (ctx, i) {
                  final item = data[i];
                  final isResolved = item['admin_response'] != null;
                  final reporterRole = item['reporter_role'] ?? 'N/A';

                  // Tentukan target table dan ID untuk update
                  // ID complaint di RPC (item['id']) adalah ID PRIMARY KEY di CR/DS
                  final targetTable = reporterRole == 'walikelas'
                      ? 'class_receptions'
                      : 'delivery_stops';
                  final targetId = item['id'];

                  return Card(
                    color: isResolved ? Colors.green[50] : Colors.red[100],
                    margin: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    child: ListTile(
                      onTap: () => _showRespondComplaintDialog(
                        item,
                        reporterRole,
                        targetTable,
                        targetId,
                      ),
                      leading: Icon(
                        isResolved ? Icons.check_circle : Icons.warning,
                        color: isResolved ? Colors.green : Colors.red,
                      ),
                      title: Text(
                        item['school_name'] ?? 'Sekolah N/A',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Dari: ${item['reporter_name']} (${reporterRole.toUpperCase()})",
                          ),
                          // [FIX KRITIS]: Gunakan helper untuk mengurai JSON
                          Text(
                            "Rincian Isu:\n${_formatComplaintDetails(reporterRole, item['notes'])}",
                            // notes di sini seharusnya adalah issue_details JSONB
                            // Namun karena RPC mengembalikan 'notes', kita asumsikan 'notes' = JSONB issues
                          ),
                          Text(
                            isResolved
                                ? "Respon: ${item['admin_response']}"
                                : "Status: BELUM DITINDAK LANJUT",
                            style: TextStyle(
                              fontSize: 12,
                              color: isResolved
                                  ? Colors.green[800]
                                  : Colors.red[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      trailing: isResolved
                          ? const Icon(Icons.reply, color: Colors.grey)
                          : ElevatedButton(
                              onPressed: () => _showRespondComplaintDialog(
                                item,
                                reporterRole,
                                targetTable,
                                targetId,
                              ),
                              child: const Text("Tindak Lanjut"),
                            ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // [BARU HELPER] Mengurai JSON Issue Details dari Koordinator/Wali Kelas
  String _formatComplaintDetails(String reporterRole, String rawNotes) {
    if (rawNotes.isEmpty) return 'Tidak ada detail spesifik.';

    // Kasus 1: Laporan Koordinator (Diharapkan format JSON Array dari issue_details)
    if (reporterRole == 'koordinator') {
      try {
        String cleanedNotes = rawNotes.trim();

        // [FIX KRITIS JSON STRING]: Hapus quotes ganda di awal/akhir
        // Ini mengatasi masalah jika PostgREST mengembalikan JSONB sebagai string ber-quote.
        if (cleanedNotes.startsWith('"') && cleanedNotes.endsWith('"')) {
          cleanedNotes = cleanedNotes.substring(1, cleanedNotes.length - 1);
        }
        // Hapus escape character '\' yang mungkin tersisa
        cleanedNotes = cleanedNotes.replaceAll(r'\"', '"');

        final List<dynamic> issues = jsonDecode(
          cleanedNotes,
        ); // <-- Coba decode string yang sudah dibersihkan

        if (issues.isEmpty) return 'Diterima, tetapi detail masalah kosong.';

        return issues
            .mapIndexed((index, issue) {
              final type = issue['type'] ?? 'Masalah Umum';
              final notes = issue['notes']?.trim() ?? '—';
              final qty = issue['qty_impacted'];

              String qtyStr = '';
              if (type == 'Jumlah Tidak Sesuai') {
                qtyStr = ' (Defisit: ${qty} Porsi)';
              } else if (type == 'Kemasan Rusak') {
                qtyStr = ' (Rusak: ${qty} Kotak)';
              } else if (type == 'Terlambat') {
                qtyStr = ' (Telat: ${qty} Menit)';
              }

              return '${index + 1}. [${type}]${qtyStr}. Detail: "${notes}"';
            })
            .join('\n');
      } catch (e) {
        return 'Detail Masalah JSON Rusak. Raw Data: $rawNotes';
      }
    }
    // Kasus 2: Laporan Wali Kelas (Masih menggunakan format notes lama/tunggal)
    else {
      return rawNotes;
    }
  }

  // Helper untuk menampilkan dialog gambar (Disalin dari EditRouteScreen)
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

  void _showRespondComplaintDialog(
    Map<String, dynamic> complaint,
    String reporterRole,
    String targetTable,
    String targetTableId,
  ) {
    final responseController = TextEditingController();
    final issueDetailsText = _formatComplaintDetails(
      reporterRole,
      complaint['notes'],
    );

    // [BARU]: Ambil URL Foto dari item (asumsi sudah ditarik di RPC)
    final photoUrl = complaint['proof_photo_url'];
    final receivedQty = complaint['received_qty']; // Ambil kuantitas (jika ada)

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Tindak Lanjut Keluhan"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Detail Pengaduan
              const Text(
                "Detail Pengaduan:",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 5),

              // Kuantitas Diterima (relevan untuk Koordinator)
              if (receivedQty != null)
                Text(
                  "Kuantitas Diterima: $receivedQty Porsi",
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),

              const SizedBox(height: 10),

              // Rincian Isu (Formatted)
              Container(
                padding: const EdgeInsets.all(8),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  border: Border.all(color: Colors.red),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: SelectableText(
                  issueDetailsText,
                  style: const TextStyle(fontSize: 13),
                ),
              ),

              // [BARU]: BUKTI FOTO
              if (photoUrl != null) ...[
                const SizedBox(height: 15),
                const Text(
                  "Bukti Foto Pelapor:",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => _showImageDialog(
                    ctx,
                    photoUrl,
                    "Bukti dari ${complaint['reporter_name']}",
                  ),
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      image: DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Icon(Icons.zoom_in, color: Colors.white70),
                  ),
                ),
              ],

              const SizedBox(height: 20),
              const Text(
                "Respon Admin:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              // Text Form Field Respon
              TextFormField(
                controller: responseController,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  labelText: "Instruksi / Tindak Lanjut Admin SPPG",
                  hintText: "Contoh: Sudah kami cek...",
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("BATAL"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (responseController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Wajib isi instruksi!")),
                );
                return;
              }
              Navigator.pop(ctx);

              // Cek ID Penerima Notifikasi (ID user profiles/auth)
              String finalReporterUserId;
              try {
                // Panggil service untuk mendapatkan ID user yang benar-benar melapor
                finalReporterUserId = await _complaintService
                    .getReporterIdForNotification(targetTableId, reporterRole);
              } catch (e) {
                if (mounted)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Gagal tentukan penerima notifikasi: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                return;
              }

              await _complaintService.respondToComplaint(
                id: complaint['id'], // ID unik complaint (dari RPC)
                response: responseController.text,
                reporterId:
                    finalReporterUserId, // ID user yang akan dapat notif
                reporterRole: reporterRole,
                targetTableId: targetTableId,
                targetTableName: targetTable,
              );
              _refreshData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Tindak Lanjut & Notifikasi Terkirim!"),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text("KIRIM INSTRUKSI"),
          ),
        ],
      ),
    );
  }
}
