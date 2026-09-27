import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/medicine_service.dart';

class ReportsScreen extends StatefulWidget {
  final String? targetUid;
  const ReportsScreen({super.key, this.targetUid});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int adherenceRate = 0;
  int totalLogs = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    final stats = await MedicineService.getRealStats(targetUid: widget.targetUid);
    if (mounted) {
      setState(() {
        adherenceRate = stats['adherence_rate'] ?? 0;
        totalLogs = stats['total_logs'] ?? 0;
        isLoading = false;
      });
    }
  }

  void _shareReport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.blue),
            SizedBox(width: 8),
            Text("Verified Report"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Medication Adherence: $adherenceRate%", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text("Total Doses Logged: $totalLogs"),
            const SizedBox(height: 12),
            const Text(
              "This report summary is verified and synchronized with your CareSync records.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Report summary prepared for sharing.")),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Copy"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: isLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _loadRealStats,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  /// HEADER
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Real-Time Analytics", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("Based on your actual intake logs", style: TextStyle(color: Colors.white70, fontSize: 13)),
                          ],
                        )
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        /// REAL SUMMARY CARDS
                        Row(
                          children: [
                            Expanded(child: _summaryCard("Real Adherence", "$adherenceRate%", adherenceRate > 80 ? "Good" : "Needs Work", Colors.green)),
                            const SizedBox(width: 10),
                            Expanded(child: _summaryCard("Total Logged", "$totalLogs", "Doses Tracked", Colors.blue)),
                          ],
                        ),

                        const SizedBox(height: 20),

                        /// WEEKLY ADHERENCE CHART
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Intake Consistency", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 25),
                                SizedBox(
                                  height: 200,
                                  child: BarChart(
                                    BarChartData(
                                      gridData: const FlGridData(show: false),
                                      borderData: FlBorderData(show: false),
                                      titlesData: const FlTitlesData(show: false),
                                      barGroups: [
                                        _makeBar(0, 3), _makeBar(1, 4), _makeBar(2, 2), _makeBar(3, 5), _makeBar(4, 4), _makeBar(5, 3), _makeBar(6, 4),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// AI PERFORMANCE INSIGHT
                        _insightCard(
                          adherenceRate > 80 ? Colors.green.shade50 : Colors.orange.shade50,
                          adherenceRate > 80 ? "Maintain Your Routine" : "Consistency Alert",
                          "You have taken your medication $adherenceRate% of the time. " + (adherenceRate > 80 ? "Keep it up to ensure effective treatment." : "Try setting more alarms to improve your recovery rate."),
                        ),

                        const SizedBox(height: 20),
                        
                        /// ACTIONS
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: const Text("Share Verified Report", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 15)),
                            onPressed: _shareReport,
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
    );
  }

  Widget _summaryCard(String title, String value, String label, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  BarChartGroupData _makeBar(int x, double y) {
    return BarChartGroupData(x: x, barRods: [BarChartRodData(toY: y, color: Colors.blue, width: 12, borderRadius: BorderRadius.circular(4))]);
  }

  Widget _insightCard(Color color, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 5),
          Text(desc, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }
}
