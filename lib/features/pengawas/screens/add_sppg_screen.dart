import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Untuk DatePicker
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 

import 'location_picker_screen.dart'; 
import '../services/sppg_service.dart'; 
import '../../../models/sppg_model.dart'; // Import Model

class AddSppgScreen extends StatefulWidget {
  final Sppg? sppgToEdit; // Data untuk diedit (Null = Mode Tambah)

  const AddSppgScreen({super.key, this.sppgToEdit});

  @override
  State<AddSppgScreen> createState() => _AddSppgScreenState();
}

class _AddSppgScreenState extends State<AddSppgScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- DATA DAPUR (SPPG) ---
  final _sppgNameController = TextEditingController();
  final _sppgAddressController = TextEditingController();
  final _sppgPhoneController = TextEditingController();
  final _sppgEmailController = TextEditingController(); 
  DateTime? _establishedDate;
  
  // Lokasi (Sekarang bisa diedit manual)
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  // --- DATA ADMIN (Personal) ---
  final _adminNameController = TextEditingController();
  final _adminEmailController = TextEditingController(); 
  final _adminPasswordController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // [LOGIKA EDIT] Isi form jika ada data
    if (widget.sppgToEdit != null) {
      final s = widget.sppgToEdit!;
      _sppgNameController.text = s.name;
      _sppgAddressController.text = s.address ?? '';
      _sppgPhoneController.text = s.phone ?? '';
      _sppgEmailController.text = s.email ?? '';
      
      if (s.establishedDate != null) {
        try {
          _establishedDate = DateTime.parse(s.establishedDate!);
        } catch (_) {}
      }

      if (s.latitude != null) _latController.text = s.latitude.toString();
      if (s.longitude != null) _longController.text = s.longitude.toString();
    }
  }

  Future<void> _pickDate(bool isEstablishedDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isEstablishedDate) {
          _establishedDate = picked;
        }
      });
    }
  }

  Future<void> _openMapPicker() async {
    // Ambil nilai awal dari inputan manual (kalau user udah ngetik)
    double initialLat = double.tryParse(_latController.text) ?? -6.9175; 
    double initialLong = double.tryParse(_longController.text) ?? 107.6191;

    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          initialLat: initialLat,
          initialLong: initialLong,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        // Isi otomatis ke kolom input
        _latController.text = result.latitude.toString();
        _longController.text = result.longitude.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Koordinat berhasil diambil dari Peta!")),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      
      // Validasi Tanggal hanya saat Mode Tambah (Opsional saat edit)
      if (widget.sppgToEdit == null && _establishedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Isi Tanggal Berdiri SPPG")));
        return;
      }

      setState(() => _isSubmitting = true); 

      try {
        // 1. Siapkan Data SPPG
        final Map<String, dynamic> sppgData = {
          "name": _sppgNameController.text.trim(),
          "address": _sppgAddressController.text.trim(),
          "email": _sppgEmailController.text.trim(),
          "phone": _sppgPhoneController.text.trim(),
          // Ambil dari Controller (bisa hasil peta atau ketikan manual)
          "gps_lat": double.tryParse(_latController.text),
          "gps_long": double.tryParse(_longController.text),
        };

        // Masukkan tanggal hanya jika diisi (biar aman pas edit)
        if (_establishedDate != null) {
          sppgData["established_date"] = DateFormat('yyyy-MM-dd').format(_establishedDate!);
        }

        if (widget.sppgToEdit == null) {
          // --- MODE TAMBAH ---
          if (_adminEmailController.text.isEmpty || _adminPasswordController.text.isEmpty) {
             throw Exception("Email & Password Admin wajib diisi.");
          }

          final supabase = Supabase.instance.client; 
          final sppgRes = await supabase.from('sppgs').insert(sppgData).select().single();
          final String newSppgId = sppgRes['id'];

          // Create Admin
          await SppgService().createSppgUser(
             email: _adminEmailController.text.trim(),
             password: _adminPasswordController.text,
             sppgId: newSppgId,
             sppgName: _sppgNameController.text,
             fullName: _adminNameController.text.trim(),
          );

        } else {
          // --- MODE EDIT ---
          await SppgService().updateSppg(widget.sppgToEdit!.id, sppgData);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.sppgToEdit == null ? "SPPG Baru Berhasil!" : "Data SPPG Diperbarui!"), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context, true); 

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _sppgNameController.dispose(); 
    _sppgAddressController.dispose(); 
    _sppgPhoneController.dispose();
    _sppgEmailController.dispose();
    _latController.dispose(); 
    _longController.dispose();
    _adminNameController.dispose(); 
    _adminEmailController.dispose(); 
    _adminPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.sppgToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit SPPG" : "Tambah Akun SPPG"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("1. Detail SPPG (Dapur)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
              const SizedBox(height: 15),
              
              TextFormField(controller: _sppgNameController, decoration: const InputDecoration(labelText: "Nama SPPG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)), validator: (v) => v!.isEmpty ? "Wajib" : null),
              const SizedBox(height: 10),
              
              TextFormField(controller: _sppgAddressController, maxLines: 2, decoration: const InputDecoration(labelText: "Alamat SPPG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)), validator: (v) => v!.isEmpty ? "Wajib" : null),
              const SizedBox(height: 10),

              InkWell(
                onTap: () => _pickDate(true),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Tanggal Berdiri", border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                  child: Text(_establishedDate == null ? "Pilih Tanggal" : DateFormat('dd MMM yyyy').format(_establishedDate!)),
                ),
              ),
              const SizedBox(height: 10),

              TextFormField(controller: _sppgPhoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Telepon Kantor", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)), validator: (v) => v!.isEmpty ? "Wajib" : null),
              const SizedBox(height: 10),
              TextFormField(controller: _sppgEmailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email Kantor (Opsional)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
              
              const SizedBox(height: 20),
              
              // --- [BARU] Input Lat/Long Manual + Tombol Peta ---
              const Text("Titik Koordinat (GPS)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text("Isi manual atau gunakan tombol 'Buka Peta'", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: "Latitude", 
                        hintText: "-6.xxxx",
                        border: OutlineInputBorder()
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _longController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(
                        labelText: "Longitude", 
                        hintText: "107.xxxx",
                        border: OutlineInputBorder()
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _openMapPicker, 
                  icon: const Icon(Icons.map), 
                  label: const Text("Ambil dari Peta (Otomatis)"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[900]
                  ),
                ),
              ),
              // --------------------------------------------------

              const SizedBox(height: 30),
              const Divider(thickness: 2),
              
              // BAGIAN ADMIN HANYA MUNCUL SAAT TAMBAH BARU
              if (!isEdit) ...[
                const Text("2. Akun Admin SPPG", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                const SizedBox(height: 15),
                TextFormField(controller: _adminNameController, decoration: const InputDecoration(labelText: "Nama Lengkap Admin", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)), validator: (v) => v!.isEmpty ? "Wajib" : null),
                const SizedBox(height: 15),
                TextFormField(controller: _adminEmailController, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email Login", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)), validator: (v) => v!.isEmpty ? "Wajib" : null),
                const SizedBox(height: 10),
                TextFormField(controller: _adminPasswordController, obscureText: true, decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)), validator: (v) => v!.length < 6 ? "Min 6 karakter" : null),
                const SizedBox(height: 40),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEdit ? "SIMPAN PERUBAHAN" : "SIMPAN", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}