import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/menu_model.dart';
import '../../../models/sppg_model.dart';

// [BARU] STATIC DATA: Didefinisikan di service layer untuk digunakan oleh client.
class MenuSetDefinitions {
  // Menu Set 1: Stik Tempe, Spaghetti, Mix Vegetable, Chicken Bolognese, Melon Potong
  static const List<String> set1Names = [
    'Stik Tempe',
    'Spaghetti',
    'Mix Vegetable',
    'Chicken Bolognese',
    'Melon Potong',
  ];

  // Menu Set 2: French Fries, Wortel Jagung Steam, Chicken Dimsum, Semangka Potong, Saus Tomat Sachet
  static const List<String> set2Names = [
    'French Fries',
    'Wortel Jagung Steam',
    'Chicken Dimsum',
    'Semangka Potong',
    'Saus Tomat Sachet',
  ];

  // Menu Set 3: Nasi Putih, Ayam Geprek Katsu, Tumis Tahu Wortel, Timun & Tomat Iris, Melon Slice
  static const List<String> set3Names = [
    'Nasi Putih',
    'Ayam Geprek Katsu',
    'Tumis Tahu Wortel',
    'Timun & Tomat Iris',
    'Melon Slice',
  ];

  // Menu Set 4: Nasi Putih, Ayam Karage, Tahu Bejek Kemangi, Salad Coleslaw Mayo, Jeruk Manis
  static const List<String> set4Names = [
    'Nasi Putih',
    'Ayam Karage',
    'Tahu Bejek Kemangi',
    'Salad Coleslaw Mayo',
    'Jeruk Manis',
  ];

  // Menu Set 5: Chicken Katsu, Roti Bun (Burger), Lettuce & Tomat, Saus Mayonnaise, Melon Potong
  static const List<String> set5Names = [
    'Chicken Katsu',
    'Roti Bun (Burger)',
    'Lettuce & Tomat',
    'Saus Mayonnaise',
    'Melon Potong',
  ];

  static const Map<String, List<String>> predefinedSets = {
    'Menu Set 1 (Tempe)': set1Names,
    'Menu Set 2 (Dimsum)': set2Names,
    'Menu Set 3 (Geprek)': set3Names,
    'Menu Set 4 (Karage)': set4Names,
    'Menu Set 5 (Katsu Burger)': set5Names,
  };
}

class MenuService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase
        .from('profiles')
        .select('sppg_id')
        .eq('id', userId)
        .single();
    return profile['sppg_id'];
  }

  Future<List<Menu>> getMyMenus() async {
    try {
      final mySppgId = await _getMySppgId();
      // [UPDATE SELECT] Tambahkan max_consume_minutes
      final response = await _supabase
          .from('menus')
          .select('*, max_consume_minutes') // <-- TAMBAHKAN FIELD BARU DI SINI
          .eq('sppg_id', mySppgId)
          .order('category', ascending: true);

      final List<dynamic> data = response;
      return data.map((json) => Menu.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Gagal mengambil daftar menu: $e');
    }
  }

  Future<void> createMenu(Map<String, dynamic> menuData) async {
    try {
      final mySppgId = await _getMySppgId();

      menuData['sppg_id'] = mySppgId;

      await _supabase.from('menus').insert(menuData);
    } catch (e) {
      throw Exception('Gagal menambah menu: $e');
    }
  }

  Future<void> updateMenu(String menuId, Map<String, dynamic> menuData) async {
    try {
      // [FIX LOGIC] Memastikan data menu yang diupdate sudah termasuk field baru
      await _supabase.from('menus').update(menuData).eq('id', menuId);
    } catch (e) {
      throw Exception('Gagal mengedit menu: $e');
    }
  }

  Future<void> deleteMenu(String menuId) async {
    try {
      await _supabase.from('menus').delete().eq('id', menuId);
    } catch (e) {
      throw Exception('Gagal menghapus menu: $e');
    }
  }
}
