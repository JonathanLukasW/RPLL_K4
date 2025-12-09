// === FILE: lib/features/admin_sppg/screens/add_menu_set_screen.dart ===

import 'package:flutter/material.dart';
import 'package:collection/collection.dart'; // Tambahkan ini
import '../../../models/menu_model.dart';
import '../services/menu_service.dart';

class AddMenuSetScreen extends StatefulWidget {
  // [BARU] Tambahkan Menu Set untuk diedit
  final AdminMenuSetModel? setToEdit;

  const AddMenuSetScreen({super.key, this.setToEdit});

  @override
  State<AddMenuSetScreen> createState() => _AddMenuSetScreenState();
}

class _AddMenuSetScreenState extends State<AddMenuSetScreen> {
  final _formKey = GlobalKey<FormState>();
  final MenuService _menuService = MenuService();
  final _nameController = TextEditingController();

  List<Menu> _allMenus = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  // State untuk menyimpan ID Menu yang dipilih berdasarkan kategori
  Map<String, String?> _selectedMenuIds = {
    'Karbo': null,
    'Lauk Protein': null,
    'Sayur': null,
    'Buah': null,
    'Lauk Nabati': null,
    'Pelengkap': null, // Opsional
  };

  // State untuk menyimpan Total Gizi yang dihitung
  int _totalEnergy = 0;
  double _totalProtein = 0.0;
  double _totalFat = 0.0;
  double _totalCarbs = 0.0;

  final List<String> _requiredCategories = [
    'Karbo',
    'Lauk Protein',
    'Sayur',
    'Buah',
    'Lauk Nabati',
  ];

  @override
  void initState() {
    super.initState();

    // [LOGIC EDIT] Isi form jika mode Edit
    if (widget.setToEdit != null) {
      final s = widget.setToEdit!;
      _nameController.text = s.setName;
      _selectedMenuIds = {
        'Karbo': s.karboId,
        'Lauk Protein': s.proteinId,
        'Sayur': s.sayurId,
        'Buah': s.buahId,
        'Lauk Nabati': s.nabatiId,
        'Pelengkap': s.pelengkapId,
      };

      // Inisialisasi total gizi dari data yang sudah ada (jika ada)
      _totalEnergy = s.totalEnergy;
      _totalProtein = s.totalProtein;
      _totalFat = s.totalFat;
      _totalCarbs = s.totalCarbs;
    }
    _fetchMenus();
  }

  void _calculateNutrition() {
    int energy = 0;
    double protein = 0.0;
    double fat = 0.0;
    double carbs = 0.0;

    for (var id in _selectedMenuIds.values) {
      if (id != null) {
        final menu = _allMenus.firstWhereOrNull((m) => m.id == id);
        if (menu != null) {
          energy += menu.energy;
          protein += menu.protein;
          fat += menu.fat;
          carbs += menu.carbs;
        }
      }
    }

    setState(() {
      _totalEnergy = energy;
      _totalProtein = protein;
      _totalFat = fat;
      _totalCarbs = carbs;
    });
  }

  Future<void> _fetchMenus() async {
    try {
      final menus = await _menuService.getMyMenus();
      if (mounted) {
        setState(() {
          _allMenus = menus;
          _isLoading = false;
        });
        // Hitung ulang gizi saat data menu/data edit selesai dimuat
        _calculateNutrition();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal load menu: $e"),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    for (var category in _requiredCategories) {
      if (_selectedMenuIds[category] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("$category wajib diisi!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);

    // [BARU] Sertakan data total gizi ke dalam payload
    final Map<String, dynamic> data = {
      'set_name': _nameController.text.trim(),
      'karbo_id': _selectedMenuIds['Karbo'],
      'protein_id': _selectedMenuIds['Lauk Protein'],
      'sayur_id': _selectedMenuIds['Sayur'],
      'buah_id': _selectedMenuIds['Buah'],
      'nabati_id': _selectedMenuIds['Lauk Nabati'],
      'pelengkap_id': _selectedMenuIds['Pelengkap'],
      'total_energy': _totalEnergy, // Kirim total gizi
      'total_protein': _totalProtein,
      'total_fat': _totalFat,
      'total_carbs': _totalCarbs,
    };

    try {
      if (widget.setToEdit == null) {
        await _menuService.createMenuSet(data);
      } else {
        await _menuService.updateMenuSet(
          widget.setToEdit!.id,
          data,
        ); // Gunakan update service
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Menu Set Berhasil ${widget.setToEdit == null ? 'Dibuat' : 'Diperbarui'}!",
          ),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.setToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? "Edit Menu Set" : "Tambah Menu Set Baru"),
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
                    TextFormField(
                      controller: _nameController,
                      readOnly:
                          isEdit, // Nama set tidak bisa diubah setelah dibuat
                      decoration: InputDecoration(
                        labelText: "Nama Set Menu",
                        prefixIcon: const Icon(Icons.label),
                        border: const OutlineInputBorder(),
                        suffixIcon: isEdit
                            ? const Icon(Icons.lock_outline, size: 18)
                            : null,
                      ),
                      validator: (v) =>
                          v!.isEmpty ? "Nama set wajib diisi" : null,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Pilih Komponen Menu:",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    // List Dropdown per Kategori
                    ..._selectedMenuIds.keys.map((category) {
                      final isRequired = _requiredCategories.contains(category);

                      // Filter menu yang sesuai kategori saat ini
                      final filteredMenus = _allMenus
                          .where((menu) => menu.category == category)
                          .toList();

                      final menuItems = filteredMenus.map((menu) {
                        return DropdownMenuItem(
                          value: menu.id,
                          // [BARU] Tampilkan Gizi di Dropdown
                          child: Text(
                            "${menu.name} (E:${menu.energy} P:${menu.protein.toStringAsFixed(1)})",
                          ),
                        );
                      }).toList();

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText:
                                "$category ${isRequired ? '(Wajib)' : '(Opsional)'}",
                            prefixIcon: Icon(
                              isRequired
                                  ? Icons.restaurant
                                  : Icons.auto_fix_high,
                            ),
                          ),
                          value: _selectedMenuIds[category],
                          items: [
                            DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                isRequired
                                    ? "--- Pilih $category ---"
                                    : "--- Tidak Ada ---",
                                style: TextStyle(
                                  color: isRequired ? Colors.red : Colors.grey,
                                ),
                              ),
                            ),
                            ...menuItems,
                          ],
                          onChanged: (String? newValue) {
                            setState(() {
                              _selectedMenuIds[category] = newValue;
                              _calculateNutrition(); // Hitung ulang saat pilihan berubah
                            });
                          },
                          validator: (v) => isRequired && v == null
                              ? "$category harus dipilih"
                              : null,
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 20),
                    // [BARU] RINGKASAN TOTAL GIZI
                    Card(
                      color: Colors.blue[50],
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "TOTAL KANDUNGAN GIZI (Per Porsi)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Divider(),
                            Text("⚡ Energi: ${_totalEnergy} Kkal"),
                            Text(
                              "🍖 Protein: ${_totalProtein.toStringAsFixed(1)} gram",
                            ),
                            Text(
                              "🧀 Lemak: ${_totalFat.toStringAsFixed(1)} gram",
                            ),
                            Text(
                              "🥖 Karbohidrat: ${_totalCarbs.toStringAsFixed(1)} gram",
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _submitForm,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: _isSubmitting
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                isEdit ? "SIMPAN PERUBAHAN" : "SIMPAN MENU SET",
                                style: const TextStyle(
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
                  ],
                ),
              ),
            ),
    );
  }
}
