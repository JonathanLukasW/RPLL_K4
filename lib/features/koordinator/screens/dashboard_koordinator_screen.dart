import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../autentikasi/screens/login_screen.dart';
import '../services/receiving_service.dart';
// Import Storage Service baru
import '../../../core/services/storage_service.dart'; 
import '../../../core/screens/profile_screen.dart';

// [BARU] Import Layar Request Koordinator
import 'coordinator_request_screen.dart'; 

class DashboardKoordinatorScreen extends StatefulWidget {
  const DashboardKoordinatorScreen({super.key});

  @override
  State<DashboardKoordinatorScreen> createState() => _DashboardKoordinatorScreenState();
}

class _DashboardKoordinatorScreenState extends State<DashboardKoordinatorScreen> {
  final ReceivingService _service = ReceivingService();
  final StorageService _storageService = StorageService();
  
  Map<String, dynamic>? _deliveryData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getTodayDelivery();
      if (mounted) setState(() => _deliveryData = data);
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

  // --- LOGIKA DIALOG KONFIRMASI / LAPOR MASALAH ---
  void _showConfirmationDialog(String stopId) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    
    File? photoFile;
    bool isProblem = false; 
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Konfirmasi Penerimaan"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Pilihan Status
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("✅ Aman"),
                            selected: !isProblem,
                            selectedColor: Colors.green[100],
                            onSelected: (val) => setDialogState(() => isProblem = !val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Text("⚠️ Masalah"),
                            selected: isProblem,
                            selectedColor: Colors.red[100],
                            onSelected: (val) => setDialogState(() => isProblem = val),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Jml Diterima", border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 10),
                    
                    TextField(
                      controller: noteController,
                      decoration: InputDecoration(
                        labelText: isProblem ? "Jelaskan Kerusakan/Kekurangan" : "Catatan (Opsional)", 
                        border: const OutlineInputBorder()
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 10),

                    // Tombol Kamera
                    if (isProblem)
                      GestureDetector(
                        onTap: () async {
                          final file = await _storageService.pickImage(ImageSource.camera);
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
                                  children: [Icon(Icons.camera_alt), Text("Ambil Foto Bukti")],
                                )
                              : Image.file(photoFile!, fit: BoxFit.cover),
                        ),
                      ),
                      
                     if (isSubmitting)
                       const Padding(
                         padding: EdgeInsets.only(top: 15),
                         child: CircularProgressIndicator(),
                       )
                  ],
                ),
              ),
              actions: [
                if (!isSubmitting)
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
                
                if (!isSubmitting)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isProblem ? Colors.red : Colors.teal,
                      foregroundColor: Colors.white
                    ),
                    onPressed: () async {
                      if (isProblem && photoFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wajib sertakan foto jika ada masalah!")));
                        return;
                      }
                      
                      setDialogState(() => isSubmitting = true);

                      try {
                        String? imageUrl;
                        if (photoFile != null) {
                          imageUrl = await _storageService.uploadEvidence(photoFile!, 'stops');
                        }

                        await _service.confirmReception(
                          stopId: stopId,
                          receivedQty: int.tryParse(qtyController.text) ?? 0,
                          notes: isProblem ? "[MASALAH] ${noteController.text}" : noteController.text,
                          recipientName: "Koordinator", 
                          issueType: isProblem ? 'problem' : null,
                          proofUrl: imageUrl,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        _fetchData(); 
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan Terkirim!")));

                      } catch (e) {
                         setDialogState(() => isSubmitting = false);
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
                      }
                    },
                    child: Text(isProblem ? "Lapor Masalah" : "Terima Barang"),
                  )
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Portal Sekolah"),
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          // [BARU] Tombol Pengajuan Perubahan (Request)
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: "Ajukan Perubahan",
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CoordinatorRequestScreen()),
              );
            },
          ),
          
          // Tombol Profil
          IconButton(
            icon: const Icon(Icons.account_circle, size: 30), 
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
            ? const Center(child: Text("Tidak ada jadwal pengiriman hari ini."))
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildStatusCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildStatusCard() {
    final status = _deliveryData!['status'];
    final vehicle = _deliveryData!['delivery_routes']['vehicles'];
    final plat = vehicle != null ? vehicle['plate_number'] : '-';
    
    Color statusColor = Colors.grey;
    String statusText = "Menunggu";
    
    if (status == 'completed') { 
      statusColor = Colors.orange;
      statusText = "Barang Tiba - Perlu Konfirmasi";
    } else if (status == 'received') {
      statusColor = Colors.green;
      statusText = "Selesai - Diterima";
    } else if (status == 'issue_reported') { 
      statusColor = Colors.red;
      statusText = "Masalah Dilaporkan";
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, size: 40, color: statusColor),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Pengiriman Hari Ini", style: TextStyle(fontSize: 14, color: Colors.grey)),
                      Text(statusText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 30),
            Text("Mobil: $plat", style: const TextStyle(fontSize: 16)),
            
            const SizedBox(height: 20),
            
            if (status == 'completed')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showConfirmationDialog(_deliveryData!['id']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("KONFIRMASI PENERIMAAN"),
                ),
              )
          ],
        ),
      ),
    );
  }
}