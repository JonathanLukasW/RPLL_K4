import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart'; 

import '../../autentikasi/screens/login_screen.dart';
import '../services/receiving_service.dart';
import '../../../core/services/storage_service.dart'; 
import '../../../core/screens/profile_screen.dart';
import 'coordinator_request_screen.dart'; 

class DashboardKoordinatorScreen extends StatefulWidget {
  const DashboardKoordinatorScreen({super.key});

  @override
  State<DashboardKoordinatorScreen> createState() => _DashboardKoordinatorScreenState();
}

class _DashboardKoordinatorScreenState extends State<DashboardKoordinatorScreen> {
  final ReceivingService _service = ReceivingService();
  final StorageService _storageService = StorageService();
  
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week; // Default Minggu biar ringkas
  
  Map<DateTime, List<dynamic>> _deliveries = {}; 
  bool _isLoading = true;

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
        // Parsing tanggal dari database (YYYY-MM-DD)
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

  // --- LOGIKA DIALOG ---
  void _showConfirmationDialog(String stopId) {
    final qtyController = TextEditingController();
    final noteController = TextEditingController();
    File? photoFile;
    bool isProblem = false; 
    bool isSubmitting = false;

    showDialog(context: context, barrierDismissible: false, builder: (ctx) => StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Konfirmasi Penerimaan"),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                    Expanded(child: ChoiceChip(label: const Text("✅ Aman"), selected: !isProblem, selectedColor: Colors.green[100], onSelected: (val) => setDialogState(() => isProblem = !val))),
                    const SizedBox(width: 10),
                    Expanded(child: ChoiceChip(label: const Text("⚠️ Masalah"), selected: isProblem, selectedColor: Colors.red[100], onSelected: (val) => setDialogState(() => isProblem = val))),
                ]),
                const SizedBox(height: 15),
                TextField(controller: qtyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Jml Diterima", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: noteController, decoration: InputDecoration(labelText: isProblem ? "Detail Kerusakan" : "Catatan", border: const OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 10),
                if (isProblem) GestureDetector(
                  onTap: () async {
                    final file = await _storageService.pickImage(ImageSource.camera);
                    if (file != null) setDialogState(() => photoFile = file);
                  },
                  child: Container(height: 100, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[200], border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)), child: photoFile == null ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.camera_alt), Text("FOTO BUKTI")]) : Image.file(photoFile!, fit: BoxFit.cover)),
                ),
                if (isSubmitting) const Padding(padding: EdgeInsets.only(top: 15), child: CircularProgressIndicator())
            ]),
          ),
          actions: [
            if (!isSubmitting) TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
            if (!isSubmitting) ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: isProblem ? Colors.red : Colors.teal, foregroundColor: Colors.white),
              onPressed: () async {
                if (isProblem && photoFile == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Wajib foto bukti!"))); return; }
                setDialogState(() => isSubmitting = true);
                try {
                  String? imageUrl;
                  if (photoFile != null) imageUrl = await _storageService.uploadEvidence(photoFile!, 'stops');
                  await _service.confirmReception(stopId: stopId, receivedQty: int.tryParse(qtyController.text) ?? 0, notes: isProblem ? "[MASALAH] ${noteController.text}" : noteController.text, recipientName: "Koordinator", issueType: isProblem ? 'problem' : null, proofUrl: imageUrl);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _fetchData(); 
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Laporan Terkirim!")));
                } catch (e) { setDialogState(() => isSubmitting = false); }
              },
              child: Text(isProblem ? "Lapor" : "Terima"),
            )
          ],
        );
      },
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jadwal & Status"), // Judul lebih relevan
        backgroundColor: Colors.teal[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.edit_document), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorRequestScreen()))),
          IconButton(icon: const Icon(Icons.account_circle, size: 30), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
        ],
      ),
      body: Column(
        children: [
           // HEADER & FILTER FORMAT
           Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Kalender Pengiriman:", style: TextStyle(fontWeight: FontWeight.bold)),
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

          // KALENDER
          TableCalendar(
            firstDay: DateTime(2024), lastDay: DateTime(2030),
            focusedDay: _focusedDay, currentDay: DateTime.now(),
            selectedDayPredicate: (d) => isSameDay(_selectedDay, d),
            calendarFormat: _calendarFormat,
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
            eventLoader: _getEventsForDay,
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              markerDecoration: BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
            ),
            onDaySelected: (sel, foc) { setState(() { _selectedDay = sel; _focusedDay = foc; }); },
            onPageChanged: (foc) { _focusedDay = foc; _fetchData(); },
          ),
          
          const Divider(thickness: 1),
          
          // LIST HARIAN
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _buildDayList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayList() {
    final events = _getEventsForDay(_selectedDay);
    
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 60, color: Colors.grey),
            const SizedBox(height: 10),
            Text("Tidak ada jadwal pada ${DateFormat('dd MMM').format(_selectedDay)}", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: events.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final item = events[index];
        final status = item['status'];
        final vehicle = item['delivery_routes']['vehicles'];
        final plat = vehicle != null ? vehicle['plate_number'] : '-';
        final driver = vehicle != null ? vehicle['driver_name'] : '-';

        // --- LOGIKA STATUS (Timeline Visual) ---
        String step1Title = "1. Produksi (Dapur)";
        String step1Status = "Selesai"; // Asumsi kalau rute udah dibuat, produksi on-going
        Color step1Color = Colors.green;

        String step2Title = "2. Distribusi (Kurir)";
        String step2Status = "Menunggu";
        Color step2Color = Colors.grey;

        String step3Title = "3. Penerimaan (Sekolah)";
        String step3Status = "Belum Tiba";
        Color step3Color = Colors.grey;
        bool showButton = false;

        if (status == 'active') {
          step2Status = "Sedang Berjalan 🚚";
          step2Color = Colors.blue;
        } else if (status == 'completed') {
          step2Status = "Sampai di Gerbang";
          step2Color = Colors.green;
          step3Status = "Perlu Konfirmasi Anda";
          step3Color = Colors.orange;
          showButton = true;
        } else if (status == 'received' || status == 'issue_reported') {
          step2Status = "Selesai";
          step2Color = Colors.green;
          step3Status = status == 'received' ? "Diterima Aman ✅" : "Ada Masalah ⚠️";
          step3Color = status == 'received' ? Colors.green : Colors.red;
        }

        return Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 15),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Armada: $plat", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(driver, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const Divider(),
                
                // TIMELINE PROSES
                _buildStep(step1Title, step1Status, step1Color, Icons.soup_kitchen),
                _buildLine(step2Color),
                _buildStep(step2Title, step2Status, step2Color, Icons.local_shipping),
                _buildLine(step3Color),
                _buildStep(step3Title, step3Status, step3Color, Icons.school),

                if (showButton) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _showConfirmationDialog(item['id']),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                      child: const Text("KONFIRMASI PENERIMAAN"),
                    ),
                  ),
                ]
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper Widget untuk Timeline
  Widget _buildStep(String title, String status, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ],
        )
      ],
    );
  }

  Widget _buildLine(Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 11, top: 2, bottom: 2),
      height: 15,
      width: 2,
      color: color.withOpacity(0.5),
    );
  }
}