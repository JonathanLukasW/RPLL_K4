// FILE: lib/models/menu_model.dart

class Menu {
  final String id;
  final String sppgId;
  final String name;
  final String category;
  final int cookingDurationMinutes;
  // [BARU] Waktu maksimal konsumsi setelah masak/terima (menit)
  final int maxConsumeMinutes;

  Menu({
    required this.id,
    required this.sppgId,
    required this.name,
    required this.category,
    required this.cookingDurationMinutes,
    required this.maxConsumeMinutes, // [BARU]
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    return Menu(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      name: json['name'] ?? 'Menu Baru',
      category: json['category'] ?? 'Lain-lain',
      cookingDurationMinutes: json['cooking_duration_minutes'] != null
          ? int.parse(json['cooking_duration_minutes'].toString())
          : 0,
      // [BARU] Parsing field baru, default 120 menit (2 jam)
      maxConsumeMinutes: json['max_consume_minutes'] != null
          ? int.parse(json['max_consume_minutes'].toString())
          : 120,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'name': name,
      'category': category,
      'cooking_duration_minutes': cookingDurationMinutes,
      // [BARU] Tambahkan field baru saat kirim data
      'max_consume_minutes': maxConsumeMinutes,
    };
  }
}
