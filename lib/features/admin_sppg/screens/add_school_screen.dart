import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
// Import Peta yang kemarin kita buat (Lokasinya ada di folder pengawas)
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
  final TextEditingController _serviceTimeController = TextEditingController(text: "10"); // Default 10 menit
  
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _longController = TextEditingController();

  // --- State Variables ---
  bool _isHighRisk = false;     // Untuk Checkbox High Risk
  TimeOfDay? _deadlineTime;     // Untuk nyimpen jam deadline
  bool _isSubmitting = false;   // Loading state

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

  // --- 2. Fungsi Buka Peta (Reuse Peta Kemarin) ---
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
        // Format TimeOfDay ke String "HH:mm:ss" buat Supabase
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
          // 'sppg_id' akan diisi otomatis oleh Service di backend
        };

        await SchoolService().createSchool(newSchoolData);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sekolah berhasil ditambahkan!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Balik bawa sinyal sukses

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Sekolah Mitra"),
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
              const Text("Data Sekolah", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),

              // Nama Sekolah
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Sekolah",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.school),
                ),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),

              // Jumlah Siswa & Service Time (Sebelah-sebelahan)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _studentCountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Jml Siswa",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.people),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _serviceTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Waktu Layanan (Menit)",
                        hintText: "10",
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.timer),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib" : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // Deadline Picker (Pilih Jam)
              InkWell(
                onTap: _pickTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: "Deadline Pengiriman (Jam Makan Siang)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.access_time),
                  ),
                  child: Text(
                    _deadlineTime == null 
                        ? "Pilih Jam..." 
                        : "${_deadlineTime!.hour.toString().padLeft(2, '0')}:${_deadlineTime!.minute.toString().padLeft(2, '0')}",
                    style: TextStyle(
                      color: _deadlineTime == null ? Colors.grey : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // High Risk Switch
              SwitchListTile(
                title: const Text("Lokasi High Risk?"),
                subtitle: const Text("Aktifkan jika akses sulit, rawan macet, atau butuh penanganan khusus."),
                value: _isHighRisk,
                activeColor: Colors.red,
                onChanged: (val) => setState(() => _isHighRisk = val),
                contentPadding: EdgeInsets.zero,
              ),
              
              const Divider(thickness: 2),
              const SizedBox(height: 10),

              // --- BAGIAN LOKASI ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Lokasi Sekolah", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ElevatedButton.icon(
                    onPressed: _openMapPicker,
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text("Buka Peta"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[700], foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              
              // Alamat Teks
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Alamat Lengkap",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
              ),
              const SizedBox(height: 10),

              // Koordinat
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _latController, decoration: const InputDecoration(labelText: "Lat", border: OutlineInputBorder()))),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: _longController, decoration: const InputDecoration(labelText: "Long", border: OutlineInputBorder()))),
                ],
              ),

              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800], 
                    padding: const EdgeInsets.symmetric(vertical: 15)
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SIMPAN DATA SEKOLAH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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