class DeliveryRoute {
  final String id;
  final String date; // Format YYYY-MM-DD
  final String vehicleId;
  final String courierId;
  final String status; // pending, active, completed

  // [PENTING] Field Baru
  final String? departureTime; // Jam Berangkat (HH:mm:ss)

  // Variabel tambahan untuk join
  final String? vehiclePlate;
  final String? courierName;
  final String? menuName; // [BARU] Dari route_menus join
  final String? menuId; // [BARU] Dari route_menus join

  // [FIX KRITIS 1] Tambahkan field bukti muat
  final String? loadProofPhotoUrl; // Bukti Muat

  DeliveryRoute({
    required this.id,
    required this.date,
    required this.vehicleId,
    required this.courierId,
    this.status = 'pending',
    this.departureTime,
    this.loadProofPhotoUrl, // <--- TAMBAHKAN KE CONSTRUCTOR
    this.vehiclePlate,
    this.courierName,
    this.menuName,
    this.menuId,
  });

  factory DeliveryRoute.fromJson(Map<String, dynamic> json) {
    // Logic untuk membaca MenuName dan MenuId dari array join route_menus
    String? menuName;
    String? menuId;
    if (json['route_menus'] is List &&
        (json['route_menus'] as List).isNotEmpty) {
      final menuJson = (json['route_menus'] as List).first;
      if (menuJson['menus'] != null) {
        menuName = menuJson['menus']['name'];
        menuId = menuJson['menu_id'];
      }
    }

    // [FIX KRITIS 1]: Ambil data dari Map hasil JOIN (AdminReportService)
    final courierProfile = json['profiles!courier_id'] ?? json['profiles'];
    final vehicle = json['vehicles'];

    return DeliveryRoute(
      id: json['id'].toString(),
      date: json['date'],
      vehicleId: json['vehicle_id'].toString(),
      courierId: json['courier_id'].toString(),
      status: json['status'] ?? 'pending',

      // Ambil data departure_time dari database
      departureTime: json['departure_time'],

      // [FIX KRITIS 2]: Ambil load_proof_photo_url dari top level route
      loadProofPhotoUrl:
          json['load_proof_photo_url'], // <-- Dipastikan ada di model
      // Supabase join objects
      // [FIX 3]: Menggunakan null-check pada Map join
      vehiclePlate: vehicle?['plate_number'],
      courierName:
          courierProfile?['full_name'], // <-- Ambil nama kurir dari join yang benar
      menuName: menuName ?? 'Menu Tidak Ditemukan',
      menuId: menuId,
    );
  }
}
