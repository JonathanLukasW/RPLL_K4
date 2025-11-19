class Vehicle {
  final String id;
  final String sppgId;
  final String plateNumber; // Plat Nomor
  final String? driverName; // Nama Supir
  final int capacityLimit;  // Kapasitas Angkut (Porsi)
  final bool isActive;      // Status Siap Jalan?

  Vehicle({
    required this.id,
    required this.sppgId,
    required this.plateNumber,
    this.driverName,
    this.capacityLimit = 0,
    this.isActive = true,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      plateNumber: json['plate_number'] ?? 'Tanpa Plat',
      driverName: json['driver_name'],
      capacityLimit: json['capacity_limit'] != null ? int.parse(json['capacity_limit'].toString()) : 0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'plate_number': plateNumber,
      'driver_name': driverName,
      'capacity_limit': capacityLimit,
      'is_active': isActive,
    };
  }
}