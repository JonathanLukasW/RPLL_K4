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
  
  // Method untuk mengambil data menu
  Future<List<Menu>> _fetchMenus() async {
    return await _menuService.getMyMenus();
  }

  // Fungsi navigasi ke form tambah/edit
  void _navigateToAddEdit(BuildContext context, {Menu? menu}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMenuScreen(menuToEdit: menu), // Jika menu null, berarti tambah
      ),
    ).then((result) {
      if (result == true) {
        // Refresh tampilan list setelah kembali dari form
        setState(() {}); 
      }
    });
  }

  // Fungsi hapus menu
  Future<void> _deleteMenu(BuildContext context, String menuId) async {
    await _menuService.deleteMenu(menuId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Menu berhasil dihapus!"), backgroundColor: Colors.green),
    );
    setState(() {}); // Refresh list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Menu Produksi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Menu>>(
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
            return const Center(child: Text("Belum ada menu yang terdaftar."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: menus.length,
            itemBuilder: (context, index) {
              final menu = menus[index];
              return Card(
                elevation: 2,
                child: ListTile(
                  title: Text(menu.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${menu.category} | Durasi Masak: ${menu.cookingDurationMinutes} menit"),
                  leading: const Icon(Icons.restaurant_menu, color: Colors.orange),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Tombol Edit (UC12)
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _navigateToAddEdit(context, menu: menu),
                      ),
                      // Tombol Hapus (UC13)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                        onPressed: () => _deleteMenu(context, menu.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
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