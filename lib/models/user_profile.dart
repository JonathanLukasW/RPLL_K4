// FILE: lib/models/user_profile.dart

class UserProfile {
  final String id;
  final String? email;
  final String? fullName;
  final String role;
  final String? sppgId;
  final String? schoolId;
  // [BARU] Nomor Telepon
  final String? phoneNumber;

  UserProfile({
    required this.id,
    this.email,
    this.fullName,
    required this.role,
    this.sppgId,
    this.schoolId,
    this.phoneNumber, // [BARU]
  });

  // FIX: Email dijadikan parameter opsional. Mengambil data dari profiles
  factory UserProfile.fromJson(Map<String, dynamic> json, [String? email]) {
    return UserProfile(
      id: json['id'],
      email: email,
      fullName: json['full_name'],
      role: json['role'] ?? 'unknown',
      sppgId: json['sppg_id'],
      schoolId: json['school_id'],
      phoneNumber:
          json['phone_number'], // [BARU] Ambil dari kolom 'phone_number' atau 'phone'
    );
  }
}
