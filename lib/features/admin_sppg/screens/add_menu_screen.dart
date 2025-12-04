import 'package:flutter/material.dart';
import '../../../models/menu_model.dart';
import '../services/menu_service.dart';

class AddMenuScreen extends StatefulWidget {
  final Menu? menuToEdit; // Jika ini diisi, berarti mode Edit

  const AddMenuScreen({super.key, this.menuToEdit});

  @override
  State<AddMenuScreen> createState() => _AddMenuScreenState();
}

class _AddMenuScreenState extends State<AddMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final MenuService _menuService = MenuService();

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _durationController = TextEditingController(
    text: '0',
  ); // Default 0
  final TextEditingController _consumeMinutesController = TextEditingController(
    text: '120',
  );

  // Daftar Kategori Tetap (Untuk Dropdown)
  // [FIX KRITIS] Harus mencakup semua nilai kategori yang mungkin ada di database
  final List<String> _categories = [
    'Karbo', // Asumsi Nasi Putih / Spaghetti adalah Karbo
    'Lauk Protein',
    'Lauk Nabati', // Dari data dump lo ada ini
    'Saus/Lauk', // Dari data dump lo ada ini
    'Sayur', // Dari data dump lo ada ini
    'Buah', // Dari data dump lo ada ini
    'Pelengkap', // Dari data dump lo ada ini
  ];

  String? _selectedCategory;

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.menuToEdit != null) {
      // Mode Edit: Isi form dengan data yang sudah ada
      _nameController.text = widget.menuToEdit!.name;
      _durationController.text = widget.menuToEdit!.cookingDurationMinutes
          .toString();
      // [BARU] Isi field Batas Konsumsi
      _consumeMinutesController.text = widget.menuToEdit!.maxConsumeMinutes
          .toString();
      _selectedCategory = widget.menuToEdit!.category;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _consumeMinutesController.dispose(); // [BARU] Dispose controller
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() && _selectedCategory != null) {
      setState(() => _isSubmitting = true);

      // Ambil nilai baru
      final int duration = int.tryParse(_durationController.text) ?? 0;
      final int maxConsume =
          int.tryParse(_consumeMinutesController.text) ?? 120; // [BARU]

      final Map<String, dynamic> menuData = {
        'name': _nameController.text,
        'category': _selectedCategory,
        'cooking_duration_minutes': duration,
        'max_consume_minutes': maxConsume, // [BARU] Masukkan ke data
      };

      try {
        if (widget.menuToEdit == null) {
          // Mode Tambah (UC11)
          await _menuService.createMenu(menuData);
        } else {
          // Mode Edit (UC12)
          await _menuService.updateMenu(widget.menuToEdit!.id, menuData);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Menu berhasil ${widget.menuToEdit == null ? 'ditambahkan' : 'diperbarui'}!",
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Balik dan kirim sinyal sukses
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      if (_selectedCategory == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kategori wajib dipilih!")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.menuToEdit == null ? "Tambah Menu Baru" : "Edit Menu",
        ),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Nama Makanan
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Nama Makanan",
                  prefixIcon: Icon(Icons.food_bank),
                ),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 15),

              // Dropdown Kategori
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Kategori Menu",
                  prefixIcon: Icon(Icons.category),
                ),
                value: _selectedCategory,
                items: _categories.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) =>
                    setState(() => _selectedCategory = newValue),
                validator: (v) => v == null ? "Pilih kategori" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _durationController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Estimasi Durasi Masak (Menit)",
                  hintText: "Contoh: 60",
                  prefixIcon: Icon(Icons.timer),
                ),
                validator: (v) => v!.isEmpty || int.tryParse(v) == null
                    ? "Wajib diisi angka"
                    : null,
              ),

              const SizedBox(height: 15),

              // [BARU] Batas Waktu Konsumsi
              TextFormField(
                controller: _consumeMinutesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Batas Waktu Konsumsi (Menit)",
                  hintText: "Contoh: 120",
                  prefixIcon: Icon(Icons.hourglass_bottom),
                ),
                validator: (v) => v!.isEmpty || (int.tryParse(v) ?? 0) < 30
                    ? "Minimal 30 menit"
                    : null,
              ),

              const SizedBox(height: 30),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.menuToEdit == null
                              ? "SIMPAN MENU"
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
