class UserProfile {
  final String id;
  final String? email; // Email dari Auth Supabase
  final String? fullName;
  final String role; // 'bgn', 'admin_sppg', 'kurir', 'koordinator', 'walikelas'
  final String? sppgId;
  final String? schoolId;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    required this.role,
    this.sppgId,
    this.schoolId,
  });

  // Fungsi untuk mengubah data JSON dari Supabase menjadi Objek Dart
  factory UserProfile.fromJson(Map<String, dynamic> json, String? email) {
    return UserProfile(
      id: json['id'],
      email: email,
      fullName: json['full_name'],
      role: json['role'] ?? 'unknown', // Default kalau kosong
      sppgId: json['sppg_id'],
      schoolId: json['school_id'],
    );
  }
}