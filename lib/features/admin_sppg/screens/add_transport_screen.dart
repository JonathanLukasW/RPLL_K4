import 'package:flutter/material.dart';
import '../services/vehicle_service.dart';
import '../../../models/vehicle_model.dart'; // Import Model

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
  
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // [LOGIKA EDIT] Isi form jika ada data
    if (widget.vehicleToEdit != null) {
      _plateController.text = widget.vehicleToEdit!.plateNumber;
      _driverController.text = widget.vehicleToEdit!.driverName ?? '';
      _capacityController.text = widget.vehicleToEdit!.capacityLimit.toString();
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      
      final data = {
        'plate_number': _plateController.text,
        'driver_name': _driverController.text,
        'capacity_limit': int.parse(_capacityController.text),
        'is_active': true, // Default aktif
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
            content: Text(widget.vehicleToEdit == null ? "Berhasil ditambah!" : "Berhasil diperbarui!"), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context, true); // Sukses

      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicleToEdit == null ? "Tambah Transportasi" : "Edit Transportasi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: "Plat Nomor", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _driverController,
                decoration: const InputDecoration(labelText: "Nama Supir / Kurir", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Kapasitas Angkut (Box)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800], padding: const EdgeInsets.symmetric(vertical: 15)),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(
                        widget.vehicleToEdit == null ? "SIMPAN" : "SIMPAN PERUBAHAN", 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                      ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}