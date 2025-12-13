import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/coordinator_service.dart';
import '../services/teacher_service.dart';
import '../services/courier_service.dart';
import '../services/school_service.dart';
import '../../../models/school_model.dart';
import 'package:collection/collection.dart';

class EditAccountScreen extends StatefulWidget {
  final String userId;
  final String initialRole;
  final Map<String, dynamic> initialData;

  const EditAccountScreen({
    super.key,
    required this.userId,
    required this.initialRole,
    required this.initialData,
  });

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _classController;
  late final TextEditingController _phoneController;
  // [BARU] Controller untuk menampilkan nama sekolah saat ini (uneditable)
  late final TextEditingController _currentSchoolNameController;

  // [BARU] Controller Siswa Kelas
  late final TextEditingController _classStudentCountController;

  // [BARU] State Kuota
  int _totalSchoolCapacity = 0;
  int _allocatedCapacity = 0;

  List<School> _schools = [];
  String? _selectedSchoolId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _emailController = TextEditingController(text: widget.initialData['email']);
    _phoneController = TextEditingController(
      text: widget.initialData['phoneNumber'],
    );
    _classController = TextEditingController(
      text: widget.initialData['className'],
    );
    _selectedSchoolId = widget.initialData['schoolId'];

    // [FIX 1: Ambil nama sekolah dari initialData untuk preview]
    // Ambil nama sekolah dari data yang dilempar dari dashboard (sudah fix di atas)
    final String currentSchoolName =
        widget.initialData['schoolName'] ?? 'Belum Ditugaskan';
    _currentSchoolNameController = TextEditingController(
      text: currentSchoolName,
    ); // <--- INI SUDAH BENAR

    // [BARU] Initialize class student count (memastikan tipenya num/int)
    _classStudentCountController = TextEditingController(
      text: widget.initialData['studentCountClass']?.toString() ?? '0',
    );

