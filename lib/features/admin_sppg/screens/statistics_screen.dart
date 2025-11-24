import 'package:fl_chart/fl_chart.dart'; // Import Library Grafik
import 'package:flutter/material.dart';
import '../services/stats_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  final StatsService _statsService = StatsService();
  
  Map<String, int>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _statsService.getDeliveryStats();
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
        title: const Text("Laporan Kinerja"),
        backgroundColor: Colors.indigo[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _stats == null 
              ? const Center(child: Text("Gagal memuat data."))
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        "Status Pengiriman Keseluruhan",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 30),
                      
                      // --- GRAFIK LINGKARAN (PIE CHART) ---
                      SizedBox(
                        height: 250,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 50,
                            sections: [
                              // Bagian Hijau (Sukses)
                              PieChartSectionData(
                                color: Colors.green,
                                value: _stats!['received']!.toDouble(),
                                title: '${_stats!['received']}',
                                radius: 60,
                                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              // Bagian Merah (Masalah)
                              PieChartSectionData(
                                color: Colors.red,
                                value: _stats!['issues']!.toDouble(),
                                title: '${_stats!['issues']}',
                                radius: 60,
                                titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              // Bagian Abu (Pending)
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

                      // --- KETERANGAN (LEGEND) ---
                      _buildLegend(Colors.green, "Sukses Diterima", _stats!['received']!),
                      _buildLegend(Colors.red, "Ada Masalah/Komplain", _stats!['issues']!),
                      _buildLegend(Colors.grey, "Dalam Proses", _stats!['pending']!),
                      
                      const Divider(height: 40),
                      
                      // Ringkasan Total
                      Card(
                        color: Colors.indigo[50],
                        child: ListTile(
                          leading: const Icon(Icons.analytics, color: Colors.indigo),
                          title: const Text("Total Aktivitas Pengiriman"),
                          trailing: Text(
                            "${_stats!['total']}", 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo)
                          ),
                        ),
                      )
                    ],
                  ),
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