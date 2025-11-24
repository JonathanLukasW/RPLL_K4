import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../services/bgn_monitoring_service.dart';

class BgnStatisticsScreen extends StatefulWidget {
  const BgnStatisticsScreen({super.key});

  @override
  State<BgnStatisticsScreen> createState() => _BgnStatisticsScreenState();
}

class _BgnStatisticsScreenState extends State<BgnStatisticsScreen> {
  final BgnMonitoringService _service = BgnMonitoringService();
  
  List<Map<String, dynamic>> _sppgList = []; // Daftar SPPG untuk Dropdown
  String? _selectedSppgId; // ID yang dipilih
  
  Map<String, int>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // 1. Load Daftar SPPG dulu
  Future<void> _loadInitialData() async {
    try {
      final list = await _service.getSppgList();
      setState(() {
        _sppgList = list;
        if (list.isNotEmpty) {
          _selectedSppgId = list[0]['id']; // Default pilih yang pertama
          _loadStats(_selectedSppgId!); // Langsung load statistiknya
        } else {
          _isLoading = false;
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // 2. Load Statistik berdasarkan ID
  Future<void> _loadStats(String sppgId) async {
    setState(() => _isLoading = true);
    try {
      final data = await _service.getSppgStats(sppgId);
      setState(() {
        _stats = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analisis Kinerja SPPG"),
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // --- DROPDOWN PILIH SPPG ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSppgId,
                  hint: const Text("Pilih Dapur SPPG..."),
                  items: _sppgList.map((sppg) {
                    return DropdownMenuItem(
                      value: sppg['id'].toString(),
                      child: Text(sppg['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedSppgId = val);
                      _loadStats(val); // Reload grafik
                    }
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 20),

            // --- KONTEN GRAFIK ---
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _stats == null
                      ? const Center(child: Text("Pilih SPPG untuk melihat data."))
                      : _buildChartContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContent() {
    // Cek jika data kosong semua
    if (_stats!['total'] == 0) {
      return const Center(child: Text("Belum ada data pengiriman untuk SPPG ini."));
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          const Text("Distribusi Status Pengiriman", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 30),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: Colors.green,
                    value: _stats!['received']!.toDouble(),
                    title: '${_stats!['received']}',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.red,
                    value: _stats!['issues']!.toDouble(),
                    title: '${_stats!['issues']}',
                    radius: 60,
                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: Colors.grey,
                    value: _stats!['pending']!.toDouble(),
                    title: '${_stats!['pending']}',
                    radius: 50,
                    titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          _buildLegend(Colors.green, "Sukses Diterima", _stats!['received']!),
          _buildLegend(Colors.red, "Insiden/Komplain", _stats!['issues']!),
          _buildLegend(Colors.grey, "Dalam Proses", _stats!['pending']!),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 20),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 16)),
          const Spacer(),
          Text("$value", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}