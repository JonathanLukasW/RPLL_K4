import 'package:flutter/material.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/courier_model.dart';
// Import untuk Collection utilities (firstWhereOrNull)
import 'package:collection/collection.dart';

class AddTransportScreen extends StatefulWidget {
  final Vehicle? vehicleToEdit; // Data untuk diedit
  const AddTransportScreen({super.key, this.vehicleToEdit});

  @override
  State<AddTransportScreen> createState() => _AddTransportScreenState();
}

class _AddTransportScreenState extends State<AddTransportScreen> {
  final _formKey = GlobalKey<FormState>();
  // ... (inside _AddTransportScreenState)

  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  List<CourierModel> _couriers = [];
  String? _selectedCourierId; // Main Driver
  String? _selectedAssistantId; // [BARU] Assistant Driver

  // [BARU] List ID Kurir yang Sudah Ditugaskan ke Mobil Lain
  List<String> _assignedCourierIds = [];
  bool _isLoadingData = true;
  // ...
  // [FIX KRITIS]: Deklarasi Variabel isSubmitting
  bool _isSubmitting = false; // <--- TAMBAHKAN INI!

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final courierService = CourierService();
      final results = await Future.wait([
        courierService.getMyCouriers(),
        VehicleService().getMyVehicles(),
      ]);
      final fetchedCouriers = results[0] as List<CourierModel>;
      final allVehicles = results[1] as List<Vehicle>;

      // Tentukan ID Kurir yang sudah ditugaskan (Main atau Assistant)
      final currentVehicleId = widget.vehicleToEdit?.id;
      final Set<String> assignedIds = {};
      for (var v in allVehicles) {
        // Masukkan Main Driver
        if (v.courierProfileId != null && v.id != currentVehicleId) {
          assignedIds.add(v.courierProfileId!);
        }
        // Masukkan Assistant Driver
        if (v.assistantCourierId != null && v.id != currentVehicleId) {
          assignedIds.add(v.assistantCourierId!);
        }
      }

