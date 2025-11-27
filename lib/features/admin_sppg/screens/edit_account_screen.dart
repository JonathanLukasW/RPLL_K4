import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/coordinator_service.dart';
import '../services/teacher_service.dart';
import '../services/courier_service.dart';
import '../services/school_service.dart';
import '../../../models/school_model.dart';

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

  List<School> _schools = [];
  String? _selectedSchoolId;
  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _emailController = TextEditingController(text: widget.initialData['email']);
    _classController = TextEditingController(
      text: widget.initialData['className'],
    );
    _selectedSchoolId = widget.initialData['schoolId'];
    _fetchSchools();
  }

  Future<void> _fetchSchools() async {
    try {
      final data = await SchoolService().getMySchools();
      if (!mounted) return;
      setState(() {
        _schools = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error loading schools: $e")));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);
      try {
        final Map<String, dynamic> data = {
          'full_name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
        };

        if (widget.initialRole == 'koordinator' ||
            widget.initialRole == 'walikelas') {
          data['school_id'] = _selectedSchoolId;
        }
        if (widget.initialRole == 'walikelas') {
          data['class_name'] = _classController.text.trim();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        widget.initialRole == 'walikelas')
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: "Tugaskan di Sekolah",
                          prefixIcon: Icon(Icons.school),
                        ),
                        value: _selectedSchoolId,
                        items: _schools.map((school) {
                          return DropdownMenuItem(
                            value: school.id,
                            child: Text(
                              school.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSchoolId = val),
                        validator: (val) =>
                            val == null ? "Wajib pilih sekolah" : null,
                      ),
                    const SizedBox(height: 15),

                    // Field Khusus Wali Kelas
                    if (widget.initialRole == 'walikelas')
                      TextFormField(
                        controller: _classController,
                        decoration: const InputDecoration(
                          labelText: "Nama Kelas (Misal: 7A)",
                          prefixIcon: Icon(Icons.class_),
                        ),
                        validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
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
                ),
              ),
            ),
    );
  }
}
