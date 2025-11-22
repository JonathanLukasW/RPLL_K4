class Sppg {
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone; 
  final double? latitude;
  final double? longitude;

  Sppg({
    required this.id,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.latitude,
    this.longitude,
  });

  // Menerima data JSON dari Supabase
  factory Sppg.fromJson(Map<String, dynamic> json) {
    return Sppg(
      id: json['id'].toString(),
      name: json['name'] ?? 'Tanpa Nama',    // FIX: Menggunakan 'name'
      address: json['address'],              // FIX: Menggunakan 'address'
      email: json['email'],
      phone: json['phone'],                  // FIX: Menggunakan 'phone'
      latitude: json['gps_lat'] != null ? double.parse(json['gps_lat'].toString()) : null,
      longitude: json['gps_long'] != null ? double.parse(json['gps_long'].toString()) : null,
    );
  }
}