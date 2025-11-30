import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/school_model.dart';
import '../../../models/vehicle_model.dart';
import '../../../models/courier_model.dart';
import '../../../models/menu_model.dart';
import '../services/school_service.dart';
import '../services/vehicle_service.dart';
import '../services/courier_service.dart';
import '../services/menu_service.dart';
import '../services/route_service.dart';

class CreateRouteScreen extends StatefulWidget {
  const CreateRouteScreen({super.key});

  @override
  State<CreateRouteScreen> createState() => _CreateRouteScreenState();
}

class _CreateRouteScreenState extends State<CreateRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  
  List<School> _schools = [];
  List<Vehicle> _vehicles = [];
  List<CourierModel> _couriers = [];
  List<Menu> _menus = [];
  
  DateTime _selectedDate = DateTime.now();
  List<String> _selectedVehicleIds = []; // [REVISI] Multi Mobil
  String? _selectedCourierId;
  String? _selectedMenuId;
  final List<School> _selectedSchools = [];

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        SchoolService().getMySchools(),
        VehicleService().getMyVehicles(),
        CourierService().getMyCouriers(),
        MenuService().getMyMenus(),
      ]);
      setState(() {
        _schools = results[0] as List<School>;
        _vehicles = results[1] as List<Vehicle>;
        _couriers = results[2] as List<CourierModel>;
        _menus = results[3] as List<Menu>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedSchools.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 sekolah")));
        return;
      }
      if (_selectedVehicleIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih minimal 1 mobil")));
        return;
      }
      if (_selectedSchools.length < _selectedVehicleIds.length) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Jumlah sekolah lebih sedikit dari mobil!")));
        return;
      }
      
      setState(() => _isSubmitting = true);
      try {
        final menu = _menus.firstWhere((m) => m.id == _selectedMenuId);

        await RouteService().createBatchRoutes(
          vehicleIds: _selectedVehicleIds,
          courierId: _selectedCourierId!,
          menuId: _selectedMenuId!,
          date: _selectedDate,
          selectedSchools: _selectedSchools,
          cookingDuration: menu.cookingDurationMinutes,
        );
        
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rute & Jadwal Otomatis Terbuat!")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      } finally {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Buat Rute Otomatis"), backgroundColor: Colors.orange[800]),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TANGGAL
                    ListTile(
                      title: Text("Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
                        if (d != null) setState(() => _selectedDate = d);
                      },
                    ),
                    const SizedBox(height: 10),
                    
                    // 2. MENU (Wajib)
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Menu (Hitung Masak Otomatis)", border: OutlineInputBorder()),
                      items: _menus.map((m) => DropdownMenuItem(value: m.id, child: Text("${m.name} (${m.cookingDurationMinutes} mnt)"))).toList(),
                      onChanged: (v) => setState(() => _selectedMenuId = v),
                      validator: (v) => v == null ? "Wajib pilih menu" : null,
                    ),
                    const SizedBox(height: 15),

                    // 3. PILIH KURIR
                    DropdownButtonFormField(
                      decoration: const InputDecoration(labelText: "Kurir Penanggung Jawab", border: OutlineInputBorder()),
                      items: _couriers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                      onChanged: (v) => _selectedCourierId = v,
                      validator: (v) => v == null ? "Pilih Kurir" : null,
                    ),
                    const SizedBox(height: 15),

                    // 4. PILIH MOBIL (MULTI SELECT)
                    const Text("Pilih Armada (Bisa Lebih dari 1):", style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                      child: ListView.builder(
                        itemCount: _vehicles.length,
                        itemBuilder: (ctx, i) {
                          final v = _vehicles[i];
                          final isSelected = _selectedVehicleIds.contains(v.id);
                          return CheckboxListTile(
                            title: Text(v.plateNumber),
                            subtitle: Text(v.driverName ?? '-'),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val!) _selectedVehicleIds.add(v.id);
                                else _selectedVehicleIds.remove(v.id);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text("${_selectedVehicleIds.length} Mobil Dipilih. Sistem akan membagi sekolah secara otomatis.", style: const TextStyle(fontSize: 12, color: Colors.blue)),

                    const SizedBox(height: 20),
                    const Divider(),
                    
                    // 5. PILIH SEKOLAH
                    const Text("Pilih Sekolah Tujuan:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _schools.length,
                      itemBuilder: (ctx, i) {
                        final s = _schools[i];
                        final isSelected = _selectedSchools.any((e) => e.id == s.id);
                        return CheckboxListTile(
                          title: Text(s.name),
                          subtitle: Text("${s.studentCount} Pax (Deadline: ${s.deadlineTime ?? '12:00'})"),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val!) _selectedSchools.add(s);
                              else _selectedSchools.removeWhere((e) => e.id == s.id);
                            });
                          },
                        );
                      },
                    ),

                    const SizedBox(height: 30),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.all(15)),
                        child: _isSubmitting 
                           ? const CircularProgressIndicator(color: Colors.white)
                           : const Text("GENERATE BATCH RUTE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}