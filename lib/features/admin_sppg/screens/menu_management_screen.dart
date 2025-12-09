import 'package:flutter/material.dart';
import '../../../models/menu_model.dart';
import '../services/menu_service.dart';
import 'add_menu_screen.dart';
import 'add_menu_set_screen.dart'; // [BARU] Import Screen Menu Set

class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen>
    with SingleTickerProviderStateMixin {
  // Tambahkan Mixin
  late TabController _tabController; // [BARU] Tab Controller
  final MenuService _menuService = MenuService();

  // [BARU] State Menu Set List
  List<AdminMenuSetModel> _menuSets = [];
  bool _isLoadingSets = true;

  // [State Lama] State untuk Filter Menu
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
  ];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // [FIX KRITIS 1]: Tambahkan listener untuk refresh FAB saat tab berubah
    _tabController.addListener(() {
      if (mounted) {
        // Memastikan setState hanya dipanggil jika Index sudah settle
        if (!_tabController.indexIsChanging) {
          setState(() {
            // Ini akan memicu rebuild _buildFixedAddButton
          });
        }
      }
    });
    _fetchMenusAndSets();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // [BARU] Fetch Data Menu dan Menu Set
  Future<void> _fetchMenusAndSets() async {
    setState(() {
      _isLoadingSets = true;
      // Note: _fetchMenus() dipanggil di FutureBuilder, jadi tidak perlu di sini
    });
    try {
      final sets = await _menuService.getMyMenuSets();
      if (mounted) {
        setState(() {
          _menuSets = sets;
          _isLoadingSets = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error load Menu Set: $e")));
        setState(() => _isLoadingSets = false);
      }
    }
  }

  // Method untuk mengambil data menu (diperbarui untuk handle filter)
  Future<List<Menu>> _fetchMenus() async {
    // Dipanggil oleh FutureBuilder di Tab 1
    final allMenus = await _menuService.getMyMenus();
    if (_selectedCategoryFilter == null ||
        _selectedCategoryFilter == 'Semua Kategori') {
      return allMenus;
    }
    return allMenus
        .where((menu) => menu.category == _selectedCategoryFilter)
        .toList();
  }

  // Fungsi navigasi ke form tambah/edit Menu Reguler
  void _navigateToAddEdit(BuildContext context, {Menu? menu}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AddMenuScreen(menuToEdit: menu), // Jika menu null, berarti tambah
      ),
    ).then((result) {
      if (result == true) {
        setState(() {}); // Refresh tampilan list setelah kembali dari form
      }
    });
  }

  // Fungsi navigasi ke form tambah Menu Set
  void _navigateToAddMenuSet(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMenuSetScreen()),
    ).then((result) {
      if (result == true) {
        _fetchMenusAndSets(); // Refresh data Menu Set
      }
    });
  }

  // Fungsi navigasi ke form edit Menu Set
  void _navigateToEditMenuSet(BuildContext context, AdminMenuSetModel set) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMenuSetScreen(
          setToEdit: set,
        ), // Gunakan screen yang sama untuk edit
      ),
    ).then((result) {
      if (result == true) {
        _fetchMenusAndSets(); // Refresh data Menu Set
      }
    });
  }

  // [BARU] Fungsi Hapus Menu Set
  Future<void> _deleteMenuSet(
    BuildContext context,
    String menuSetId,
    String setName,
  ) async {
    final confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Menu Set?"),
        content: Text(
          "Yakin ingin menghapus set menu '$setName'? Tindakan ini tidak bisa dibatalkan.",
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
        await _menuService.deleteMenuSet(menuSetId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Menu Set berhasil dihapus!"),
            backgroundColor: Colors.green,
          ),
        );
        _fetchMenusAndSets(); // Refresh list Menu Set
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

  // [KRITIS] Tambahkan kembali helper _buildEmptyState
  Widget _buildEmptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 70, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(text, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Menu Produksi"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
        // [BARU] TabBar di bawah AppBar
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Semua Menu (Item)"),
            Tab(text: "Menu Set"), // Tab Baru
          ],
        ),
      ),
      body: Column(
        children: [
          // Expanded TabBarView
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllMenuList(), // Tab 1: Semua Menu Item
                _buildMenuSetList(), // Tab 2: Menu Set
              ],
            ),
          ),

          // Tombol Fixed (Akan berubah tergantung Tab yang dipilih)
          _buildFixedAddButton(context),
        ],
      ),
    );
  }

  // --- WIDGET TAB 1: SEMUA MENU ---
  Widget _buildAllMenuList() {
    return Column(
      children: [
        // 1. Filter Kategori
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
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedCategoryFilter = newValue;
              });
            },
          ),
        ),
        // 2. List Menu (Expanded)
        Expanded(
          child: FutureBuilder<List<Menu>>(
            future: _fetchMenus(),
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
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      title: Text(
                        menu.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      // [BARU] Tampilkan Gizi di Subtitle Menu Item
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${menu.category} | Masak: ${menu.cookingDurationMinutes} mnt | Batas Konsumsi: ${menu.maxConsumeMinutes} mnt",
                          ),
                          Text(
                            "Energi: ${menu.energy} Kkal | P: ${menu.protein.toStringAsFixed(1)}g | L: ${menu.fat.toStringAsFixed(1)}g | K: ${menu.carbs.toStringAsFixed(1)}g",
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.blueGrey,
                            ),
                          ),
                        ],
                      ),
                      isThreeLine: true, // Ubah ke 3 baris
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
                            onPressed: () =>
                                _deleteMenu(context, menu.id, menu.name),
                          ), // Pass name for confirmation
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
    );
  }

  // --- WIDGET TAB 2: MENU SET ---
  Widget _buildMenuSetList() {
    if (_isLoadingSets) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_menuSets.isEmpty) {
      return _buildEmptyState(
        "Belum ada Menu Set yang terdaftar.",
        Icons.set_meal,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _menuSets.length,
      itemBuilder: (ctx, i) {
        final set = _menuSets[i];
        final menuNames = set.menuNames.entries.map((e) => e.value).join(', ');

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: const Icon(
              Icons.collections_bookmark,
              color: Colors.indigo,
            ),
            title: Text(
              set.setName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(menuNames, maxLines: 2, overflow: TextOverflow.ellipsis),
                // [BARU] Tampilkan Total Gizi Menu Set
                Text(
                  "TOTAL GIZI: E: ${set.totalEnergy} Kkal | P: ${set.totalProtein.toStringAsFixed(1)}g | L: ${set.totalFat.toStringAsFixed(1)}g | K: ${set.totalCarbs.toStringAsFixed(1)}g",
                  style: const TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
            isThreeLine: true, // Agar subtitle terlihat penuh
            trailing: Row(
              // [FIX KRITIS 2]: Tambahkan Row untuk banyak trailing
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () =>
                      _navigateToEditMenuSet(context, set), // Navigasi ke Edit
                ),
                // [BARU] Tombol Delete Menu Set
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteMenuSet(context, set.id, set.setName),
                ),
              ],
            ),
            onTap: () {
              // Navigasi ke Edit juga untuk kemudahan
              _navigateToEditMenuSet(context, set);
            },
          ),
        );
      },
    );
  }

  // --- FLOATING ACTION BUTTON DINAMIS ---
  Widget _buildFixedAddButton(BuildContext context) {
    String label;
    VoidCallback onPressed;

    // [FIX KRITIS 3]: Mengambil index dari controller, yang di-update oleh listener
    final currentIndex = _tabController.index;

    // Logic untuk menentukan aksi berdasarkan tab saat ini
    if (currentIndex == 0) {
      label = "TAMBAH MENU BARU";
      onPressed = () => _navigateToAddEdit(context);
    } else {
      label = "TAMBAH MENU SET BARU";
      onPressed = () =>
          _navigateToAddMenuSet(context); // Navigasi ke AddMenuSetScreen
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[800],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          icon: const Icon(Icons.add),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }
}
