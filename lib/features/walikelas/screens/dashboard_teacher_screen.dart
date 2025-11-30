import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../autentikasi/screens/login_screen.dart';
import '../services/teacher_reception_service.dart';
import '../../../core/services/storage_service.dart'; 
import '../../../core/screens/profile_screen.dart';

class DashboardTeacherScreen extends StatefulWidget {
  const DashboardTeacherScreen({super.key});

  @override
  State<DashboardTeacherScreen> createState() => _DashboardTeacherScreenState();
}

class _DashboardTeacherScreenState extends State<DashboardTeacherScreen> {
  final TeacherReceptionService _service = TeacherReceptionService();
  final StorageService _storageService = StorageService();

  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week; 

  Map<DateTime, List<dynamic>> _deliveries = {};
  bool _isLoading = true;
  String _className = "";

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getMonthlyDeliveries(_focusedDay);
      
      Map<DateTime, List<dynamic>> newMap = {};
      for (var item in data) {
        _className = item['my_class_name'] ?? "-";
        final dateStr = item['delivery_routes']['date'];
        final date = DateTime.parse(dateStr);
        final dateKey = DateTime(date.year, date.month, date.day);
        
        if (newMap[dateKey] == null) newMap[dateKey] = [];
        newMap[dateKey]!.add(item);
      }

      if (mounted) {
        setState(() {
          _deliveries = newMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dateKey = DateTime(day.year, day.month, day.day);
    return _deliveries[dateKey] ?? [];
  }

  void _showReceiveDialog(String stopId) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    File? photoFile;
    bool isProblem = false; 
    bool isSubmitting = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Laporan Kelas $_className"),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(children: [
                      Expanded(child: ChoiceChip(label: const Text("✅ Aman"), selected: !isProblem, selectedColor: Colors.green[100], onSelected: (val) => setDialogState(() => isProblem = !val))),
                      const SizedBox(width: 10),
                      Expanded(child: ChoiceChip(label: const Text("⚠️ Masalah"), selected: isProblem, selectedColor: Colors.red[100], onSelected: (val) => setDialogState(() => isProblem = val))),
                  ]),
                  const SizedBox(height: 15),
                  TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Box Diterima", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: noteController, decoration: InputDecoration(labelText: isProblem ? "Detail Masalah" : "Catatan", border: const OutlineInputBorder()), maxLines: 2),
                  const SizedBox(height: 10),
                  if (isProblem) GestureDetector(
                    onTap: () async {
                      final file = await _storageService.pickImage(ImageSource.camera);
                      if (file != null) setDialogState(() => photoFile = file);
                    },
                    child: Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], border: Border.all(color: Colors.grey)), child: photoFile == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("FOTO BUKTI")]) : Image.file(photoFile!, fit: BoxFit.cover)),
                  ),
                  if (isSubmitting) const Padding(padding: EdgeInsets.only(top: 10), child: CircularProgressIndicator())
              ]),
            ),
            actions: [
              if (!isSubmitting) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
              if (!isSubmitting) ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: isProblem ? Colors.red : Colors.indigo, foregroundColor: Colors.white),
                onPressed: () async {
                  if (isProblem && photoFile == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wajib foto!"))); return; }
                  setDialogState(() => isSubmitting = true);
                  try {
                    String? imageUrl;
                    if (photoFile != null) imageUrl = await _storageService.uploadEvidence(photoFile!, 'classroom_issues');
                    await _service.submitClassReception(stopId: stopId, className: _className, qty: int.tryParse(qtyController.text) ?? 0, notes: noteController.text, issueType: isProblem ? 'quality' : null, proofUrl: imageUrl);
                    if (!mounted) return; Navigator.pop(ctx); _fetchData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tersimpan!")));
                  } catch (e) { setDialogState(() => isSubmitting = false); }
                },
                child: const Text("Simpan"),
              )
            ],
          );
        }));
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_className.isNotEmpty ? "Kelas $_className" : "Wali Kelas"), 
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.account_circle, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())))],
      ),
      body: Column(
        children: [
           // HEADER FORMAT
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Jadwal Distribusi:", style: TextStyle(fontWeight: FontWeight.bold)),
                DropdownButtonHideUnderline(child: DropdownButton<CalendarFormat>(
                  value: _calendarFormat,
                  items: const [
                    DropdownMenuItem(value: CalendarFormat.month, child: Text("Bulan")),
                    DropdownMenuItem(value: CalendarFormat.week, child: Text("Minggu")),
                  ],
                  onChanged: (fmt) => setState(() => _calendarFormat = fmt!),
                )),
              ],
            ),
          ),

          TableCalendar(
            firstDay: DateTime(2024), lastDay: DateTime(2030),
            focusedDay: _focusedDay, currentDay: DateTime.now(),
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            calendarFormat: _calendarFormat,
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            eventLoader: _getEventsForDay,
            onDaySelected: (sel, foc) { setState(() { _selectedDay = sel; _focusedDay = foc; }); },
            onFormatChanged: (fmt) { setState(() => _calendarFormat = fmt); },
            onPageChanged: (foc) { _focusedDay = foc; _fetchData(); },
            calendarStyle: const CalendarStyle(todayDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle), selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle), markerDecoration: BoxDecoration(color: Colors.indigo, shape: BoxShape.circle)),
          ),
          
          const Divider(),
          
          Expanded(
            child: _isLoading ? const Center(child: CircularProgressIndicator()) : _buildDayList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayList() {
    final events = _getEventsForDay(_selectedDay);
    if (events.isEmpty) return const Center(child: Text("Tidak ada jadwal.", style: TextStyle(color: Colors.grey)));

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = events[index];
        final status = item['status'];
        final bool alreadyReceived = item['already_received'];

        // LOGIKA STATUS TIMELINE
        bool isDelivered = (status == 'completed' || status == 'received' || status == 'issue_reported');
        bool isConfirmed = (status == 'received' || status == 'issue_reported');

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Status Pengiriman:", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                _buildStep("1. Dapur & Kurir", "Selesai", Colors.green),
                _buildLine(isDelivered ? Colors.green : Colors.grey),
                _buildStep("2. Tiba di Gerbang", isDelivered ? "Sampai" : "Menunggu", isDelivered ? Colors.green : Colors.grey),
                _buildLine(isConfirmed ? Colors.green : Colors.grey),
                _buildStep("3. Cek Koordinator", isConfirmed ? "Sudah Dicek" : "Menunggu", isConfirmed ? Colors.green : Colors.orange),
                
                const Divider(height: 30),

                // TOMBOL AKSI WALI KELAS
                // Wali Kelas bisa ambil barang kalau barang sudah Tiba di Gerbang (Completed)
                // Walaupun Koordinator belum konfirmasi, Wali Kelas kadang butuh cepat (opsional, tergantung SOP).
                // Di sini kita buat: Harus Tiba dulu.
                if (isDelivered && !alreadyReceived)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showReceiveDialog(item['id']),
                      icon: const Icon(Icons.inventory),
                      label: const Text("TERIMA DI KELAS (QC)"),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    ),
                  )
                else if (alreadyReceived)
                  const Center(child: Text("✅ Sudah Diterima Kelas", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)))
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep(String title, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title),
        Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildLine(Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      height: 2,
      width: double.infinity,
      color: color.withOpacity(0.3),
    );
  }
}