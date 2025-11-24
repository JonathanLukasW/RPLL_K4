import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../autentikasi/screens/login_screen.dart';
import '../services/teacher_reception_service.dart';
// Import Storage Service
import '../../../core/services/storage_service.dart';
import '../../../core/screens/profile_screen.dart';

class DashboardTeacherScreen extends StatefulWidget {
  const DashboardTeacherScreen({super.key});

  @override
  State<DashboardTeacherScreen> createState() => _DashboardTeacherScreenState();
}

class _DashboardTeacherScreenState extends State<DashboardTeacherScreen> {
  final TeacherReceptionService _service = TeacherReceptionService();
  final StorageService _storageService = StorageService();

  Map<String, dynamic>? _deliveryData;
  bool _isLoading = true;
  bool _alreadyReceived = false;
  String _className = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getSchoolDeliveryStatus();
      if (mounted) {
        setState(() {
          _deliveryData = data;
          if (data != null) {
            _alreadyReceived = data['already_received'] ?? false;
            _className = data['my_class_name'] ?? "-";
          }
        });
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // --- DIALOG CANGGIH (QC & FOTO) ---
  void _showReceiveDialog() {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();

    // State lokal dialog
    File? photoFile;
    bool isProblem = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Laporan Kelas $_className"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Pilihan Status QC
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("✅ Aman"),
                          selected: !isProblem,
                          selectedColor: Colors.green[100],
                          onSelected: (val) =>
                              setDialogState(() => isProblem = !val),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text("⚠️ Masalah"),
                          selected: isProblem,
                          selectedColor: Colors.red[100],
                          onSelected: (val) =>
                              setDialogState(() => isProblem = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Jumlah Box Diterima",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: noteController,
                    decoration: InputDecoration(
                      labelText: isProblem
                          ? "Detail Masalah (Basi/Asing/dll)"
                          : "Catatan (Opsional)",
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 10),

                  // Tombol Kamera (Wajib jika Masalah)
                  if (isProblem)
                    GestureDetector(
                      onTap: () async {
                        final file = await _storageService.pickImage(
                          ImageSource.camera,
                        );
                        if (file != null) {
                          setDialogState(() => photoFile = file);
                        }
                      },
                      child: Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: photoFile == null
                            ? const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.camera_alt),
                                  Text("FOTO BUKTI (WAJIB)"),
                                ],
                              )
                            : Image.file(photoFile!, fit: BoxFit.cover),
                      ),
                    ),

                  if (isSubmitting)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
            actions: [
              if (!isSubmitting)
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Batal"),
                ),

              if (!isSubmitting)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isProblem ? Colors.red : Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    // Validasi
                    if (isProblem && photoFile == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Wajib sertakan foto jika ada masalah!",
                          ),
                        ),
                      );
                      return;
                    }

                    setDialogState(() => isSubmitting = true);
                    try {
                      String? imageUrl;
                      if (photoFile != null) {
                        imageUrl = await _storageService.uploadEvidence(
                          photoFile!,
                          'classroom_issues',
                        );
                      }

                      await _service.submitClassReception(
                        stopId: _deliveryData!['id'],
                        className: _className,
                        qty: int.tryParse(qtyController.text) ?? 0,
                        notes: noteController.text,
                        issueType: isProblem ? 'food_quality_issue' : null,
                        proofUrl: imageUrl,
                      );

                      if (!mounted) return;
                      Navigator.pop(ctx);
                      _fetchData();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Laporan Kelas Berhasil!"),
                        ),
                      );
                    } catch (e) {
                      setDialogState(() => isSubmitting = false);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("Error: $e")));
                    }
                  },
                  child: const Text("Simpan Laporan"),
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
        title: Text("Wali Kelas $_className"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30), // Ikon Profil
            tooltip: "Profil Saya",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _deliveryData == null
          ? const Center(child: Text("Belum ada jadwal pengiriman."))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    // Status Pengiriman Global (dari tabel delivery_stops)
    final String status = _deliveryData!['status'];

    String message = "Makanan sedang diproses.";
    Color color = Colors.grey;
    bool canReceive = false;

    if (status == 'completed') {
      message =
          "Makanan sudah tiba di Sekolah.\nMenunggu pengecekan Koordinator.";
      color = Colors.orange;
    } else if (status == 'received' || status == 'issue_reported') {
      // Kalau Koordinator sudah terima (baik aman atau ada masalah kemasan),
      // Wali Kelas tetap boleh ambil jatahnya.
      message = "Makanan SIAP DIBAGIKAN KE SISWA.";
      color = Colors.green;
      canReceive = true;
    }

    if (_alreadyReceived) {
      message = "Laporan kelas Anda sudah masuk.\nTerima kasih.";
      color = Colors.blue;
      canReceive = false;
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: color.withOpacity(0.1),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: color),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    _alreadyReceived ? Icons.check_circle : Icons.local_dining,
                    size: 50,
                    color: color,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),

          if (canReceive)
            ElevatedButton.icon(
              onPressed: _showReceiveDialog,
              icon: const Icon(Icons.inventory),
              label: const Text("TERIMA & CEK KUALITAS MAKANAN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
        ],
      ),
    );
  }
}
