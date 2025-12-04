import 'package:flutter/material.dart';
import '../../../models/menu_model.dart';
import '../services/menu_service.dart';
import 'add_menu_screen.dart';

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  final MenuService _menuService = MenuService();

  // [BARU] State untuk Filter
  String? _selectedCategoryFilter;

  // Daftar Kategori untuk Filter (Harus mencakup semua kategori yang mungkin)
  final List<String> _filterCategories = [
    'Semua Kategori',
    'Karbo',
    'Lauk Protein',
    'Sayur',
    'Pelengkap',
    'Buah',
    'Lauk Nabati',
    'Saus/Lauk',
  ];

  // Method untuk mengambil data menu (diperbarui untuk handle filter)
  Future<List<Menu>> _fetchMenus() async {
    final allMenus = await _menuService.getMyMenus();
    if (_selectedCategoryFilter == null ||
        _selectedCategoryFilter == 'Semua Kategori') {
      return allMenus;
    }
    return allMenus
        .where((menu) => menu.category == _selectedCategoryFilter)
        .toList();
  }

  // Fungsi navigasi ke form tambah/edit
  void _navigateToAddEdit(BuildContext context, {Menu? menu}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddMenuScreen(menuToEdit: menu), // Jika menu null, berarti tambah
      ),
    ).then((result) {
      if (result == true) {
        // Refresh tampilan list setelah kembali dari form
        setState(() {});
      }
    });
  }

  // Fungsi hapus menu (Tambahkan konfirmasi)
  Future<void> _deleteMenu(
    BuildContext context,
    String menuId,
    String menuName,
  ) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Menu Produksi?"),
        content: Text(
          "Yakin ingin menghapus menu '$menuName'? Tindakan ini tidak bisa dibatalkan.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Batal"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _menuService.deleteMenu(menuId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Menu berhasil dihapus!"),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh list
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal menghapus: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Menu Produksi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Column(
        // Pake Column untuk menempatkan filter di atas list
        children: [
          // [BARU] Dropdown Filter Kategori
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: "Filter Kategori",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.filter_list),
              ),
              value: _selectedCategoryFilter ?? 'Semua Kategori',
              items: _filterCategories.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategoryFilter = newValue;
                });
              },
            ),
          ),

          // List Menu (Dibungkus Expanded)
          Expanded(
            child: FutureBuilder<List<Menu>>(
              future: _fetchMenus(), // Panggil data menu
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                final menus = snapshot.data ?? [];

                if (menus.isEmpty) {
                  return Center(
                    child: Text(
                      _selectedCategoryFilter == 'Semua Kategori'
                          ? "Belum ada menu yang terdaftar."
                          : "Tidak ada menu terdaftar di kategori ini.",
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: menus.length,
                  itemBuilder: (context, index) {
                    final menu = menus[index];
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(
                          menu.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "${menu.category} | Masak: ${menu.cookingDurationMinutes} mnt | Batas Konsumsi: ${menu.maxConsumeMinutes} mnt",
                        ),
                        leading: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.orange,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Tombol Edit (UC12)
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () =>
                                  _navigateToAddEdit(context, menu: menu),
                            ),
                            // Tombol Hapus (UC13)
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteMenu(
                                context,
                                menu.id,
                                menu.name,
                              ), // Pass name for confirmation
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text("Tambah Menu Baru"), // UC11
        onPressed: () => _navigateToAddEdit(context),
      ),
    );
  }
}
