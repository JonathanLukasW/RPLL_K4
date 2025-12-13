import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/courier_model.dart';
import '../../../models/menu_model.dart';
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/menu_service.dart';
import '../services/route_service.dart';
import 'edit_route_screen.dart'; // Import biar bisa langsung navigasi ke detail

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final RouteService _routeService = RouteService();

  // --- STATE DATA ---
  DateTime _selectedDate = DateTime.now();
  List<School> _allSchools = [];
  List<Vehicle> _availableVehicles = [];
  List<School> _selectedSchools = [];
  Vehicle? _selectedVehicle; // Hanya bisa 1 mobil per rute

  // Menu data yang akan di-set berdasarkan sekolah yang dipilih
  int _bottleneckDuration = 0; // Durasi masak terlama (dalam menit)
  List<String> _requiredMenuIds = []; // ID menu unik yang dibutuhkan
  List<String> _requiredMenuNames = []; // Nama menu

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final results = await Future.wait([
        SchoolService().getMySchools(),
        VehicleService().getMyVehicles(),
        _getRoutesBySelectedDate(
          _selectedDate,
        ), // Ambil rute yang sudah terpakai
      ]);

      final allSchools = results[0] as List<School>;
      final allVehicles = results[1] as List<Vehicle>;
      final routesOnDate = results[2] as List<Map<String, dynamic>>;

      // Filter mobil yang AKTIF dan BELUM terpakai di tanggal ini
      final usedVehicleIds = routesOnDate
          .map((r) => r['vehicle_id'].toString())
          .toSet();
      final availableVehicles = allVehicles
          .where((v) => v.isActive && !usedVehicleIds.contains(v.id))
          .toList();

      if (!mounted) return;
      setState(() {
        _allSchools = allSchools;
        _availableVehicles = availableVehicles;
        _isLoading = false;

        // Atur default selected vehicle ke yang pertama tersedia
        if (availableVehicles.isNotEmpty) {
          _selectedVehicle = availableVehicles.first;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal memuat data: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<Map<String, dynamic>>> _getRoutesBySelectedDate(
    DateTime date,
  ) async {
    return await _routeService.getRoutesByDate(date);
  }

  // Dipanggil saat tanggal diubah
  void _onDateChanged(DateTime newDate) {
    if (newDate.isBefore(DateTime.now().subtract(const Duration(hours: 24)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Jadwal harus hari ini atau ke depan, Goblok!"),
        ),
      );
      return;
    }
    setState(() {
      _selectedDate = newDate;
      _selectedSchools = []; // Clear selection
      _selectedVehicle = null; // Clear vehicle selection to refilter
      _bottleneckDuration = 0;
      _requiredMenuIds = [];
      _requiredMenuNames = [];
      _isLoading = true;
    });
    _fetchInitialData(); // Re-fetch data untuk filter ketersediaan mobil
  }

  // Dipanggil saat ada perubahan sekolah yang dipilih
  Future<void> _onSchoolSelectionChanged() async {
    if (_selectedSchools.isEmpty) {
      setState(() {
        _bottleneckDuration = 0;
        _requiredMenuIds = [];
        _requiredMenuNames = [];
      });
      return;
    }

    // Perhitungan Bottleneck Menu (Menu yang butuh waktu masak terlama)
    try {
      // >>> UBAH: Panggil service untuk menganalisis Menu Set yang terlibat <<<
      final result = await _routeService.getBottleneckMenuSetInfo(
        _selectedSchools,
      );

      // Hasilnya sekarang adalah: {duration: int, menuIds: List<String>, menuSetNames: List<String>}

      if (!mounted) return;
      setState(() {
        _bottleneckDuration = result['duration'] as int;
        _requiredMenuIds = result['menuIds'] as List<String>;
        _requiredMenuNames =
            result['menuSetNames']
                as List<String>; // <-- Ini adalah nama Set yang terlibat
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal hitung bottleneck menu: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _bottleneckDuration = 0;
          _requiredMenuIds = [];
          _requiredMenuNames = [];
        });
      }
    }
  }

  // --- SUBMIT: RUTE MANUAL ---
  Future<void> _createManualRoute() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedVehicle == null || _requiredMenuIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Mobil dan Menu Wajib ada, Anjing!")),
      );
      return;
    }

    // >>> KRITIS: Tambahkan cek kapasitas total! <<<
    final totalPortions = _selectedSchools.fold(
      0,
      (sum, s) => sum + s.studentCount,
    );
    if (totalPortions > _selectedVehicle!.capacityLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Total porsi (${totalPortions}) melebihi kapasitas mobil (${_selectedVehicle!.capacityLimit}). Rute akan dibuat Multi-Trip!",
          ),
          backgroundColor: Colors.orange,
        ),
      );
      // Lanjutkan proses, tapi service harus menangani Multi-Trip
    }

    // WARNING: Logika OSRM dan Insert Route ada di Service!
    setState(() => _isSubmitting = true);
    try {
      // Menggunakan fungsi yang sama (asumsi service yang mengontrol multi-trip)
      await _routeService.createBatchRoutes(
        vehicleIds: [_selectedVehicle!.id], // Hanya 1 mobil
        courierId:
            _selectedVehicle!.courierProfileId ??
            await _routeService.getFirstCourierId(),
        menuIds: _requiredMenuIds,
        date: _selectedDate,
        selectedSchools: _selectedSchools,
        cookingDuration: _bottleneckDuration,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Rute Manual Berhasil Dibuat dan Di-Optimasi (Multi-Trip jika perlu)!",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // Selesai
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Gagal Buat Rute: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Buat Rute Pengiriman (Manual)"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- STEP 1: TANGGAL (PENTING) ---
                    const Text(
                      "1. Tanggal Pengiriman",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.red,
                      ),
                      title: Text(
                        DateFormat(
                          'EEEE, d MMMM yyyy',
                          'id_ID',
                        ).format(_selectedDate),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(
                            const Duration(days: 90),
                          ),
                        );
                        if (picked != null && picked != _selectedDate) {
                          _onDateChanged(picked);
                        }
                      },
                    ),
                    const Divider(thickness: 2, height: 30),

                    // --- STEP 2: ARMADA (MOBIL & KURIR) ---
                    const Text(
                      "2. Pilih Armada (Mobil & Kurir)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Vehicle>(
                      decoration: const InputDecoration(
                        labelText: "Pilih Armada Mobil",
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                      value: _selectedVehicle,
                      items: _availableVehicles.map((v) {
                        return DropdownMenuItem(
                          value: v,
                          child: Text(
                            "${v.plateNumber} (Kap: ${v.capacityLimit})",
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedVehicle = val),
                      validator: (v) =>
                          v == null ? "Wajib pilih mobil, bego!" : null,
                    ),
                    const SizedBox(height: 10),
                    // Display Kurir (hanya read-only, dari join ke vehicle)
                    Text(
                      "Kurir Bertugas: ${_selectedVehicle?.driverName ?? 'Belum Ditugaskan'}",
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: _selectedVehicle?.driverName != null
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    const Divider(thickness: 2, height: 30),

                    // --- STEP 3: SEKOLAH TUJUAN ---
                    const Text(
                      "3. Pilih Sekolah Tujuan (Urutan TIDAK penting, akan di-optimasi)",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Multi Select Dropdown untuk Sekolah
                    Wrap(
                      spacing: 8.0,
                      children: _allSchools.map((school) {
                        final isSelected = _selectedSchools.contains(school);
                        return ChoiceChip(
                          label: Text(school.name),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedSchools.add(school);
                              } else {
                                _selectedSchools.removeWhere(
                                  (s) => s.id == school.id,
                                );
                              }
                            });
                            _onSchoolSelectionChanged(); // Update menu bottleneck
                          },
                          selectedColor: Colors.orange[100],
                          backgroundColor: Colors.grey[200],
                          side: BorderSide(
                            color: isSelected ? Colors.orange : Colors.grey,
                          ),
                        );
                      }).toList(),
                    ),

                    if (_selectedSchools.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Text(
                          "Wajib pilih minimal 1 sekolah!",
                          style: TextStyle(color: Colors.red),
                        ),
                      ),

                    const Divider(thickness: 2, height: 30),

                    // --- STEP 4: RINGKASAN & ACTION ---
                    const Text(
                      "4. Ringkasan Kebutuhan",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 10),

                    Card(
                      color: Colors.yellow[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Total Sekolah: ${_selectedSchools.length} Lokasi",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Total Porsi: ${_selectedSchools.fold(0, (sum, s) => sum + s.studentCount)} Porsi",
                            ),
                            Text(
                              "Menu Bottleneck: ${_requiredMenuNames.join(', ')}",
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Durasi Masak Terlama (Bottleneck): **${_bottleneckDuration} Menit**",
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed:
                            (_isSubmitting ||
                                _selectedSchools.isEmpty ||
                                _selectedVehicle == null ||
                                _bottleneckDuration == 0)
                            ? null
                            : _createManualRoute,
                        icon: const Icon(Icons.route, color: Colors.white),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                "GENERATE RUTE MANUAL & OPTIMASI",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          padding: const EdgeInsets.symmetric(vertical: 15),
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
