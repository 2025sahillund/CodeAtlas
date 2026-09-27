import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/health_service.dart';

class SleepScreen extends StatefulWidget {
  @override
  _SleepScreenState createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  double lastNightSleep = 0.0;
  double goalSleep = 8.0;
  double sleepQuality = 0;
  double deepSleep = 0;
  double lightSleep = 0;
  double remSleep = 0;
  String bedTime = "--:--";
  String wakeTime = "--:--";
  
  bool isLoading = true;
  bool permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _fetchSleepData();
  }

  Future<void> _fetchSleepData() async {
    setState(() {
      isLoading = true;
      permissionDenied = false;
    });

    bool hasPermissions = await HealthService.requestPermissions();
    if (!hasPermissions) {
      setState(() {
        isLoading = false;
        permissionDenied = true;
      });
      return;
    }

    final sleepData = await HealthService.getSleepData();
    if (sleepData.isNotEmpty) {
      setState(() {
        lastNightSleep = sleepData['totalHours'] ?? 0.0;
        deepSleep = sleepData['deepSleep'] ?? 0.0;
        lightSleep = sleepData['lightSleep'] ?? 0.0;
        remSleep = sleepData['remSleep'] ?? 0.0;
        
        if (sleepData['bedTime'] != null) {
          final bt = sleepData['bedTime'] as DateTime;
          bedTime = "${bt.hour.toString().padLeft(2, '0')}:${bt.minute.toString().padLeft(2, '0')}";
        }
        if (sleepData['wakeTime'] != null) {
          final wt = sleepData['wakeTime'] as DateTime;
          wakeTime = "${wt.hour.toString().padLeft(2, '0')}:${wt.minute.toString().padLeft(2, '0')}";
        }
        
        sleepQuality = lastNightSleep >= goalSleep ? 95 : (lastNightSleep / goalSleep) * 100;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progress = lastNightSleep / goalSleep;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchSleepData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              /// HEADER
              Container(
                padding: EdgeInsets.fromLTRB(20, 50, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo, Colors.purple],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: CircleAvatar(
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.arrow_back, color: Colors.white),
                      ),
                    ),
                    SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Sleep Tracker",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "Monitor your sleep patterns",
                          style: TextStyle(color: Colors.white70),
                        )
                      ],
                    )
                  ],
                ),
              ),

              if (isLoading)
                Padding(
                  padding: EdgeInsets.all(50.0),
                  child: CircularProgressIndicator(),
                )
              else if (permissionDenied)
                Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.lock_outline, size: 60, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("Health data access denied."),
                      ElevatedButton(
                        onPressed: _fetchSleepData,
                        child: Text("Grant Access"),
                      )
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      /// LAST NIGHT SLEEP CARD
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              /// Circular Progress
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 150,
                                    height: 150,
                                    child: CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 10,
                                      backgroundColor: Colors.grey.shade300,
                                      color: Colors.purple,
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Icon(Icons.nightlight_round,
                                          color: Colors.indigo, size: 30),
                                      SizedBox(height: 5),
                                      Text("${lastNightSleep.toStringAsFixed(1)}h",
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold)),
                                      Text("last night",
                                          style: TextStyle(color: Colors.grey))
                                    ],
                                  )
                                ],
                              ),

                              SizedBox(height: 20),

                              if (lastNightSleep > 0)
                                Chip(
                                  label: Text(
                                      "Sleep Quality (${sleepQuality.toInt()}%)"),
                                  backgroundColor: Colors.green.shade100,
                                )
                              else
                                Chip(
                                  label: Text("No data for last night"),
                                  backgroundColor: Colors.orange.shade100,
                                ),

                              SizedBox(height: 15),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.nightlight, color: Colors.indigo),
                                      SizedBox(width: 5),
                                      Text("Bedtime: $bedTime")
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.wb_sunny, color: Colors.orange),
                                      SizedBox(width: 5),
                                      Text("Wake: $wakeTime")
                                    ],
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// SLEEP PHASES
                      sleepPhase("Deep Sleep", deepSleep, deepSleep / (lastNightSleep > 0 ? lastNightSleep : 1), Colors.indigo),
                      sleepPhase("Light Sleep", lightSleep, lightSleep / (lastNightSleep > 0 ? lastNightSleep : 1), Colors.blue),
                      sleepPhase("REM Sleep", remSleep, remSleep / (lastNightSleep > 0 ? lastNightSleep : 1), Colors.purple),

                      SizedBox(height: 20),

                      /// WEEKLY CHART (Mocked as real historical sleep requires more processing, keeping simplified for now)
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Weekly Sleep Trend",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 20),
                              SizedBox(
                                height: 200,
                                child: LineChart(
                                  LineChartData(
                                    gridData: FlGridData(show: true),
                                    titlesData: FlTitlesData(show: true),
                                    borderData: FlBorderData(show: false),
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: [
                                          FlSpot(0, 7.2),
                                          FlSpot(1, 8.1),
                                          FlSpot(2, 6.5),
                                          FlSpot(3, 7.8),
                                          FlSpot(4, 7.0),
                                          FlSpot(5, 8.5),
                                          FlSpot(6, lastNightSleep),
                                        ],
                                        isCurved: true,
                                        color: Colors.purple,
                                        barWidth: 3,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// RECOMMENDATIONS
                      Card(
                        color: Colors.purple.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Sleep Recommendations",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              Text("• Maintain consistent sleep schedule"),
                              Text("• Avoid screens before bed"),
                              Text("• Keep bedroom cool (18–22°C)"),
                              Text("• Try meditation before sleep"),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// HEALTH IMPACT
                      healthImpactCard(
                          "Blood Sugar Regulation", lastNightSleep > 7 ? "Good" : "At Risk", lastNightSleep > 7 ? Colors.green : Colors.orange),
                      SizedBox(height: 10),
                      healthImpactCard(
                          "Recovery & Healing", lastNightSleep > 6 ? "Optimal" : "Slow", lastNightSleep > 6 ? Colors.blue : Colors.red),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  /// Sleep Phase Widget
  Widget sleepPhase(
      String title, double hours, double percentage, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title),
                Text("${hours.toStringAsFixed(1)}h (${(percentage * 100).toInt()}%)")
              ],
            ),
            SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              color: color,
            )
          ],
        ),
      ),
    );
  }

  /// Health Impact Widget
  Widget healthImpactCard(String title, String status, Color color) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            Chip(
              label: Text(status),
              backgroundColor: color.withOpacity(0.2),
            )
          ],
        ),
      ),
    );
  }
}
