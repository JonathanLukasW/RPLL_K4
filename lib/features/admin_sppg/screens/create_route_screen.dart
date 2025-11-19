import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Jangan lupa: flutter pub add intl

// Import Models
import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
// Import Services
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/route_service.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();

  // --- Services ---
  final SchoolService _schoolService = SchoolService();
  final VehicleService _vehicleService = VehicleService();
  final CourierService _courierService = CourierService();
  
  // --- Data Sources (List Pilihan) ---
  List<School> _availableSchools = [];
  List<Vehicle> _availableVehicles = [];
  List<CourierModel> _availableCouriers = [];
  
  // --- Form State (Data yang dipilih user) ---
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1)); // Default Besok
  String? _selectedVehicleId;
  String? _selectedCourierId;
  final List<School> _selectedSchools = []; // Sekolah yang dicentang

  bool _isLoadingData = true; // Loading awal (ambil data dropdown)
  bool _isSubmitting = false; // Loading saat simpan

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  // 1. AMBIL SEMUA DATA (Mobil, Kurir, Sekolah) SEKALIGUS
  Future<void> _fetchAllData() async {
    try {
      // Future.wait biar jalan paralel (lebih cepat)
      final results = await Future.wait([
        _schoolService.getMySchools(),
        _vehicleService.getMyVehicles(),
        _courierService.getMyCouriers(),
      ]);

      if (!mounted) return;

      setState(() {
        _availableSchools = results[0] as List<School>;
        _availableVehicles = results[1] as List<Vehicle>;
        _availableCouriers = results[2] as List<CourierModel>;
        _isLoadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal memuat data: $e")));
      setState(() => _isLoadingData = false);
    }
  }

  // 2. FUNGSI PILIH TANGGAL
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // 3. LOGIKA CENTANG SEKOLAH
  void _toggleSchool(School school, bool? isChecked) {
    setState(() {
      if (isChecked == true) {
        _selectedSchools.add(school);
      } else {
        _selectedSchools.removeWhere((element) => element.id == school.id);
      }
    });
  }

  // 4. SIMPAN RUTE
  Future<void> _submitRoute() async {
    if (_formKey.currentState!.validate()) {
      // Validasi Manual: Sekolah harus dipilih minimal 1
      if (_selectedSchools.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pilih minimal satu sekolah tujuan!")),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        await RouteService().createRoute(
          vehicleId: _selectedVehicleId!,
          courierId: _selectedCourierId!,
          date: _selectedDate,
          selectedSchools: _selectedSchools,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Rute Pengiriman Berhasil Dibuat!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Balik ke dashboard bawa sinyal sukses

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buat Rute Pengiriman"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- BAGIAN 1: TANGGAL ---
                    const Text("Tanggal Pengiriman", style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_selectedDate), // Pake library intl
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),

                    // --- BAGIAN 2: ARMADA & KURIR ---
                    Row(
                      children: [
                        // Dropdown Mobil
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: "Pilih Mobil", border: OutlineInputBorder()),
                            value: _selectedVehicleId,
                            items: _availableVehicles.map((v) {
                              return DropdownMenuItem(
                                value: v.id,
                                child: Text(v.plateNumber, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedVehicleId = val),
                            validator: (val) => val == null ? "Wajib isi" : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Dropdown Kurir
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(labelText: "Pilih Kurir", border: OutlineInputBorder()),
                            value: _selectedCourierId,
                            items: _availableCouriers.map((c) {
                              return DropdownMenuItem(
                                value: c.id,
                                child: Text(c.name, overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCourierId = val),
                            validator: (val) => val == null ? "Wajib isi" : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    const Divider(thickness: 2),
                    
                    // --- BAGIAN 3: PILIH SEKOLAH ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Pilih Sekolah Tujuan", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("${_selectedSchools.length} Dipilih", style: TextStyle(color: Colors.orange[800], fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      height: 300, // Tinggi fixed biar bisa discroll list sekolahnya
                      child: _availableSchools.isEmpty 
                        ? const Center(child: Text("Belum ada data sekolah."))
                        : ListView.separated(
                            itemCount: _availableSchools.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final school = _availableSchools[index];
                              final isSelected = _selectedSchools.any((s) => s.id == school.id);
                              
                              return CheckboxListTile(
                                title: Text(school.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text("Siswa: ${school.studentCount} | Alamat: ${school.address ?? '-'}"),
                                value: isSelected,
                                activeColor: Colors.orange[800],
                                onChanged: (bool? val) => _toggleSchool(school, val),
                                secondary: isSelected 
                                    ? const Icon(Icons.check_circle, color: Colors.orange) 
                                    : const Icon(Icons.circle_outlined, color: Colors.grey),
                              );
                            },
                          ),
                    ),

                    const SizedBox(height: 20),

                    // --- TOMBOL SIMPAN ---
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRoute,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                "SIMPAN RUTE & TUGASKAN KURIR",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
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