class School {
  final String id;
  final String sppgId; 
  final String name;
  final String? address;
  final double? latitude;  
  final double? longitude; 
  final int studentCount;  
  final String? deadlineTime; 
  final int serviceTimeMinutes; 
  final bool isHighRisk; 
  
  // [BARU] Field untuk VRP Constraints
  final int toleranceMinutes;  
  final String? menuDefault;     

  School({
    required this.id,
    required this.sppgId,
    required this.name,
    this.address,
    this.latitude,
    this.longitude,
    this.studentCount = 0,
    this.deadlineTime,
    this.serviceTimeMinutes = 10,
    this.isHighRisk = false,
    this.toleranceMinutes = 45, // Default 45 menit
    this.menuDefault,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      name: json['name'] ?? 'Tanpa Nama Sekolah',
      address: json['address'],
      latitude: json['gps_lat'] != null ? double.tryParse(json['gps_lat'].toString()) : null,
      longitude: json['gps_long'] != null ? double.tryParse(json['gps_long'].toString()) : null,
      studentCount: json['student_count'] != null ? int.parse(json['student_count'].toString()) : 0,
      serviceTimeMinutes: json['service_time_minutes'] != null ? int.parse(json['service_time_minutes'].toString()) : 10,
      isHighRisk: json['is_high_risk'] ?? false,
      deadlineTime: json['deadline_time'],
      // [BARU] Parsing kolom tambahan
      toleranceMinutes: json['tolerance_minutes'] != null ? int.parse(json['tolerance_minutes'].toString()) : 45,
      menuDefault: json['menu_default'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'name': name,
      'address': address,
      'gps_lat': latitude,
      'gps_long': longitude,
      'student_count': studentCount,
      'deadline_time': deadlineTime,
      'service_time_minutes': serviceTimeMinutes,
      'is_high_risk': isHighRisk,
      // [BARU] Properti tambahan
      'tolerance_minutes': toleranceMinutes,
      'menu_default': menuDefault,
    };
  }
}