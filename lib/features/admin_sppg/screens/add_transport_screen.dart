import 'package:flutter/material.dart';
import '../services/vehicle_service.dart';

class AddTransportScreen extends StatefulWidget {
  const AddTransportScreen({super.key});

  @override
  State<AddTransportScreen> createState() => _AddTransportScreenState();
}

class _AddTransportScreenState extends State<AddTransportScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _driverController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController();
  
  bool _isSubmitting = false;

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        await VehicleService().createVehicle({
          'plate_number': _plateController.text,
          'driver_name': _driverController.text,
          'capacity_limit': int.parse(_capacityController.text),
          'is_active': true,
        });

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transportasi berhasil ditambahkan!"), backgroundColor: Colors.green),
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
        title: const Text("Tambah Transportasi"),
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
                decoration: const InputDecoration(labelText: "Plat Nomor (Misal: D 1234 ABC)", border: OutlineInputBorder()),
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
                decoration: const InputDecoration(labelText: "Kapasitas Angkut (Box/Porsi)", border: OutlineInputBorder(), hintText: "Misal: 500"),
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
                    : const Text("SIMPAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}