      setState(() {
        _couriers = fetchedCouriers;
        _assignedCourierIds = assignedIds.toList();
        _isLoadingData = false;

        if (widget.vehicleToEdit != null) {
          final s = widget.vehicleToEdit!;
          _plateController.text = s.plateNumber;
          _capacityController.text = s.capacityLimit.toString();

          // Inisialisasi Main Driver
          _selectedCourierId = s.courierProfileId;
          final assignedMain = fetchedCouriers.firstWhereOrNull(
            (c) => c.id == s.courierProfileId,
          );
          _driverController.text = assignedMain?.name ?? s.driverName ?? '';

          // [BARU] Inisialisasi Assistant Driver
          _selectedAssistantId = s.assistantCourierId;
        } else {
          _driverController.text = '';
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal memuat data kurir: $e")));
      }
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      // Validasi: Driver Utama dan Asisten tidak boleh sama
      if (_selectedCourierId != null &&
          _selectedCourierId == _selectedAssistantId) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Kurir Utama dan Asisten tidak boleh sama!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      // [PERBAIKAN KRITIS] Gunakan Nama Kurir yang dipilih sebagai Nama Supir
      final selectedCourier = _couriers.firstWhereOrNull(
        (c) => c.id == _selectedCourierId,
      );
      final driverName = selectedCourier?.name ?? _driverController.text;

      final data = {
        'plate_number': _plateController.text,
        'driver_name': driverName, // <- Update nama supir
        'capacity_limit': int.parse(_capacityController.text),
        'is_active': true,
        'courier_profile_id': _selectedCourierId,
        'assistant_courier_id': _selectedAssistantId, // [BARU]
      };

      try {
        if (widget.vehicleToEdit == null) {
          await VehicleService().createVehicle(data);
        } else {
          await VehicleService().updateVehicle(widget.vehicleToEdit!.id, data);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.vehicleToEdit == null
                  ? "Berhasil ditambah!"
                  : "Berhasil diperbarui!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  // Helper untuk filter kurir: Kurir yang belum ditugaskan (di mobil lain)
  List<CourierModel> _filterAvailableCouriers(String? currentSelectedId) {
    return _couriers.where((c) {
      // 1. Kurir itu sendiri (selalu available)
      if (c.id == currentSelectedId) return true;

      // 2. Kurir yang sedang diedit (slot lain)
      if (widget.vehicleToEdit != null) {
        if (c.id == widget.vehicleToEdit!.courierProfileId) return true;
        if (c.id == widget.vehicleToEdit!.assistantCourierId) return true;
      }

      // 3. Kurir yang sudah ditugaskan ke mobil lain (slot manapun)
      if (_assignedCourierIds.contains(c.id)) return false;

      // 4. Cek Kurir yang sudah dipilih di slot lain di form ini (real-time check)
      if (_selectedCourierId != null && _selectedCourierId == c.id)
        return false;
      if (_selectedAssistantId != null && _selectedAssistantId == c.id)
        return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Filter kurir yang tersedia untuk Main Driver: kurir yang belum ditugaskan ke mobil lain
    final availableMainCouriers = _filterAvailableCouriers(_selectedCourierId);

    // Filter kurir yang tersedia untuk Assistant: kurir yang belum ditugaskan ke mobil lain ATAU Main Driver
    final availableAssistantCouriers = _filterAvailableCouriers(
      _selectedAssistantId,
    );
    final isEdit = widget.vehicleToEdit != null;

    // Filter Kurir yang Available
    final availableCouriers = _couriers.where((c) {
      // Jika mode edit, kurir yang saat ini ditugaskan tetap tersedia
      if (isEdit && c.id == widget.vehicleToEdit!.courierProfileId) return true;
      // Jika kurir belum ditugaskan ke mobil lain
      return !_assignedCourierIds.contains(c.id);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Transportasi" : "Tambah Transportasi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _plateController,
                      decoration: const InputDecoration(
                        labelText: "Plat Nomor",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),

                    // [FIX] HIDE DRIVER NAME INPUT, IT SHOULD BE POPULATED BY COURIER SELECTION
                    // Kita akan set `_driverController.text` berdasarkan kurir yang dipilih di `onChanged`

                    // --- DROPDOWN 1: COURIER UTAMA ---
                    // Menggunakan availableMainCouriers
                    DropdownButtonFormField<String>(
                      // ... (existing decoration) ...
                      value: _selectedCourierId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '--- Tidak Ditugaskan ---',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ...availableMainCouriers.map((courier) {
                          // Menggunakan list yang sudah di-filter
                          return DropdownMenuItem(
                            value: courier.id,
                            child: Text(
                              courier.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedCourierId = val;
                          if (val != null) {
                            final selected = _couriers.firstWhereOrNull(
                              (c) => c.id == val,
                            );
                            _driverController.text = selected?.name ?? '';
                          } else {
                            _driverController.text = '';
                          }
                        });
                      },
                      validator: (val) => null, // Boleh null
                    ),
                    const SizedBox(height: 15),

                    // [TAMPILKAN SAJA] Driver Name (Non-Editable)
                    TextFormField(
                      controller: _driverController,
                      decoration: const InputDecoration(
                        labelText: "Nama Supir (Otomatis dari Kurir)",
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                      style: const TextStyle(color: Colors.blueGrey),
                    ),
                    const SizedBox(height: 15),

                    // --- DROPDOWN 2: ASSISTANT COURIER [BARU] ---
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Tugaskan Asisten Kurir (Opsional)",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedAssistantId,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '--- Tidak Ditugaskan ---',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ...availableAssistantCouriers.map((courier) {
                          // Menggunakan list yang sudah di-filter
                          return DropdownMenuItem(
                            value: courier.id,
                            child: Text(
                              courier.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedAssistantId = val;
                        });
                      },
                      validator: (val) => null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Kapasitas Angkut (Box)",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        // Sekarang _isSubmitting sudah dideklarasikan dan bisa digunakan
                        onPressed: _isSubmitting || _isLoadingData
                            ? null
                            : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                widget.vehicleToEdit == null
                                    ? "SIMPAN"
                                    : "SIMPAN PERUBAHAN",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
