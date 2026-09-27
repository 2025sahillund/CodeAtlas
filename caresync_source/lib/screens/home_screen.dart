import 'package:flutter/material.dart';
import 'chatbot_screen.dart';
import 'medicine_list_screen.dart';
import 'alerts_screen.dart';
import 'sos_screen.dart';
import 'profile_screen.dart';
import 'add_medicine_screen.dart';
import 'family_members_screen.dart';
import 'activity_tracking_screen.dart';
import 'scan_prescription_screen.dart';
import 'reports_screen.dart';
import 'health_tracking_screen.dart';
import 'appointments_screen.dart';
import 'health_explorer/health_explorer_screen.dart';
import '../services/medicine_service.dart';
import '../services/notification_service.dart';
import '../services/api_service.dart';
import '../services/health_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIndex = 0;
  DateTime selectedDate = DateTime.now();
  String userName = "User";
  List<Map<String, dynamic>> todaySchedule = [];
  String latestBP = "---";
  int? todaySteps;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool skipRefillAlert = false}) async {
    if (!mounted) return;
    setState(() => isLoading = true);
    
    try {
      await ApiService.syncUser();
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
    
    await _loadUser();
    
    // Fetch real data in parallel - Sugar and Sleep removed from dashboard summary
    final results = await Future.wait([
      MedicineService.getTodaySchedule(),
      ApiService.getBPHistory(),
      HealthService.getSteps(),
    ]);
    
    final schedule = results[0] as List<Map<String, dynamic>>;
    final bpHistory = results[1] as List<Map<String, dynamic>>;
    final steps = results[2] as int?;
    
    if (mounted) {
      setState(() {
        todaySchedule = schedule;
        if (bpHistory.isNotEmpty) {
          final first = bpHistory.first;
          latestBP = "${first['systolic']}/${first['diastolic']}";
        }
        todaySteps = steps;
        isLoading = false;
      });
    }

    _scheduleNotifications(schedule);
    if (!skipRefillAlert) {
      _checkRefills();
    }
  }

  void _checkRefills() async {
    final inventory = await MedicineService.getInventory();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    for (var med in inventory) {
      if (med.totalStock <= med.stockThreshold) {
        NotificationService.showImmediateNotification(
          title: "Low Stock Alert: ${med.name}",
          body: "Only ${med.totalStock} units remaining (Threshold: ${med.stockThreshold}). Tap to refill.",
          type: "medication",
          customId: NotificationService.calculateNotificationId('low_stock_${med.name}'),
        );
        if (currentUid != null) {
          ApiService.sendInAppNotification(
            targetUid: currentUid,
            title: "Low Stock Alert: ${med.name}",
            body: "Only ${med.totalStock} units remaining (Threshold: ${med.stockThreshold}). Tap to refill.",
            type: "medication",
            referenceId: "stock_${med.name}",
          );
        }
      }
    }
  }

  Future<void> _scheduleNotifications(List<Map<String, dynamic>> schedule) async {
    for (var med in schedule) {
      if (!(med['is_taken'] ?? false)) {
        await NotificationService.scheduleMedicineReminder(
          id: med['reminder_id'],
          title: "CareSync Dose Reminder",
          body: "Time for ${med['medicine_name']}.",
          time: med['reminder_time'],
        );
      }
    }
  }

  Future<void> _loadUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          if (mounted) {
            setState(() => userName = doc['fullName'] ?? doc['name'] ?? "User");
          }
        }
      }
    } catch (e) {
      debugPrint("User load error: $e");
    }
  }

  Future<void> _markAsTaken(dynamic reminderId, {String? medName, String? reminderTime}) async {
    bool success = await MedicineService.takeDose(reminderId, medicineName: medName);
    if (success) {
      await _loadData(skipRefillAlert: true);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    medName != null && medName.isNotEmpty
                        ? "$medName marked as taken"
                        : "Medicine marked as taken",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF15803D),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 8,
            action: SnackBarAction(
              label: "UNDO",
              textColor: const Color(0xFFFDE047),
              onPressed: () => _undoTakenDose(reminderId, medName: medName, reminderTime: reminderTime),
            ),
          ),
        );
      }
    }
  }

  Future<void> _undoTakenDose(dynamic reminderId, {String? medName, String? reminderTime}) async {
    bool success = await MedicineService.undoDose(
      reminderId,
      medicineName: medName,
      reminderTime: reminderTime,
    );
    if (success) {
      await _loadData(skipRefillAlert: true);
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.undo_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Dose undone for ${medName ?? 'medicine'}. Stock restored (+1).",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1D4ED8),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 8,
          ),
        );
      }
    }
  }

  void _showUndoConfirmationDialog(dynamic reminderId, String medicineName, String reminderTime) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.undo_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text("Undo Dose?", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "Mark $medicineName ($reminderTime) as not taken for today? This will restore 1 unit back to stock.",
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Keep Taken"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _undoTakenDose(reminderId, medName: medicineName, reminderTime: reminderTime);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Undo Dose"),
          ),
        ],
      ),
    );
  }

  String _weekdayInitial(int weekday) {
    switch (weekday) {
      case 1: return "M";
      case 2: return "T";
      case 3: return "W";
      case 4: return "T";
      case 5: return "F";
      case 6: return "S";
      case 7: return "S";
      default: return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
        backgroundColor: Colors.purple,
        child: const Icon(Icons.chat, color: Colors.white),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (mounted) setState(() => selectedIndex = index);
          if (index == 1) Navigator.push(context, MaterialPageRoute(builder: (_) => const MedicineListScreen())).then((_) => _loadData());
          if (index == 2) Navigator.push(context, MaterialPageRoute(builder: (_) => AlertsScreen()));
          if (index == 3) Navigator.push(context, MaterialPageRoute(builder: (_) => SOSScreen()));
          if (index == 4) Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthExplorerScreen()));
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.medication), label: "Meds"),
          BottomNavigationBarItem(icon: Icon(Icons.notifications), label: "Alerts"),
          BottomNavigationBarItem(icon: Icon(Icons.warning), label: "SOS"),
          BottomNavigationBarItem(icon: Icon(Icons.accessibility_new_rounded), label: "Explorer"),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              /// Header with Calendar
              Container(
                padding: const EdgeInsets.fromLTRB(20, 50, 20, 30),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.blue, Colors.green]),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Hello, $userName ", style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                              const Text("Your health at a glance.", style: TextStyle(color: Colors.white70)),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            StreamBuilder<int>(
                              stream: FirebaseAuth.instance.currentUser?.uid != null
                                  ? ApiService.unreadNotificationsCountStream(FirebaseAuth.instance.currentUser!.uid)
                                  : Stream.value(0),
                              builder: (context, snapshot) {
                                final unreadCount = snapshot.data ?? 0;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsScreen())),
                                      child: const CircleAvatar(
                                        backgroundColor: Colors.white24,
                                        child: Icon(Icons.notifications_outlined, color: Colors.white),
                                      ),
                                    ),
                                    if (unreadCount > 0)
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                          child: Text(
                                            unreadCount > 9 ? '9+' : '$unreadCount',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
                              child: const CircleAvatar(backgroundColor: Colors.white24, child: Icon(Icons.person, color: Colors.white)),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        DateTime day = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1 - index));
                        bool isToday = day.day == DateTime.now().day;
                        return Column(
                          children: [
                            Text("${day.day}", style: TextStyle(color: isToday ? Colors.white : Colors.white70, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? Colors.white : Colors.transparent),
                              child: Text(_weekdayInitial(day.weekday), style: TextStyle(color: isToday ? Colors.blue : Colors.white)),
                            )
                          ],
                        );
                      }),
                    )
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // INCOMING CAREGIVER REQUESTS BANNER
                    _buildIncomingRequestsBanner(),

                    // TOP ROW HEALTH SUMMARY
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ActivityTrackingScreen())).then((_) => _loadData()),
                            child: _dashboardTile(Icons.directions_walk, "Steps Today", todaySteps != null ? todaySteps.toString() : "---", Colors.blue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HealthTrackingScreen())).then((_) => _loadData()),
                            child: _dashboardTile(Icons.favorite, "Blood Pressure", latestBP, Colors.orange),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 15),

                    /// Today's Schedule Card
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text("Today's Schedule", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddMedicineScreen())).then((_) => _loadData()), child: const Text("Add New")),
                              ],
                            ),
                            if (isLoading) const Center(child: CircularProgressIndicator())
                            else if (todaySchedule.isEmpty) const Text("No doses scheduled for today.")
                            else Column(
                              children: todaySchedule.map((med) {
                                bool isTaken = med['is_taken'] ?? false;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.medication, color: isTaken ? Colors.green : Colors.orange),
                                  title: Text(med['medicine_name'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isTaken ? TextDecoration.lineThrough : null)),
                                  subtitle: Text("Due: ${med['reminder_time']} • Notify: ${med['notification_time']}"),
                                  trailing: isTaken 
                                    ? InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () => _showUndoConfirmationDialog(
                                          med['reminder_id'],
                                          med['medicine_name'] ?? 'Medicine',
                                          med['reminder_time'] ?? '08:00',
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 24),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Taken",
                                                style: TextStyle(
                                                  color: Colors.green.shade800,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : ElevatedButton(
                                        onPressed: () => _markAsTaken(
                                          med['reminder_id'],
                                          medName: med['medicine_name'],
                                          reminderTime: med['reminder_time'],
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: const Text("Take"),
                                      ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    /// Quick Actions Grid
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _quickAction(Icons.qr_code_scanner, "Scan Rx", () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScanPrescriptionScreen()))),
                        _quickAction(Icons.event_note, "Appointments", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen()))),
                        _quickAction(Icons.description, "Reports", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()))),
                        _quickAction(Icons.family_restroom, "Family & Care", () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FamilyMembersScreen())).then((_) => _loadData())),
                      ],
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

  Widget _buildIncomingRequestsBanner() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ApiService.incomingRequestsStream(uid),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? [];
        if (requests.isEmpty) return const SizedBox.shrink();

        final req = requests.first;
        final reqId = req['id'] as String? ?? '';
        final caregiverName = req['caregiverName'] ?? req['caregiverEmail'] ?? 'A CareSync User';
        final relation = req['relationship'] ?? 'Caregiver';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.shade300, width: 1.5),
          ),
          color: Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade200,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.mark_email_unread, color: Colors.deepOrange, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Caregiver Connection Request",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (requests.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade200,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "+${requests.length - 1} more",
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "$caregiverName ($relation) wants to connect as your caregiver to view your health logs and medicines.",
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                        side: BorderSide(color: Colors.red.shade300),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await ApiService.respondToConnectionRequest(
                          connectionId: reqId,
                          accept: false,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Request declined."), behavior: SnackBarBehavior.floating),
                          );
                        }
                      },
                      child: const Text("Decline"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await ApiService.respondToConnectionRequest(
                          connectionId: reqId,
                          accept: true,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Connected with caregiver $caregiverName!"),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      child: const Text("Accept"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _dashboardTile(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(16), 
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _quickAction(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.blue, size: 30),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

