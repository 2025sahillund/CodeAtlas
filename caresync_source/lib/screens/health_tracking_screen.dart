import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';

class HealthTrackingScreen extends StatefulWidget {
  final String? targetUid;
  final bool isReadOnly;
  const HealthTrackingScreen({super.key, this.targetUid, this.isReadOnly = false});

  @override
  _HealthTrackingScreenState createState() => _HealthTrackingScreenState();
}

class _HealthTrackingScreenState extends State<HealthTrackingScreen> {
  bool showAddForm = false;
  String recordType = "sugar"; // "sugar" or "bp"
  
  final TextEditingController sugarController = TextEditingController();
  final TextEditingController systolicController = TextEditingController();
  final TextEditingController diastolicController = TextEditingController();
  final TextEditingController pulseController = TextEditingController();
  
  List<Map<String, dynamic>> sugarLogs = [];
  List<Map<String, dynamic>> bpLogs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => isLoading = true);
    final sugarHistory = await ApiService.getSugarHistory(targetUid: widget.targetUid);
    final bpHistory = await ApiService.getBPHistory(targetUid: widget.targetUid);
    setState(() {
      sugarLogs = sugarHistory;
      bpLogs = bpHistory;
      isLoading = false;
    });
  }

  Future<void> _addRecord() async {
    final now = DateTime.now();
    final date = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final time = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    bool success = false;
    if (recordType == "sugar") {
      final text = sugarController.text.trim();
      if (text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter blood sugar level")),
        );
        return;
      }
      final sugar = int.tryParse(text);
      if (sugar == null || sugar < 30 || sugar > 700) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Sugar level. Valid clinical range: 30–700 mg/dL")),
        );
        return;
      }
      success = await ApiService.logSugar(sugar, date, time);
    } else {
      final sysText = systolicController.text.trim();
      final diaText = diastolicController.text.trim();
      final pulseText = pulseController.text.trim();

      if (sysText.isEmpty || diaText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter both Systolic and Diastolic BP")),
        );
        return;
      }
      final sys = int.tryParse(sysText);
      final dia = int.tryParse(diaText);
      final pulse = pulseText.isNotEmpty ? (int.tryParse(pulseText) ?? 72) : 72;

      if (sys == null || sys < 60 || sys > 260) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Systolic BP. Valid clinical range: 60–260 mmHg")),
        );
        return;
      }
      if (dia == null || dia < 40 || dia > 150) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Diastolic BP. Valid clinical range: 40–150 mmHg")),
        );
        return;
      }
      if (sys < dia + 15) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Systolic BP must be at least 15 mmHg higher than Diastolic BP")),
        );
        return;
      }
      if (pulseText.isNotEmpty && (pulse < 30 || pulse > 220)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid Pulse. Valid clinical range: 30–220 bpm")),
        );
        return;
      }

      success = await ApiService.logBP(sys, dia, pulse, date, time);
    }

    if (success) {
      sugarController.clear();
      systolicController.clear();
      diastolicController.clear();
      pulseController.clear();
      setState(() => showAddForm = false);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Record saved successfully"), backgroundColor: Colors.green),
        );
      }
    }
  }

  Future<void> _confirmDeleteLog(String logId, String type) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Delete $type Reading?"),
        content: const Text("This reading will be removed from your logs and trend charts."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      bool ok;
      if (type == "Sugar") {
        ok = await ApiService.deleteSugarLog(logId, targetUid: widget.targetUid);
      } else {
        ok = await ApiService.deleteBPLog(logId, targetUid: widget.targetUid);
      }
      if (ok) {
        _loadHistory();
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text("Deleted $type reading")),
        );
      }
    }
  }

  List<String> getChartLabels() {
    final list = recordType == "sugar" ? sugarLogs : bpLogs;
    final entries = list.take(7).toList().reversed.toList();
    return entries.map((e) {
      final dStr = e['log_date'] as String? ?? '';
      try {
        final dt = DateTime.parse(dStr);
        return "${dt.day}/${dt.month}";
      } catch (_) {
        return dStr.length > 5 ? dStr.substring(5) : dStr;
      }
    }).toList();
  }

  List<FlSpot> getSugarSpots() {
    if (sugarLogs.isEmpty) return [const FlSpot(0, 0)];
    List<FlSpot> spots = [];
    var lastEntries = sugarLogs.take(7).toList().reversed.toList();
    for (int i = 0; i < lastEntries.length; i++) {
      double level = (lastEntries[i]['sugar_level'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), level));
    }
    return spots;
  }

  List<FlSpot> getBPSpots() {
    if (bpLogs.isEmpty) return [const FlSpot(0, 0)];
    List<FlSpot> spots = [];
    var lastEntries = bpLogs.take(7).toList().reversed.toList();
    for (int i = 0; i < lastEntries.length; i++) {
      double level = (lastEntries[i]['systolic'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), level));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    String latestSugar = sugarLogs.isNotEmpty ? "${sugarLogs.first['sugar_level']} mg/dL" : "---";
    String latestBP = bpLogs.isNotEmpty ? "${bpLogs.first['systolic']}/${bpLogs.first['diastolic']}" : "---";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Health Tracking"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _quickStatCard("Latest Sugar", latestSugar, Icons.water_drop, Colors.red)),
                  const SizedBox(width: 10),
                  Expanded(child: _quickStatCard("Latest BP", latestBP, Icons.favorite, Colors.orange)),
                ],
              ),
              const SizedBox(height: 20),
              
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text("${recordType == 'sugar' ? 'Sugar' : 'BP (Systolic)'} Trend", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 25),
                      SizedBox(
                        height: 200,
                        child: isLoading 
                          ? const Center(child: CircularProgressIndicator())
                          : LineChart(
                              LineChartData(
                                borderData: FlBorderData(show: false),
                                gridData: const FlGridData(show: true, drawVerticalLine: false),
                                titlesData: FlTitlesData(
                                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 24,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final labels = getChartLabels();
                                        final idx = value.toInt();
                                        if (idx >= 0 && idx < labels.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(
                                              labels[idx],
                                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                                            ),
                                          );
                                        }
                                        return const SizedBox();
                                      },
                                    ),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: recordType == "sugar" ? getSugarSpots() : getBPSpots(),
                                    isCurved: true,
                                    barWidth: 4,
                                    color: Colors.blue,
                                    belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
                                    dotData: const FlDotData(show: true),
                                  )
                                ],
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!widget.isReadOnly) ...[
                const SizedBox(height: 20),
                if (!showAddForm)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
                          onPressed: () => setState(() { recordType = "sugar"; showAddForm = true; }),
                          icon: const Icon(Icons.add),
                          label: const Text("Log Sugar"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(0, 50)),
                          onPressed: () => setState(() { recordType = "bp"; showAddForm = true; }),
                          icon: const Icon(Icons.add),
                          label: const Text("Log BP"),
                        ),
                      ),
                    ],
                  )
                else
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text("New ${recordType == 'sugar' ? 'Sugar' : 'BP'} Log", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          if (recordType == "sugar")
                            TextField(
                              controller: sugarController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Level (mg/dL)",
                                hintText: "e.g. 110 (Range: 30–700)",
                                border: OutlineInputBorder(),
                              ),
                            )
                          else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: systolicController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Systolic (mmHg)",
                                      hintText: "60–260",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: diastolicController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: "Diastolic (mmHg)",
                                      hintText: "40–150",
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: pulseController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Pulse (bpm, Optional)",
                                hintText: "30–220",
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(child: OutlinedButton(onPressed: () => setState(() => showAddForm = false), child: const Text("Cancel"))),
                              const SizedBox(width: 10),
                              Expanded(child: ElevatedButton(onPressed: _addRecord, child: const Text("Save"))),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
              ],

              const SizedBox(height: 20),

              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Log History", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      if (isLoading) 
                        const Center(child: CircularProgressIndicator())
                      else if (sugarLogs.isEmpty && bpLogs.isEmpty)
                        const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: Text("No records yet.")))
                      else ...[
                        ...sugarLogs.map((log) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.water_drop, color: Colors.white, size: 18)),
                          title: Text("${log['sugar_level']} mg/dL (Sugar)"),
                          subtitle: Text("${log['log_date']} • ${log['log_time']}"),
                          trailing: widget.isReadOnly || log['id'] == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: "Delete reading",
                                  onPressed: () => _confirmDeleteLog(log['id'] as String, "Sugar"),
                                ),
                        )),
                        ...bpLogs.map((log) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.favorite, color: Colors.white, size: 18)),
                          title: Text("${log['systolic']}/${log['diastolic']} mmHg (BP)"),
                          subtitle: Text("${log['log_date']} • ${log['log_time']} • Pulse: ${log['pulse']}"),
                          trailing: widget.isReadOnly || log['id'] == null
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                  tooltip: "Delete reading",
                                  onPressed: () => _confirmDeleteLog(log['id'] as String, "Blood Pressure"),
                                ),
                        )),
                      ]
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
