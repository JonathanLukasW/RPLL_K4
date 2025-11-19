class Sppg {
  final String id;
  final String name;
  final String? address;
  final double? lat;
  final double? long;

  Sppg({
    required this.id,
    required this.name,
    this.address,
    this.lat,
    this.long,
  });

  // Dari JSON (Database) ke Dart
  factory Sppg.fromJson(Map<String, dynamic> json) {
    return Sppg(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lat: json['gps_lat'],   // Perhatikan nama kolom di SQL tadi
      long: json['gps_long'], // Perhatikan nama kolom di SQL tadi
    );
  }

  // Dari Dart ke JSON (Untuk kirim ke Database)
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'address': address,
      'gps_lat': lat,
      'gps_long': long,
    };
  }
}