// === FILE: lib/models/menu_model.dart ===
// ...
class Menu {
  final String id;
  final String sppgId;
  final String name;
  final String category;
  final int cookingDurationMinutes;
  // [BARU] Waktu maksimal konsumsi setelah masak/terima (menit)
  final int maxConsumeMinutes;

  // [BARU GIZI]
  final int energy;
  final double protein;
  final double fat;
  final double carbs;

  Menu({
    required this.id,
    required this.sppgId,
    required this.name,
    required this.category,
    required this.cookingDurationMinutes,
    required this.maxConsumeMinutes, // [BARU]
    // [BARU GIZI]
    this.energy = 0,
    this.protein = 0.0,
    this.fat = 0.0,
    this.carbs = 0.0,
  });

  factory Menu.fromJson(Map<String, dynamic> json) {
    // Helper untuk parsing double, default 0.0
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Menu(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      name: json['name'] ?? 'Menu Baru',
      category: json['category'] ?? 'Lain-lain',
      cookingDurationMinutes: json['cooking_duration_minutes'] != null
          ? int.parse(json['cooking_duration_minutes'].toString())
          : 0,
      maxConsumeMinutes: json['max_consume_minutes'] != null
          ? int.parse(json['max_consume_minutes'].toString())
          : 120,
      // [BARU GIZI]
      energy: json['energy'] != null
          ? int.tryParse(json['energy'].toString()) ?? 0
          : 0,
      protein: parseDouble(json['protein']),
      fat: parseDouble(json['fat']),
      carbs: parseDouble(json['carbs']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'name': name,
      'category': category,
      'cooking_duration_minutes': cookingDurationMinutes,
      'max_consume_minutes': maxConsumeMinutes,
      // [BARU GIZI]
      'energy': energy,
      'protein': protein,
      'fat': fat,
      'carbs': carbs,
    };
  }
}