    // Masalah: _selectedSchoolId akan ter-set ke null jika tidak ada (meski ada nama)
    // Biarkan _selectedSchoolId default dari initialData['schoolId'].

    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    final schoolService = SchoolService();
    try {
      // 1. Coba ambil profile role user yang sedang login
      final userProfile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', Supabase.instance.client.auth.currentUser!.id)
          .single();
      final String userRole = userProfile['role'];

      // Jika user login adalah BGN, kita tidak perlu (dan tidak bisa) memuat list sekolah.
      if (userRole.toLowerCase() == 'bgn') {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return; // Stop processing for BGN user
      }

      // 2. Jika bukan BGN (Admin SPPG), lanjutkan memuat data sekolah
      final data = await schoolService.getMySchools();
      if (widget.initialRole == 'walikelas' &&
          widget.initialData['schoolId'] != null) {
        await _loadQuotaDetails(
          widget.initialData['schoolId']!,
          excludeUserId: widget.userId,
        );
      }

      if (!mounted) return;
      setState(() {
        _schools = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Ini akan menangkap error "User profile tidak memiliki ID SPPG. Akses Ditolak!"
      // yang memang dilempar SchoolService jika yang login BGN/profil rusak.
      if (e.toString().contains("Akses Ditolak")) {
        print("BGN User accessing Admin screen. School list skipped.");
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error loading schools: $e")));
      }
      setState(() => _isLoading = false);
    }
  }

  // [BARU] Load Detail Kuota Sekolah
  Future<void> _loadQuotaDetails(
    String schoolId, {
    String? excludeUserId,
  }) async {
    try {
      final quota = await TeacherService().getSchoolQuotaDetails(
        schoolId,
        excludeUserId: excludeUserId,
      );
      if (mounted) {
        setState(() {
          _totalSchoolCapacity = quota['totalSchool'] ?? 0;
          _allocatedCapacity = quota['allocated'] ?? 0;
          // Tidak perlu memanggil setState di sini karena sudah dipanggil di caller.
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error load kuota: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final int classCount =
          int.tryParse(_classStudentCountController.text) ?? 0;
      final availableQuota = _totalSchoolCapacity - _allocatedCapacity;
      // Hitung kembali maxAllowed agar sinkron
      final initialClassCount = widget.initialData['studentCountClass'] ?? 0;
      final maxAllowed =
          (_totalSchoolCapacity - _allocatedCapacity) + initialClassCount;

      // Validasi Kuota Total
      if (classCount > maxAllowed) {
        // <-- Menggunakan maxAllowed yang benar
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Jumlah siswa melebihi kuota sekolah yang tersedia!"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);
      try {
        final Map<String, dynamic> data = {
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone_number': _phoneController.text
              .trim(), // [BARU] Tambahkan phone number
          'school_id': _selectedSchoolId,
        };

        if (widget.initialRole == 'koordinator' ||
            widget.initialRole == 'walikelas') {
          data['school_id'] = _selectedSchoolId;
        }
        if (widget.initialRole == 'walikelas') {
          data['class_name'] = _classController.text.trim();
          data['student_count_class'] = classCount; // BARU
        }

        // Panggil service yang sesuai
        if (widget.initialRole == 'kurir') {
          await CourierService().updateCourierAccount(widget.userId, data);
        } else if (widget.initialRole == 'koordinator') {
          await CoordinatorService().updateCoordinatorAccount(
            widget.userId,
            data,
          );
        } else if (widget.initialRole == 'walikelas') {
          await TeacherService().updateTeacherAccount(widget.userId, data);
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akun berhasil diperbarui!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _classController.dispose();
    _phoneController.dispose(); // [BARU] Dispose phone controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // [FIX KRITIS 4]: Hitung maxAllowed di build agar responsif
    final isWaliKelas = widget.initialRole == 'walikelas';
    final currentClassCount = widget.initialData['studentCountClass'] ?? 0;

    // Max yang boleh diinput saat edit = (Total Sekolah - Alokasi Kelas Lain) + Porsi Kelas Saat Ini
    final maxAllowed =
        (_totalSchoolCapacity - _allocatedCapacity) + currentClassCount;
    // Cari nama sekolah yang saat ini dipilih (untuk display di dropdown)
    final selectedSchool = _schools.firstWhereOrNull(
      (s) => s.id == _selectedSchoolId,
    );
    final availableQuota = _totalSchoolCapacity - _allocatedCapacity;

    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Akun ${widget.initialRole.toUpperCase()}"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: "Nama Lengkap",
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _phoneController, // [BARU] Phone Field
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Nomor Telepon",
                        prefixIcon: Icon(Icons.phone),
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: "Email Login",
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                    const SizedBox(height: 15),

                    // Field Khusus Koordinator & Wali Kelas
                    if (widget.initialRole == 'koordinator' ||
                        widget.initialRole == 'walikelas') ...[
                      // [FIX PREVIEW] Tampilkan Sekolah yang Ditugaskan Saat Ini (Uneditable)
                      TextFormField(
                        controller: _currentSchoolNameController,
                        decoration: const InputDecoration(
                          labelText: "Sekolah Ditugaskan Saat Ini",
                          prefixIcon: Icon(Icons.school),
                        ),
                        readOnly: true,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // DROPDOWN UNTUK MENGGANTI SEKOLAH
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Ganti Sekolah Tujuan (Opsional)",
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                        // [FIX 3: Gunakan _selectedSchoolId sebagai value awal]
                        // Ini memastikan nilai awal di dropdown sesuai dengan yang ditugaskan saat ini.
                        value: _selectedSchoolId,
                        items: [
                          // Tambahkan opsi untuk 'Tidak Ditugaskan' (NULL)
                          const DropdownMenuItem(
                            value: null,
                            child: Text('--- Tidak Ditugaskan ---'),
                          ),
                          // List Sekolah yang tersedia
                          ..._schools.map((school) {
                            return DropdownMenuItem(
                              value: school.id,
                              // Tampilkan nama sekolah, pastikan tidak crash
                              child: Text(
                                school.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedSchoolId = val;
                            // [FIX KRITIS 4: Update TextController ketika pilihan diubah]
                            if (val != null) {
                              final newSchool = _schools.firstWhereOrNull(
                                (s) => s.id == val,
                              );
                              // Tampilkan nama sekolah baru yang dipilih
                              _currentSchoolNameController.text =
                                  newSchool?.name ?? 'Sekolah tidak ditemukan';
                            } else {
                              // Jika memilih 'Tidak Ditugaskan' (null)
                              _currentSchoolNameController.text =
                                  'Belum Ditugaskan';
                            }
                          });
                        },
                        validator: (val) =>
                            null, // Biarkan validasi di _submit() saja jika field ini diisi
                      ),
                      const SizedBox(height: 15),
                    ],

                    // Field Khusus Wali Kelas
                    if (isWaliKelas) ...[
                      TextFormField(
                        controller: _classController,
                        decoration: const InputDecoration(
                          labelText: "Nama Kelas (Misal: 7A)",
                          prefixIcon: Icon(Icons.class_),
                        ),
                        validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                      ),
                      const SizedBox(height: 15),

                      // INFO KUOTA SEKOLAH
                      if (isWaliKelas && _totalSchoolCapacity > 0)
                        Card(
                          color: Colors.blue[50],
                          margin: const EdgeInsets.only(bottom: 15),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Total Siswa Sekolah: $_totalSchoolCapacity",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Dialokasikan Kelas Lain: $_allocatedCapacity Siswa",
                                  style: const TextStyle(color: Colors.red),
                                ),
                                Text(
                                  "Quota Max Kelas Ini: $maxAllowed Siswa",
                                  style: const TextStyle(color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // [BARU] JUMLAH PENERIMA MANFAAT DI KELAS INI
                      // ... (TextFormField Jml Penerima Kelas Ini) ...
                      TextFormField(
                        controller: _classStudentCountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: "Jml Penerima Kelas Ini",
                          hintText:
                              "Maksimal: $maxAllowed", // <-- Menampilkan maxAllowed yang benar
                          prefixIcon: const Icon(Icons.people),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return "Wajib diisi";
                          final count = int.tryParse(v) ?? 0;
                          if (count <= 0) return "Jumlah harus lebih dari 0";
                          if (count > maxAllowed)
                            return "Melebihi kuota tersedia ($maxAllowed)";
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange[800],
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text(
                                  "SIMPAN PERUBAHAN",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
