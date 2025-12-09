import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/menu_model.dart';
import '../../../models/sppg_model.dart';
import 'dart:convert';
import 'package:collection/collection.dart';

// [BARU MODEL] Model untuk menyimpan Menu Set yang dibuat Admin
class AdminMenuSetModel {
  final String id;
  final String sppgId;
  final String setName;
  final String? karboId;
  final String? proteinId;
  final String? sayurId;
  final String? buahId;
  final String? nabatiId;
  final String? pelengkapId; // Opsional

  // [BARU TOTAL GIZI]
  final int totalEnergy;
  final double totalProtein;
  final double totalFat;
  final double totalCarbs;

  // NAMA MENU (untuk display di UI)
  final Map<String, String> menuNames;

  AdminMenuSetModel({
    required this.id,
    required this.sppgId,
    required this.setName,
    this.karboId,
    this.proteinId,
    this.sayurId,
    this.buahId,
    this.nabatiId,
    this.pelengkapId,
    required this.menuNames,
    // [BARU TOTAL GIZI]
    this.totalEnergy = 0,
    this.totalProtein = 0.0,
    this.totalFat = 0.0,
    this.totalCarbs = 0.0,
  });

  factory AdminMenuSetModel.fromJson(Map<String, dynamic> json) {
    // Helper untuk parsing double, default 0.0
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    // Logic untuk membaca menuNames dari join (jika ada)
    final Map<String, String> names = {};
    if (json['karbo_menus'] != null)
      names['Karbo'] = json['karbo_menus']['name'];
    if (json['protein_menus'] != null)
      names['Lauk Protein'] = json['protein_menus']['name'];
    if (json['sayur_menus'] != null)
      names['Sayur'] = json['sayur_menus']['name'];
    if (json['buah_menus'] != null) names['Buah'] = json['buah_menus']['name'];
    if (json['nabati_menus'] != null)
      names['Lauk Nabati'] = json['nabati_menus']['name'];
    if (json['pelengkap_menus'] != null)
      names['Pelengkap'] = json['pelengkap_menus']['name'];

    return AdminMenuSetModel(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      setName: json['set_name'] ?? 'Set Menu Baru',
      karboId: json['karbo_id']?.toString(),
      proteinId: json['protein_id']?.toString(),
      sayurId: json['sayur_id']?.toString(),
      buahId: json['buah_id']?.toString(),
      nabatiId: json['nabati_id']?.toString(),
      pelengkapId: json['pelengkap_id']?.toString(),
      menuNames: names,
      // [BARU TOTAL GIZI PARSING]
      totalEnergy: json['total_energy'] != null
          ? int.tryParse(json['total_energy'].toString()) ?? 0
          : 0,
      totalProtein: parseDouble(json['total_protein']),
      totalFat: parseDouble(json['total_fat']),
      totalCarbs: parseDouble(json['total_carbs']),
    );
  }
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

  // --- MENU SET CRUD ---

  // [BARU SERVICE] 4. Get All Menu Sets
  Future<List<AdminMenuSetModel>> getMyMenuSets() async {
    try {
      final mySppgId = await _getMySppgId();
      final response = await _supabase
          .from('menu_sets')
          .select(
            '*, karbo_menus:karbo_id(name), protein_menus:protein_id(name), sayur_menus:sayur_id(name), buah_menus:buah_id(name), nabati_menus:nabati_id(name), pelengkap_menus:pelengkap_id(name), total_energy, total_protein, total_fat, total_carbs', // <--- TAMBAHKAN FIELD TOTAL GIZI
          )
          .eq('sppg_id', mySppgId)
          .order('set_name', ascending: true);

      final List<dynamic> data = response;
      return data.map((json) => AdminMenuSetModel.fromJson(json)).toList();
    } catch (e) {
      // Throw error tanpa stack trace Supabase untuk UI yang lebih bersih
      throw Exception(
        'Gagal mengambil daftar Menu Set: ${e.toString().split("Exception:").last}',
      );
    }
  }

  // [BARU] 5. Create Menu Set (Perlu menerima data total gizi)
  Future<void> createMenuSet(Map<String, dynamic> menuSetData) async {
    try {
      final mySppgId = await _getMySppgId();
      menuSetData['sppg_id'] = mySppgId;
      await _supabase.from('menu_sets').insert(menuSetData);
    } catch (e) {
      throw Exception('Gagal menambah Menu Set: $e');
    }
  }

  // [BARU] 6. Update Menu Set (Untuk Edit Screen)
  Future<void> updateMenuSet(
    String menuSetId,
    Map<String, dynamic> menuSetData,
  ) async {
    try {
      await _supabase.from('menu_sets').update(menuSetData).eq('id', menuSetId);
    } catch (e) {
      throw Exception('Gagal mengedit Menu Set: $e');
    }
  }

  // [BARU] 7. Delete Menu Set
  Future<void> deleteMenuSet(String menuSetId) async {
    try {
      // Hapus Menu Set dari tabel menu_sets
      await _supabase.from('menu_sets').delete().eq('id', menuSetId);

      // Catatan: Jika ada sekolah yang masih menggunakan Menu Set ini (colomn menu_default menyimpan nama set),
      // maka column menu_default di sekolah tersebut mungkin perlu direset/update.
      // Namun, untuk saat ini, kita hanya menghapus set dari tabel menu_sets.
    } catch (e) {
      throw Exception('Gagal menghapus Menu Set: $e');
    }
  }

  // Perbarui select di getMyMenus agar mencakup kolom gizi
  Future<List<Menu>> getMyMenus() async {
    try {
      final mySppgId = await _getMySppgId();
      // [UPDATE SELECT] Tambahkan 4 kolom gizi baru
      final response = await _supabase
          .from('menus')
          .select(
            '*, max_consume_minutes, energy, protein, fat, carbs', // <--- TAMBAHKAN FIELD BARU
          )
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
