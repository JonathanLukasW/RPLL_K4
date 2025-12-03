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
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();

  List<CourierModel> _couriers = [];
  String? _selectedCourierId;

  // [BARU] List ID Kurir yang Sudah Ditugaskan ke Mobil Lain
  List<String> _assignedCourierIds = [];

  bool _isLoadingData = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final courierService = CourierService();

      // Ambil semua kurir dan semua kendaraan untuk cek assignment
      final results = await Future.wait([
        courierService.getMyCouriers(),
        VehicleService().getMyVehicles(), // Panggil service vehicles
      ]);

      final fetchedCouriers = results[0] as List<CourierModel>;
      final allVehicles = results[1] as List<Vehicle>;

      // Tentukan ID Kurir yang sudah ditugaskan (kecuali ID mobil yang sedang diedit)
      final currentVehicleId = widget.vehicleToEdit?.id;
      final assignedIds = allVehicles
          .where((v) => v.courierProfileId != null && v.id != currentVehicleId)
          .map((v) => v.courierProfileId!)
          .toList();

      setState(() {
        _couriers = fetchedCouriers;
        _assignedCourierIds = assignedIds;
        _isLoadingData = false;

        if (widget.vehicleToEdit != null) {
          final s = widget.vehicleToEdit!;
          _plateController.text = s.plateNumber;
          // [FIX] Menggunakan Nama Kurir sebagai default Nama Supir jika ada
          final assigned = fetchedCouriers.firstWhereOrNull(
            (c) => c.id == s.courierProfileId,
          );
          _driverController.text = assigned?.name ?? s.driverName ?? '';
          _capacityController.text = s.capacityLimit.toString();
          _selectedCourierId = s.courierProfileId;
        } else {
          // Defaultkan nama supir kosong saat tambah baru
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

  @override
  Widget build(BuildContext context) {
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

                    // [BARU] DROPDOWN PILIH KURIR YANG DITUGASKAN
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: "Tugaskan Kurir Utama",
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedCourierId,
                      // Tambahkan opsi 'Tidak Ditugaskan'
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text(
                            '--- Tidak Ditugaskan ---',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        ...availableCouriers.map((courier) {
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

                          // Auto-fill driver name with courier name if selected
                          if (val != null) {
                            final selected = _couriers.firstWhereOrNull(
                              (c) => c.id == val,
                            );
                            _driverController.text = selected?.name ?? '';
                          } else {
                            // Clear driver name if no courier is selected
                            _driverController.text = '';
                          }
                        });
                      },
                      validator: (val) {
                        if (val == null) {
                          // Asumsi boleh tidak ditugaskan (courier_profile_id null)
                          return null;
                        }
                        return null;
                      },
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
                        onPressed: _isSubmitting ? null : _submit,
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
