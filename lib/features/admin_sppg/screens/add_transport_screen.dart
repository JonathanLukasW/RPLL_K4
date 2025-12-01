import 'package:flutter/material.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart'; // [BARU]
import '../../../models/vehicle_model.dart';
import '../../../models/courier_model.dart'; // [BARU]

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

  // [BARU] State untuk Kurir
  List<CourierModel> _couriers = [];
  String? _selectedCourierId;
  bool _isLoadingData = true; // Untuk load data kurir
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final courierService = CourierService();
      final fetchedCouriers = await courierService.getMyCouriers();

      setState(() {
        _couriers = fetchedCouriers;
        _isLoadingData = false;

        if (widget.vehicleToEdit != null) {
          final s = widget.vehicleToEdit!;
          _plateController.text = s.plateNumber;
          _driverController.text = s.driverName ?? '';
          _capacityController.text = s.capacityLimit.toString();
          // Set kurir yang sudah ditugaskan
          _selectedCourierId = s.courierProfileId;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal memuat data kurir: $e")));
      }
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      // [PERBAIKAN] Menambahkan courier_profile_id ke data
      final data = {
        'plate_number': _plateController.text,
        'driver_name': _driverController.text,
        'capacity_limit': int.parse(_capacityController.text),
        'is_active': true, // Default aktif
        'courier_profile_id': _selectedCourierId, // <--- TAMBAHKAN INI
      };

      try {
        if (widget.vehicleToEdit == null) {
          // Mode Tambah
          await VehicleService().createVehicle(data);
        } else {
          // Mode Edit
          await VehicleService().updateVehicle(widget.vehicleToEdit!.id, data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(widget.vehicleToEdit == null
                  ? "Berhasil ditambah!"
                  : "Berhasil diperbarui!"),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Sukses
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.vehicleToEdit != null;

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
                          border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _driverController,
                      decoration: const InputDecoration(
                          labelText: "Nama Supir / Kurir",
                          border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _capacityController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: "Kapasitas Angkut (Box)",
                          border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),

                    // [BARU] DROPDOWN PILIH KURIR YANG DITUGASKAN
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: "Tugaskan Kurir Utama",
                          border: OutlineInputBorder()),
                      value: _selectedCourierId,
                      items: _couriers.map((courier) {
                        return DropdownMenuItem(
                          value: courier.id,
                          child: Text(courier.name,
                              overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCourierId = val),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            padding: const EdgeInsets.symmetric(vertical: 15)),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                widget.vehicleToEdit == null
                                    ? "SIMPAN"
                                    : "SIMPAN PERUBAHAN",
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}