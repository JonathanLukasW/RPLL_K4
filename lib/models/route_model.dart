class DeliveryRoute {
  final String id;
  final String date; // Format YYYY-MM-DD
  final String vehicleId;
  final String courierId;
  final String status; // pending, active, completed

  // Variabel tambahan untuk join (opsional, buat tampilan nanti)
  final String? vehiclePlate; 
  final String? courierName;

  DeliveryRoute({
    required this.id,
    required this.date,
    required this.vehicleId,
    required this.courierId,
    this.status = 'pending',
    this.vehiclePlate,
    this.courierName,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    return DeliveryRoute(
      id: json['id'].toString(),
      date: json['date'],
      vehicleId: json['vehicle_id'].toString(),
      courierId: json['courier_id'].toString(),
      status: json['status'] ?? 'pending',
      // Supabase bisa return nested object kalau kita select join
      vehiclePlate: json['vehicles']?['plate_number'], 
      courierName: json['profiles']?['full_name'],
    );
  }
}