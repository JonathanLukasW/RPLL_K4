import 'package:flutter/material.dart';
import '../services/teacher_service.dart';
import '../services/school_service.dart';
import '../../../models/school_model.dart';

class AddTeacherScreen extends StatefulWidget {
  const AddTeacherScreen({super.key});

  @override
  State<AddTeacherScreen> createState() => _AddTeacherScreenState();
}

class _AddTeacherScreenState extends State<AddTeacherScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController(); // Input Nama Kelas
  // [FIX 1]: Deklarasikan Controller Siswa Kelas
  final TextEditingController _classStudentCountController =
      TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController(); // [BARU]

  // [BARU] State Kuota
  int _totalSchoolCapacity = 0;
  int _allocatedCapacity = 0; // Kapasitas yang sudah diambil kelas lain

  final SchoolService _schoolService = SchoolService();
  List<School> _schools = [];
  String? _selectedSchoolId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchSchools();
  }

  // Diperbarui: Fetch Schools & Inisialisasi Kuota Sekolah
  Future<void> _fetchSchools() async {
    try {
      final data = await _schoolService.getMySchools();
      setState(() => _schools = data);

      // Jika sudah ada sekolah terpilih, load quota detailnya
      if (_selectedSchoolId != null) {
        await _loadQuotaDetails(_selectedSchoolId!);
      }
    } catch (e) {
      // Handle error
    }
  }

  // [BARU] Load Detail Kuota Sekolah
  Future<void> _loadQuotaDetails(String schoolId) async {
    try {
      final quota = await TeacherService().getSchoolQuotaDetails(
        schoolId,
        // Karena ini mode Add, tidak ada excludeUserId
      );
      if (mounted) {
        setState(() {
          _totalSchoolCapacity = quota['totalSchool'] ?? 0;
          _allocatedCapacity = quota['allocated'] ?? 0;
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

  // --- SUBMIT ---
  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      final int classCount =
          int.tryParse(_classStudentCountController.text) ?? 0;

      // Validasi Kuota Total
      if (classCount + _allocatedCapacity > _totalSchoolCapacity) {
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
        await TeacherService().createTeacherAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          fullName: _nameController.text.trim(),
          schoolId: _selectedSchoolId!,
          className: _classController.text.trim(),
          phoneNumber: _phoneController.text.trim(), // [BARU] Pass phone
          studentCountClass: classCount, // BARU
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Akun Wali Kelas Berhasil Dibuat!"),
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
  Widget build(BuildContext context) {
    final availableQuota = _totalSchoolCapacity - _allocatedCapacity;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tambah Akun Wali Kelas"),
        backgroundColor: Colors.orange[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Pilih Sekolah",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.school),
                  ),
                  value: _selectedSchoolId,
                  items: _schools.map((school) {
                    return DropdownMenuItem(
                      value: school.id,
                      child: Text(school.name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSchoolId = val;
                      // [FIX 2]: Ganti _portionController.clear() menjadi _classStudentCountController.clear()
                      _classStudentCountController.clear();

                      if (val != null) {
                        _loadQuotaDetails(val); // <-- Load Kuota Baru
                      } else {
                        _totalSchoolCapacity = 0;
                        _allocatedCapacity = 0;
                      }
                    });
                  },
                  validator: (val) =>
                      val == null ? "Wajib pilih sekolah" : null,
                ),
                const SizedBox(height: 15),

                // INFO QUOTA
                if (_selectedSchoolId != null && _totalSchoolCapacity > 0)
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Sudah Dialokasikan: $_allocatedCapacity Siswa",
                            style: const TextStyle(color: Colors.red),
                          ),
                          Text(
                            "Quota Tersedia: $availableQuota Siswa",
                            style: const TextStyle(color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Nama Guru / Penanggung Jawab",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _classController,
                  decoration: const InputDecoration(
                    labelText: "Nama Kelas (Misal: 7A)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.class_),
                  ),
                  validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                ),
                const SizedBox(height: 15),

                // [BARU] JUMLAH PENERIMA MANFAAT DI KELAS INI
                TextFormField(
                  controller: _classStudentCountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "Jml Penerima Kelas Ini",
                    hintText: "Maksimal: $availableQuota",
                    prefixIcon: const Icon(Icons.people),
                  ),
                  validator: (v) {
                    if (v!.isEmpty) return "Wajib diisi";
                    final count = int.tryParse(v) ?? 0;
                    if (count <= 0) return "Jumlah harus lebih dari 0";
                    if (count > availableQuota)
                      return "Melebihi kuota tersedia ($availableQuota)";
                    return null;
                  },
                ),
                const SizedBox(height: 15),
                // [BARU] Field Nomor Telepon
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Nomor Telepon",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: "Email Login",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                  ),
                  validator: (v) => v!.length < 6 ? "Minimal 6 karakter" : null,
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
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "BUAT AKUN WALI KELAS",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
