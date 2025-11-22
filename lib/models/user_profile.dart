class UserProfile {
  final String id;
  final String? email; // Email dari Auth Supabase
  final String? fullName;
  final String role; // 'bgn', 'admin_sppg', 'kurir', ...
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

  // FIX: Email dijadikan parameter opsional. Mengambil data dari profiles
  factory UserProfile.fromJson(Map<String, dynamic> json, [String? email]) { 
    return UserProfile(
      id: json['id'],
      email: email, // Email dapet dari parameter opsional di AuthService
      fullName: json['full_name'],
      role: json['role'] ?? 'unknown',
      sppgId: json['sppg_id'],
      schoolId: json['school_id'],
    );
  }
}