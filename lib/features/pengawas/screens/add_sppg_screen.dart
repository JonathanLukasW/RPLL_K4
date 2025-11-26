import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Wajib import ini

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

  // --- DATA DAPUR ---
  final _sppgNameController = TextEditingController();
  final _sppgAddressController = TextEditingController();
  
  // Lokasi
  final _latController = TextEditingController();
  final _longController = TextEditingController();

  // --- DATA ADMIN (Hanya untuk Mode Tambah) ---
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
      if (s.latitude != null) _latController.text = s.latitude.toString();
      if (s.longitude != null) _longController.text = s.longitude.toString();
    }
  }

  Future<void> _openMapPicker() async {
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
      setState(() => _isSubmitting = true); 

      try {
        // Siapkan Data SPPG
        final Map<String, dynamic> sppgData = {
          "name": _sppgNameController.text,
          "address": _sppgAddressController.text,
          "gps_lat": double.tryParse(_latController.text),
          "gps_long": double.tryParse(_longController.text),
        };

        if (widget.sppgToEdit == null) {
          // --- MODE TAMBAH (Create SPPG + Create Admin) ---
          
          // Validasi data admin
          if (_adminEmailController.text.isEmpty || _adminPasswordController.text.isEmpty) {
             throw Exception("Email & Password Admin wajib diisi untuk pendaftaran baru.");
          }

          // [FIX]: Panggil client langsung dari Supabase.instance, jangan lewat service private
          final supabase = Supabase.instance.client; 
          
          // 1. Insert SPPG dan ambil ID-nya
          final sppgRes = await supabase.from('sppgs').insert(sppgData).select().single();
          final String newSppgId = sppgRes['id'];

          // 2. Buat Akun Admin yang terhubung ke SPPG tadi
          await SppgService().createSppgUser(
             email: _adminEmailController.text,
             password: _adminPasswordController.text,
             sppgId: newSppgId,
             sppgName: _sppgNameController.text,
             fullName: _adminNameController.text,
          );

        } else {
          // --- MODE EDIT (Update SPPG Only) ---
          // Admin tidak diedit di sini (karena butuh flow Auth khusus)
          await SppgService().updateSppg(widget.sppgToEdit!.id, sppgData);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.sppgToEdit == null ? "SPPG Baru Berhasil!" : "Data SPPG Diperbarui!"), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context, true); // Balik ke list

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
              
              TextFormField(
                controller: _sppgNameController, 
                decoration: const InputDecoration(labelText: "Nama SPPG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)), 
                validator: (v) => v!.isEmpty ? "Wajib" : null
              ),
              const SizedBox(height: 10),
              
              TextFormField(
                controller: _sppgAddressController, 
                maxLines: 2, 
                decoration: const InputDecoration(labelText: "Alamat SPPG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)), 
                validator: (v) => v!.isEmpty ? "Wajib" : null
              ),
              
              const SizedBox(height: 15),
              Row(children: [
                Expanded(child: ElevatedButton.icon(onPressed: _openMapPicker, icon: const Icon(Icons.map), label: const Text("Pilih Lokasi Map"))),
              ]),
              if (_latController.text.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("GPS: ${_latController.text}, ${_longController.text}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),

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