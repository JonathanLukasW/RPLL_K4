class CourierModel {
  final String id;
  final String name; // Dipetakan dari full_name di tabel profiles
  final String email; 
  final String? sppgId; // SPPG tempat kurir bertugas

  CourierModel({
    required this.id,
    required this.name,
    required this.email,
    this.sppgId,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    return CourierModel(
      id: json['id'].toString(),
      name: json['full_name'] ?? 'Kurir Tanpa Nama',
      email: json['email'] ?? 'Email tidak tersedia',
      sppgId: json['sppg_id'],
    );
  }
}