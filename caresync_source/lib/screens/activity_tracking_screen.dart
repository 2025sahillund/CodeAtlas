import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/health_service.dart';

class ActivityTrackingScreen extends StatefulWidget {
  @override
  State<ActivityTrackingScreen> createState() => _ActivityTrackingScreenState();
}

class _ActivityTrackingScreenState extends State<ActivityTrackingScreen> {
  int? todaySteps;
  int goalSteps = 10000;
  int? calories;
  double? distance;
  int minutes = 0; 
  List<double> weeklySteps = [0, 0, 0, 0, 0, 0, 0];
  bool isLoading = true;
  bool permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
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

    try {
      final steps = await HealthService.getSteps();
      final dist = await HealthService.getDistance();
      final cals = await HealthService.getCalories();
      final weekly = await HealthService.getWeeklySteps();

      setState(() {
        todaySteps = steps;
        distance = dist;
        calories = cals;
        weeklySteps = weekly;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching activity data: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Treat null as 0 for the UI progress bar, but distinct for text
    double progress = (todaySteps ?? 0) / goalSteps;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              /// HEADER
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16, 50, 16, 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink.shade100, Colors.teal],
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
                    Text("Activity Tracker",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold)),
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
                      const SizedBox(height: 15),
                      ElevatedButton(
                        onPressed: _fetchData,
                        child: Text("Grant Access"),
                      ),
                      TextButton(
                        onPressed: () {
                          // Health Connect is managed in Android Settings
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please enable permissions in Health Connect app settings."))
                          );
                        },
                        child: const Text("How to fix?"),
                      )
                    ],
                  ),
                )
              else
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      /// TODAY PROGRESS CARD
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 140,
                                width: 140,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    CircularProgressIndicator(
                                      value: progress,
                                      strokeWidth: 10,
                                      backgroundColor: Colors.grey.shade300,
                                      color: Colors.teal,
                                    ),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.directions_walk,
                                            color: Colors.tealAccent),
                                        Text(
                                          todaySteps?.toString() ?? "---",
                                          style: TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold),
                                        ),
                                        Text("steps",
                                            style: TextStyle(fontSize: 12))
                                      ],
                                    )
                                  ],
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                todaySteps == null 
                                  ? "Data unavailable"
                                  : (goalSteps - (todaySteps ?? 0) > 0
                                    ? "${goalSteps - (todaySteps ?? 0)} steps to go"
                                    : "Goal achieved 🎉"),
                              ),
                              SizedBox(height: 20),

                              /// STATS GRID
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  statBox("🔥", calories?.toString() ?? "---", "Calories",
                                      Colors.orange),
                                  statBox("🎯", distance != null ? "${distance!.toStringAsFixed(2)} km" : "---",
                                      "Distance", Colors.blue),
                                  statBox("⏱", minutes.toString(), "Minutes",
                                      Colors.purple),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// WEEKLY CHART
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Weekly Activity",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 15),
                              SizedBox(
                                height: 200,
                                child: BarChart(
                                  BarChartData(
                                    barGroups: weeklySteps
                                        .asMap()
                                        .entries
                                        .map(
                                          (e) => BarChartGroupData(
                                            x: e.key,
                                            barRods: [
                                              BarChartRodData(
                                                toY: e.value,
                                                color: Colors.pink.shade100,
                                                width: 18,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              )
                                            ],
                                          ),
                                        )
                                        .toList(),
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                                      ),
                                      bottomTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          getTitlesWidget: (value, meta) {
                                            const days = ["M", "T", "W", "T", "F", "S", "S"];
                                            if (value.toInt() < 0 || value.toInt() >= days.length) return Text("");
                                            return Text(days[value.toInt()]);
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// ACHIEVEMENTS
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Achievements",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 15),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  achievement("🎯", "5K Steps", (todaySteps ?? 0) >= 5000),
                                  achievement("🏆", "10K Champion", (todaySteps ?? 0) >= 10000),
                                  achievement("🔥", "Active Day", (todaySteps ?? 0) > 0),
                                  achievement("🌅", "Early Bird", false),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// TIP CARD
                      Card(
                        color: Colors.blue.shade50,
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            "💡 Tip: Take the stairs instead of the elevator to boost your step count!",
                          ),
                        ),
                      ),

                      SizedBox(height: 20),

                      /// HEALTH IMPACT
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Health Impact",
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 10),
                              impactTile("Blood Sugar", (todaySteps ?? 0) > 5000 ? "Good" : "Needs Activity", Colors.green),
                              impactTile("Cardio Health", "Improving", Colors.blue),
                              impactTile("Weight", "On Track", Colors.purple),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget statBox(String icon, String value, String label, Color color) {
    return Column(
      children: [
        Text(icon, style: TextStyle(fontSize: 24)),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12))
      ],
    );
  }

  Widget achievement(String icon, String title, bool unlocked) {
    return Container(
      width: 140,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? Colors.orange.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(icon, style: TextStyle(fontSize: 28)),
          SizedBox(height: 5),
          Text(title, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget impactTile(String title, String status, Color color) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(status, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}
