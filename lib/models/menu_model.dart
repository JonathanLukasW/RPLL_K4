class Menu {
  final String id;
  final String sppgId;
  final String name;
  final String category; 
  final int cookingDurationMinutes;

  Menu({
    required this.id,
    required this.sppgId,
    required this.name,
    required this.category,
    required this.cookingDurationMinutes,
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'name': name,
      'category': category,
      'cooking_duration_minutes': cookingDurationMinutes,
    };
  }
}