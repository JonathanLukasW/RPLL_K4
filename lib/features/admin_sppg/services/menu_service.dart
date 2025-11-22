import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/menu_model.dart';
import '../../../models/sppg_model.dart';

class MenuService {
  final _supabase = Supabase.instance.client;

  Future<String> _getMySppgId() async {
    final userId = _supabase.auth.currentUser!.id;
    final profile = await _supabase.from('profiles').select('sppg_id').eq('id', userId).single();
    return profile['sppg_id'];
  }

  Future<List<Menu>> getMyMenus() async {
    try {
      final mySppgId = await _getMySppgId();
      
      final response = await _supabase
          .from('menus')
          .select()
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