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
  List<String> _selectedVehicleIds = []; 
  
  // [PERUBAHAN UTAMA] List Menu IDs untuk Multi-Select (Min 3 slot)
  List<String?> _selectedMenuIds = [null, null, null]; 
  
  String? _fallbackCourierId; 
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
        _vehicles = (results[1] as List<Vehicle>).where((v) => v.isActive).toList(); 
        _couriers = results[2] as List<CourierModel>;
        _menus = results[3] as List<Menu>;

        // Set Kurir FALLBACK Otomatis: Ambil Kurir pertama sebagai default ID
        if (_couriers.isNotEmpty) {
          _fallbackCourierId = _couriers.first.id;
        }

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Gagal memuat data: $e"), backgroundColor: Colors.red));
      }
      setState(() => _isLoading = false);
    }
  }

  // Helper untuk mendapatkan Durasi Masak Terlama (Bottleneck)
  int _getBottleneckCookingDuration(List<String> menuIds) {
      if (menuIds.isEmpty) return 0;
      
      final durations = menuIds.map((id) {
          return _menus.firstWhereOrNull((m) => m.id == id)?.cookingDurationMinutes ?? 0;
      }).toList();
      
      return durations.isNotEmpty ? durations.reduce((a, b) => a > b ? a : b) : 0;
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final validMenuIds = _selectedMenuIds.whereType<String>().toList();

      if (validMenuIds.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wajib pilih minimal 3 item Menu Set.")));
        return;
      }
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
      if (_fallbackCourierId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada Kurir yang terdaftar untuk fallback!")));
        return;
      }
      
      // [PENTING] BLOK PENGECEKAN WAJIB KURIR ARMADA DIHAPUS, Sesuai permintaan user
      // Sistem akan tetap jalan meskipun Kurir di Master Armada kosong.
      
      setState(() => _isSubmitting = true);
      try {
        final int bottleneckDuration = _getBottleneckCookingDuration(validMenuIds);
        
        await RouteService().createBatchRoutes(
          vehicleIds: _selectedVehicleIds,
          courierId: _fallbackCourierId!, // Kurir Fallback (akan ditimpa jika ada di mobil)
          menuIds: validMenuIds,
          date: _selectedDate,
          selectedSchools: _selectedSchools,
          cookingDuration: bottleneckDuration,
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
      appBar: AppBar(
          title: const Text("Buat Rute Otomatis"),
          backgroundColor: Colors.orange[800]),
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
                      title: Text(
                          "Tanggal: ${DateFormat('dd MMM yyyy').format(_selectedDate)}"),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final d = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030));
                        if (d != null) setState(() => _selectedDate = d);
                      },
                    ),
                    const SizedBox(height: 10),

                    // [PERUBAHAN UTAMA] 2. PILIH SET MENU (Multi Select 3-5)
                    const Text("Pilih Set Menu (Min 3, Max 5):",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    
                    // List Dropdown Menu
                    ...List.generate(_selectedMenuIds.length, (index) {
                      final availableItems = _menus.map((menu) {
                        return DropdownMenuItem<String>(
                          value: menu.id,
                          // Logika agar menu yang sama tidak bisa dipilih dua kali
                          enabled: !_selectedMenuIds.whereType<String>().any(
                                (id) => id == menu.id && id != _selectedMenuIds[index],
                              ),
                          child: Text("${menu.name} (${menu.cookingDurationMinutes} mnt)"),
                        );
                      }).toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: "Menu Item #${index + 1}",
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.restaurant),
                          ),
                          value: _selectedMenuIds[index],
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text("--- Pilih Menu ---"),
                            ),
                            ...availableItems,
                          ],
                          onChanged: (String? newValue) =>
                              setState(() => _selectedMenuIds[index] = newValue),
                          // Validasi minimal 3 item
                          validator: (v) => (index < 3 && v == null)
                              ? "Menu Item #${index + 1} wajib diisi."
                              : null,
                        ),
                      );
                    }),
                    
                    // Tombol Tambah/Hapus Slot Menu
                    Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_selectedMenuIds.length < 5)
                            TextButton.icon(
                              icon: const Icon(Icons.add_circle, color: Colors.blue),
                              label: const Text("Tambah Slot Menu"),
                              onPressed: () => setState(() => _selectedMenuIds.add(null)),
                            ),
                          if (_selectedMenuIds.length > 3)
                            TextButton.icon(
                              icon: const Icon(Icons.remove_circle, color: Colors.red),
                              label: const Text("Hapus Slot Menu"),
                              onPressed: () => setState(() => _selectedMenuIds.removeLast()),
                            ),
                        ],
                    ),
                    const SizedBox(height: 15),
                    
                    // [DIHAPUS DARI UI] Bagian Kurir Fallback Dihapus
                    
                    // 4. PILIH MOBIL (MULTI SELECT)
                    const Text("Pilih Armada (Bisa Lebih dari 1):",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Container(
                      height: 150,
                      decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(5)),
                      child: ListView.builder(
                        itemCount: _vehicles.length,
                        itemBuilder: (ctx, i) {
                          final v = _vehicles[i];
                          final isSelected = _selectedVehicleIds.contains(v.id);
                          
                          // Cari nama kurir yang ditugaskan ke mobil ini
                          final assignedCourier = _couriers.firstWhereOrNull(
                              (c) => c.id == v.courierProfileId);
                          final courierName = assignedCourier?.name ?? 'Belum Ditugaskan';

                          return CheckboxListTile(
                            title: Text(v.plateNumber),
                            // Menampilkan Kurir yang ditugaskan di Master Armada
                            subtitle: Text("Driver: ${v.driverName ?? '-'} | Kurir: $courierName"),
                            value: isSelected,
                            onChanged: (val) {
                              setState(() {
                                if (val!)
                                  _selectedVehicleIds.add(v.id);
                                else
                                  _selectedVehicleIds.remove(v.id);
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "${_selectedVehicleIds.length} Mobil Dipilih. Sistem akan membagi sekolah secara otomatis.",
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),

                    // 5. PILIH SEKOLAH
                    const Text("Pilih Sekolah Tujuan:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _schools.length,
                      itemBuilder: (ctx, i) {
                        final s = _schools[i];
                        final isSelected =
                            _selectedSchools.any((e) => e.id == s.id);
                        return CheckboxListTile(
                          title: Text(s.name),
                          subtitle: Text(
                              "${s.studentCount} Pax (Deadline: ${s.deadlineTime ?? '12:00'})"),
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val!)
                                _selectedSchools.add(s);
                              else
                                _selectedSchools.removeWhere((e) => e.id == s.id);
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
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.all(15)),
                        child: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text("GENERATE BATCH RUTE",
                                style: TextStyle(
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