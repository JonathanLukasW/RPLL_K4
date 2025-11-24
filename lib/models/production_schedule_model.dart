class ProductionSchedule {
  final String id;
  final DateTime date;
  final String menuId;
  final String menuName; // Dari relasi
  final int totalPortions;
  final String? startCookingTime; // Format "HH:mm:ss"
  final String? targetFinishTime; // Format "HH:mm:ss"
  final String? notes;

  ProductionSchedule({
    required this.id,
    required this.date,
    required this.menuId,
    required this.menuName,
    required this.totalPortions,
    this.startCookingTime,
    this.targetFinishTime,
    this.notes,
  });

  factory ProductionSchedule.fromJson(Map<String, dynamic> json) {
    return ProductionSchedule(
      id: json['id'].toString(),
      date: DateTime.parse(json['date']),
      menuId: json['menu_id'].toString(),
      menuName: json['menus'] != null ? json['menus']['name'] : 'Menu ?',
      totalPortions: json['total_portions'] != null ? int.parse(json['total_portions'].toString()) : 0,
      startCookingTime: json['start_cooking_time'],
      targetFinishTime: json['target_finish_time'],
      notes: json['notes'],
    );
  }
}