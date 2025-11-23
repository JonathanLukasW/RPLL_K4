import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart'; 
import '../../pengawas/screens/location_picker_screen.dart';
import '../services/school_service.dart';
import '../../../models/school_model.dart'; // Import Model Sekolah

class AddSchoolScreen extends StatefulWidget {
  final School? schoolToEdit; // Data sekolah (Kalau null = Mode Tambah)

  const AddSchoolScreen({super.key, this.schoolToEdit});

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
  
  // Controller VRP
  final TextEditingController _toleranceController = TextEditingController(text: "45"); 
  final TextEditingController _menuDefaultController = TextEditingController(); 
  
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  // --- State Variables ---
  bool _isHighRisk = false;     
  TimeOfDay? _deadlineTime;     
  bool _isSubmitting = false;   

  @override
  void initState() {
    super.initState();
    // [LOGIKA EDIT]: Kalau ada data schoolToEdit, isi form-nya
    if (widget.schoolToEdit != null) {
      final s = widget.schoolToEdit!;
      _nameController.text = s.name;
      _addressController.text = s.address ?? '';
      _studentCountController.text = s.studentCount.toString();
      _serviceTimeController.text = s.serviceTimeMinutes.toString();
      _toleranceController.text = s.toleranceMinutes.toString();
      _menuDefaultController.text = s.menuDefault ?? '';
      _isHighRisk = s.isHighRisk;
      
      if (s.latitude != null) _latController.text = s.latitude.toString();
      if (s.longitude != null) _longController.text = s.longitude.toString();

      // Parsing Jam (String "12:00:00" -> TimeOfDay)
      if (s.deadlineTime != null) {
        final parts = s.deadlineTime!.split(':');
        _deadlineTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
  }

  // --- 1. Fungsi Pilih Jam ---
  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _deadlineTime ?? const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked != null) {
      setState(() => _deadlineTime = picked);
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

  // --- 3. Submit ke Database (Bisa Create atau Update) ---
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

        final Map<String, dynamic> data = {
          'name': _nameController.text,
          'address': _addressController.text,
          'student_count': int.parse(_studentCountController.text),
          'service_time_minutes': int.parse(_serviceTimeController.text),
          'deadline_time': formattedTime,
          'is_high_risk': _isHighRisk,
          'gps_lat': double.tryParse(_latController.text),
          'gps_long': double.tryParse(_longController.text),
          'tolerance_minutes': int.parse(_toleranceController.text), 
          'menu_default': _menuDefaultController.text,
        };

        if (widget.schoolToEdit == null) {
          // Mode TAMBAH
          await SchoolService().createSchool(data);
        } else {
          // Mode EDIT
          await SchoolService().updateSchool(widget.schoolToEdit!.id, data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Data Sekolah berhasil ${widget.schoolToEdit == null ? 'ditambahkan' : 'diperbarui'}!"), 
            backgroundColor: Colors.green
          ),
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
    final isEdit = widget.schoolToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Sekolah" : "Tambah Sekolah"),
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
                  decoration: const InputDecoration(labelText: "Deadline Konsumsi", border: OutlineInputBorder(), prefixIcon: Icon(Icons.access_time)),
                  child: Text(_deadlineTime == null ? "Pilih Jam..." : "${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(color: _deadlineTime == null ? Colors.grey : Colors.black, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Toleransi
              TextFormField(
                controller: _toleranceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Toleransi Awal (Menit)", hintText: "45", prefixIcon: Icon(Icons.fast_forward)),
                validator: (v) => v!.isEmpty ? "Wajib" : null,
              ),
              const SizedBox(height: 15),

              // Menu Default
              TextFormField(
                controller: _menuDefaultController,
                decoration: const InputDecoration(labelText: "Menu Default", hintText: "Nasi, Ayam", prefixIcon: Icon(Icons.restaurant_menu)),
              ),
              const SizedBox(height: 15),

              // High Risk
              SwitchListTile(
                title: const Text("Status High Risk"),
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
                  const Text("Titik GPS", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  Expanded(child: TextFormField(controller: _latController, decoration: const InputDecoration(labelText: "Lat", hintText: "Wajib dari Peta"), readOnly: true)),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _longController, decoration: const InputDecoration(labelText: "Long", hintText: "Wajib dari Peta"), readOnly: true)),
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
                    : Text(isEdit ? "SIMPAN PERUBAHAN" : "SIMPAN DATA BARU", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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