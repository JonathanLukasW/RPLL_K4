// === FILE: lib/models/vehicle_model.dart ===

class Vehicle {
  final String id;
  final String sppgId;
  final String plateNumber; // Plat Nomor
  final String? driverName; // Nama Supir (Main Driver)
  final int capacityLimit; // Kapasitas Angkut (Porsi)
  final bool isActive; // Status Siap Jalan?
  final String? courierProfileId;

  // [BARU] Assistant Courier
  final String? assistantCourierId;
  final String? assistantCourierName;

  Vehicle({
    required this.id,
    required this.sppgId,
    required this.plateNumber,
    this.driverName,
    this.capacityLimit = 0,
    this.isActive = true,
    this.courierProfileId,

    // [BARU]
    this.assistantCourierId,
    this.assistantCourierName,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    // [FIX KRITIS ALIAS PROFILES]: Update cara mengambil data join
    final Map<String, dynamic>? primaryProfile =
        json['profiles!courier_profile_id'];
    final Map<String, dynamic>? assistantProfile =
        json['profiles_assist']; // <--- AMBIL DARI ALIAS BARU

    return Vehicle(
      id: json['id'].toString(),
      sppgId: json['sppg_id'].toString(),
      plateNumber: json['plate_number'] ?? 'Tanpa Plat',
      driverName: primaryProfile?['full_name'] ?? json['driver_name'],
      capacityLimit: json['capacity_limit'] != null
          ? int.parse(json['capacity_limit'].toString())
          : 0,
      isActive: json['is_active'] ?? true,
      courierProfileId: json['courier_profile_id']?.toString(),

      // [BARU]
      assistantCourierId: json['assistant_courier_id']?.toString(),
      assistantCourierName:
          assistantProfile?['full_name'], // <--- Ambil dari alias profiles_assist
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'sppg_id': sppgId,
      'plate_number': plateNumber,
      'driver_name': driverName,
      'capacity_limit': capacityLimit,
      'is_active': isActive,
      'courier_profile_id': courierProfileId,
      // [BARU]
      'assistant_courier_id': assistantCourierId,
    };
  }
}
