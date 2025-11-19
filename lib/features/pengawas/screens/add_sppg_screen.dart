import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// Pastikan file ini ada di folder yang sama
import 'location_picker_screen.dart'; 
// Pastikan path ini benar menuju service yang baru diperbaiki di atas
import '../services/sppg_service.dart'; 

class AddSppgScreen extends StatefulWidget {
  const AddSppgScreen({super.key});

  @override
  State<AddSppgScreen> createState() => _AddSppgScreenState();
}

class _AddSppgScreenState extends State<AddSppgScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  bool _isSubmitting = false;

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
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Koordinat berhasil diambil dari Peta!")),
      );
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true); 

      try {
        final Map<String, dynamic> newData = {
          "name": _nameController.text,
          "email": _emailController.text,
          "phone": _phoneController.text,
          "address": _addressController.text,
          "gps_lat": double.tryParse(_latController.text),
          "gps_long": double.tryParse(_longController.text),
        };

        // Memanggil fungsi createSppg yang sudah ada lagi di Service
        await SppgService().createSppg(newData);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Berhasil Mendaftarkan SPPG Baru!"),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);

      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menyimpan: $e"),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Registrasi SPPG Baru"),
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
              const Text("Informasi Dasar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nama SPPG / Dapur", border: OutlineInputBorder(), prefixIcon: Icon(Icons.store)),
                validator: (value) => value!.isEmpty ? "Nama wajib diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email Admin SPPG", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: "Nomor Telepon / WA", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: "Alamat Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                maxLines: 3,
                validator: (value) => value!.isEmpty ? "Alamat wajib diisi" : null,
              ),
              const SizedBox(height: 30),
              const Divider(thickness: 2),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Titik Koordinat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("Buka Peta"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(labelText: "Latitude", border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) => value!.isEmpty ? "Wajib diisi" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _longController,
                      decoration: const InputDecoration(labelText: "Longitude", border: OutlineInputBorder()),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      validator: (value) => value!.isEmpty ? "Wajib diisi" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[800], padding: const EdgeInsets.symmetric(vertical: 16)),
                  child: _isSubmitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("SIMPAN AKUN SPPG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}