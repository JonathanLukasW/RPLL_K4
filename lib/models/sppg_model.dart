class Sppg {
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone; // Tambahan No Telp
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
      name: json['nama'] ?? 'Tanpa Nama', // Sesuai nama kolom DB
      address: json['alamat'],
      email: json['email'],
      phone: json['no_telp'],
      // Convert float8 Supabase ke double Dart
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
    );
  }
}