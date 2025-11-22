import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; 
import '../../pengawas/screens/location_picker_screen.dart';
import '../services/school_service.dart';

class AddSchoolScreen extends StatefulWidget {
  const AddSchoolScreen({super.key});

  @override
  State<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends State<AddSchoolScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Controllers ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _studentCountController = TextEditingController();
  final TextEditingController _serviceTimeController = TextEditingController(text: "10"); 
  
  // [BARU] Controller untuk data VRP tambahan
  final TextEditingController _toleranceController = TextEditingController(text: "45"); 
  final TextEditingController _menuDefaultController = TextEditingController(); 
  
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  // --- State Variables ---
  bool _isHighRisk = false;     
  TimeOfDay? _deadlineTime;     
  bool _isSubmitting = false;   

  // --- 1. Fungsi Pilih Jam (Time Picker) ---
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() {
        _deadlineTime = picked;
      });
    }
  }

  // --- 2. Fungsi Buka Peta ---
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
        const SnackBar(content: Text("Lokasi Sekolah terpilih!")),
      );
    }
  }

  // --- 3. Submit ke Database ---
  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_deadlineTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Harap tentukan Jam Deadline Pengiriman!")),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final String formattedTime = 
            "${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}:00";

        final Map<String, dynamic> newSchoolData = {
          'name': _nameController.text,
          'address': _addressController.text,
          'student_count': int.parse(_studentCountController.text),
          'service_time_minutes': int.parse(_serviceTimeController.text),
          'deadline_time': formattedTime,
          'is_high_risk': _isHighRisk,
          'gps_lat': double.tryParse(_latController.text),
          'gps_long': double.tryParse(_longController.text),
          // [BARU] Data VRP Constraints
          'tolerance_minutes': int.parse(_toleranceController.text), 
          'menu_default': _menuDefaultController.text,
        };

        await SchoolService().createSchool(newSchoolData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sekolah berhasil ditambahkan!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); 

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _studentCountController.dispose();
    _serviceTimeController.dispose();
    _toleranceController.dispose();
    _menuDefaultController.dispose();
    _latController.dispose();
    _longController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Lokasi Penerima Manfaat"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Data Umum", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Nama Sekolah
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nama Lokasi Penerima", prefixIcon: Icon(Icons.school)), validator: (v) => v!.isEmpty ? "Wajib diisi" : null),
              const SizedBox(height: 15),

              // Alamat Teks
              TextFormField(controller: _addressController, maxLines: 2, decoration: const InputDecoration(labelText: "Alamat Lengkap", prefixIcon: Icon(Icons.home))),
              const SizedBox(height: 15),

              // Jumlah Siswa & Service Time
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _studentCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Jml Penerima", prefixIcon: Icon(Icons.people)),
                      validator: (v) => v!.isEmpty ? "Wajib" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _serviceTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Waktu Service (Menit)", prefixIcon: Icon(Icons.timer)),
                      validator: (v) => v!.isEmpty ? "Wajib" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),
              const Divider(thickness: 2),

              // --- BAGIAN CONSTRAINTS VRP ---
              const Text("Batasan Waktu (VRP Constraints)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Deadline Picker
              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: "Deadline Konsumsi (Waktu Wajib Tiba)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                  child: Text(_deadlineTime == null ? "Pilih Jam..." : "${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(color: _deadlineTime == null ? Colors.grey : Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Toleransi Kedatangan Awal (Menit)
              TextFormField(
                controller: _toleranceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Toleransi Kedatangan Awal (Menit)", hintText: "Misal: 45", prefixIcon: Icon(Icons.fast_forward)),
                validator: (v) => v!.isEmpty ? "Wajib" : null,
              ),
              const SizedBox(height: 15),

              // [BARU] Menu Default
              TextFormField(
                controller: _menuDefaultController,
                decoration: const InputDecoration(
                  labelText: "Jenis Menu Default",
                  hintText: "Contoh: Nasi, Ayam, Sayur",
                  prefixIcon: Icon(Icons.restaurant_menu)
                ),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),


              // High Risk Switch
              SwitchListTile(
                title: const Text("Status Risiko Tinggi (High Risk)"),
                subtitle: const Text("Toleransi dan pengiriman akan diprioritaskan."),
                value: _isHighRisk,
                activeColor: Colors.red,
                onChanged: (val) => setState(() => _isHighRisk = val),
                contentPadding: EdgeInsets.zero,
              ),
              
              const Divider(thickness: 2),
              const SizedBox(height: 10),

              // --- BAGIAN LOKASI MAP ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Titik GPS Lokasi", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("Buka Peta"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _latController, decoration: const InputDecoration(labelText: "Latitude", hintText: "Harus diisi dari peta"), readOnly: true)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _longController, decoration: const InputDecoration(labelText: "Longitude", hintText: "Harus diisi dari peta"), readOnly: true)),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SIMPAN DATA LOKASI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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