class Sppg {
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final double? latitude;
  final double? longitude;
  // [BARU]
  final String? establishedDate; 

  Sppg({
    required this.id,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.latitude,
    this.longitude,
    this.establishedDate,
  });

  factory Sppg.fromJson(Map<String, dynamic> json) {
    return Sppg(
      id: json['id'].toString(),
      name: json['name'] ?? 'Tanpa Nama',
      address: json['address'],
      email: json['email'],
      phone: json['phone'],
      latitude: json['gps_lat'] != null ? double.tryParse(json['gps_lat'].toString()) : null,
      longitude: json['gps_long'] != null ? double.tryParse(json['gps_long'].toString()) : null,
      // [BARU]
      establishedDate: json['established_date'],
    );
  }
}