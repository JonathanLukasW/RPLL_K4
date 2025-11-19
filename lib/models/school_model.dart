class School {
  final String id;
  final String sppgId; // Relasi ke SPPG
  final String name;
  final String? address;
  final double? latitude;  // DB: gps_lat
  final double? longitude; // DB: gps_long
  final int studentCount;  // DB: student_count
  final String? deadlineTime; // DB: deadline_time (Format "HH:mm:ss")
  final int serviceTimeMinutes; // DB: service_time_minutes
  final bool isHighRisk; // DB: is_high_risk

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
  });

  // Factory: Mengubah JSON dari Database menjadi Object School
  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      name: json['name'] ?? 'Tanpa Nama Sekolah',
      address: json['address'],
      // Parsing angka desimal dengan aman
      latitude: json['gps_lat'] != null ? double.tryParse(json['gps_lat'].toString()) : null,
      longitude: json['gps_long'] != null ? double.tryParse(json['gps_long'].toString()) : null,
      // Parsing integer
      studentCount: json['student_count'] != null ? int.parse(json['student_count'].toString()) : 0,
      serviceTimeMinutes: json['service_time_minutes'] != null ? int.parse(json['service_time_minutes'].toString()) : 10,
      // Parsing boolean & Time
      isHighRisk: json['is_high_risk'] ?? false,
      deadlineTime: json['deadline_time'], // Supabase balikin string "12:00:00"
    );
  }

  // Method: Mengubah Object School menjadi JSON (Buat dikirim balik kalau perlu)
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
    };
  }
}