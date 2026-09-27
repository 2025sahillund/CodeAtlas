import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../models/medicine.dart';
import '../services/api_service.dart';
import '../services/medicine_service.dart';
import 'appointments_screen.dart';
import 'family_members_screen.dart';
import 'health_tracking_screen.dart';
import 'medicine_list_screen.dart';
import '../widgets/empty_state_widget.dart';

class AlertsScreen extends StatefulWidget {
  final String? targetUid;
  const AlertsScreen({super.key, this.targetUid});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<Map<String, dynamic>> todaySchedule = [];
  List<Medicine> inventory = [];
  List<Map<String, dynamic>> sugarHistory = [];
  Map<String, dynamic> stats = {"adherence_rate": 0, "total_logs": 0};
  bool isLoadingSchedule = true;

  String _selectedFilter = 'all'; // all, unread, medication, appointment, caregiver

  @override
  void initState() {
    super.initState();
    _loadScheduleData();
  }

  Future<void> _loadScheduleData() async {
    if (!mounted) return;
    setState(() => isLoadingSchedule = true);

    try {
      final schedule = await MedicineService.getTodaySchedule(targetUid: widget.targetUid);
      final meds = await MedicineService.getInventory(targetUid: widget.targetUid);
      final sugar = await ApiService.getSugarHistory(targetUid: widget.targetUid);
      final realStats = await MedicineService.getRealStats(targetUid: widget.targetUid);

      if (mounted) {
        setState(() {
          todaySchedule = schedule;
          inventory = meds;
          sugarHistory = sugar;
          stats = realStats;
          isLoadingSchedule = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading alerts data: $e");
      if (mounted) setState(() => isLoadingSchedule = false);
    }
  }

  bool _isDoseMissed(String timeStr) {
    try {
      final now = DateTime.now();
      final parts = timeStr.split(':');
      final reminderTime = DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      return reminderTime.isBefore(now);
    } catch (e) {
      return false;
    }
  }

  bool _hasLoggedSugarToday() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    return sugarHistory.any((log) => log['log_date'] == today || log['date'] == today);
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return "Just now";
    } else if (difference.inMinutes < 60) {
      return "${difference.inMinutes}m ago";
    } else if (difference.inHours < 24 && dt.day == now.day) {
      return "Today, ${DateFormat('hh:mm a').format(dt)}";
    } else if (difference.inDays < 2) {
      return "Yesterday, ${DateFormat('hh:mm a').format(dt)}";
    } else {
      return DateFormat('MMM dd, hh:mm a').format(dt);
    }
  }

  void _handleNotificationTap(AppNotification notif) async {
    final effectiveUid = widget.targetUid ?? ApiService.currentUid;
    if (!notif.isRead && effectiveUid != null) {
      await ApiService.markNotificationAsRead(notif.id, targetUid: effectiveUid);
    }

    if (!mounted) return;

    if (notif.type == 'appointment') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AppointmentsScreen(targetUid: widget.targetUid)),
      );
    } else if (notif.type == 'caregiver' || notif.type == 'family') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
      );
    } else if (notif.type == 'vitals' || notif.type == 'sugar' || notif.type == 'bp') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => HealthTrackingScreen(targetUid: widget.targetUid)),
      );
    } else if (notif.type == 'medication') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MedicineListScreen(targetUid: widget.targetUid)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUid = widget.targetUid ?? ApiService.currentUid ?? '';

    final upcoming = todaySchedule.where((m) {
      bool isTaken = m['is_taken'] ?? false;
      return !isTaken && !_isDoseMissed(m['reminder_time']);
    }).toList();

    final missed = todaySchedule.where((m) {
      bool isTaken = m['is_taken'] ?? false;
      return !isTaken && _isDoseMissed(m['reminder_time']);
    }).toList();

    final lowStockMeds = inventory.where((m) => m.totalStock <= m.stockThreshold).toList();
    final bool needsSugarLog = !_hasLoggedSugarToday();
    final adherenceRate = stats['adherence_rate'] ?? 0;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: Column(
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 50, 16, 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const CircleAvatar(
                          backgroundColor: Colors.white24,
                          child: Icon(Icons.arrow_back, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Text(
                          "Alerts & Notifications",
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (effectiveUid.isNotEmpty)
                        StreamBuilder<int>(
                          stream: ApiService.unreadNotificationsCountStream(effectiveUid),
                          builder: (context, snapshot) {
                            final count = snapshot.data ?? 0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "$count unread",
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Real-time health updates, routine alerts & reminder feed",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  const TabBar(
                    indicatorColor: Colors.white,
                    indicatorWeight: 3,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    tabs: [
                      Tab(text: "Inbox Feed"),
                      Tab(text: "Dose Routine"),
                      Tab(text: "Health Alerts"),
                    ],
                  ),
                ],
              ),
            ),

            /// TAB VIEWS
            Expanded(
              child: TabBarView(
                children: [
                  /// ================= 1. INBOX FEED =================
                  _buildNotificationsInboxTab(effectiveUid),

                  /// ================= 2. DOSE ROUTINE =================
                  _buildDoseRoutineTab(upcoming, missed, needsSugarLog),

                  /// ================= 3. HEALTH ALERTS =================
                  _buildHealthAlertsTab(lowStockMeds, adherenceRate),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationsInboxTab(String effectiveUid) {
    if (effectiveUid.isEmpty) {
      return const Center(child: Text("Please login to view notifications"));
    }

    return StreamBuilder<List<AppNotification>>(
      stream: ApiService.notificationsStream(effectiveUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allNotifications = snapshot.data ?? [];

        // Filter list
        final filtered = allNotifications.where((n) {
          if (_selectedFilter == 'unread') return !n.isRead;
          if (_selectedFilter == 'medication') return n.type == 'medication';
          if (_selectedFilter == 'appointment') return n.type == 'appointment';
          if (_selectedFilter == 'caregiver') return n.type == 'caregiver' || n.type == 'family';
          return true;
        }).toList();

        final int unreadTotal = allNotifications.where((n) => !n.isRead).length;

        return Column(
          children: [
            // Filter Bar & Mark All Read
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('all', 'All'),
                          const SizedBox(width: 6),
                          _filterChip('unread', 'Unread ($unreadTotal)'),
                          const SizedBox(width: 6),
                          _filterChip('medication', 'Meds'),
                          const SizedBox(width: 6),
                          _filterChip('appointment', 'Visits'),
                          const SizedBox(width: 6),
                          _filterChip('caregiver', 'Caregiver'),
                        ],
                      ),
                    ),
                  ),
                  if (unreadTotal > 0)
                    TextButton(
                      onPressed: () => ApiService.markAllNotificationsAsRead(targetUid: effectiveUid),
                      child: const Text("Mark All Read", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Notifications List
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState(
                      Icons.notifications_none,
                      _selectedFilter == 'unread' ? "All caught up!" : "No notifications yet",
                      "Important routine updates and caregiver alerts will appear here.",
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final notif = filtered[index];
                        return _buildNotificationCard(notif, effectiveUid);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _filterChip(String key, String label) {
    final bool isSelected = _selectedFilter == key;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildNotificationCard(AppNotification notif, String effectiveUid) {
    Color iconColor;
    Color bgColor;
    IconData icon;

    switch (notif.type) {
      case 'emergency':
      case 'sos':
        icon = Icons.warning_amber_rounded;
        iconColor = Colors.red.shade700;
        bgColor = Colors.red.shade50;
        break;
      case 'appointment':
        icon = Icons.event_available;
        iconColor = const Color(0xFF2563EB);
        bgColor = Colors.blue.shade50;
        break;
      case 'medication':
        icon = Icons.medication;
        iconColor = const Color(0xFF16A34A);
        bgColor = Colors.green.shade50;
        break;
      case 'caregiver':
      case 'family':
        icon = Icons.people_alt_outlined;
        iconColor = Colors.orange.shade800;
        bgColor = Colors.orange.shade50;
        break;
      case 'vitals':
      case 'sugar':
      case 'bp':
        icon = Icons.favorite_border;
        iconColor = Colors.purple.shade700;
        bgColor = Colors.purple.shade50;
        break;
      default:
        icon = Icons.notifications_outlined;
        iconColor = Colors.blueGrey;
        bgColor = Colors.grey.shade100;
    }

    return Dismissible(
      key: Key(notif.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        ApiService.deleteNotification(notif.id, targetUid: effectiveUid);
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: notif.isRead ? 0 : 1.5,
        color: notif.isRead ? Colors.white : Colors.blue.shade50.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: notif.isRead ? Colors.grey.shade200 : const Color(0xFF2563EB).withValues(alpha: 0.3),
          ),
        ),
        child: ListTile(
          onTap: () => _handleNotificationTap(notif),
          leading: CircleAvatar(
            backgroundColor: bgColor,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  notif.title,
                  style: TextStyle(
                    fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              if (!notif.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF2563EB),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                notif.body,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(notif.createdAt),
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            onPressed: () => ApiService.deleteNotification(notif.id, targetUid: effectiveUid),
            tooltip: "Delete notification",
          ),
        ),
      ),
    );
  }

  Widget _buildDoseRoutineTab(
    List<Map<String, dynamic>> upcoming,
    List<Map<String, dynamic>> missed,
    bool needsSugarLog,
  ) {
    if (isLoadingSchedule) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadScheduleData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Remaining Doses
          const Text("Today's Medication Routine", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          if (upcoming.isEmpty && missed.isEmpty)
            _buildEmptyState(Icons.done_all, "All Doses Taken", "You're all caught up with your medicines today!")
          else ...[
            if (upcoming.isNotEmpty) ...[
              ...upcoming.map((med) => _buildMedicineCard(med, isMissed: false)),
            ],
            if (missed.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text("Missed Doses", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red)),
              const SizedBox(height: 8),
              ...missed.map((med) => _buildMedicineCard(med, isMissed: true)),
            ],
          ],

          if (needsSugarLog) ...[
            const SizedBox(height: 20),
            const Text("Daily Health Tasks", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Card(
              color: Colors.green.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.green, child: Text("🩸")),
                title: const Text("Log Blood Glucose", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text("You haven't logged your sugar level today."),
                trailing: const Icon(Icons.chevron_right, color: Colors.green),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HealthTrackingScreen(targetUid: widget.targetUid)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHealthAlertsTab(List<Medicine> lowStockMeds, int adherenceRate) {
    if (isLoadingSchedule) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadScheduleData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Inventory Stock Warnings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          if (lowStockMeds.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle, color: Colors.green),
                title: Text("All stocks are sufficient", style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("No medicine refills needed right now."),
              ),
            )
          else
            ...lowStockMeds.map((med) => Card(
                  color: Colors.orange.shade50,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
                    title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Only ${med.totalStock} units left (Threshold: ${med.stockThreshold})"),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(60, 32),
                      ),
                      onPressed: () async {
                        await MedicineService.refillStock(
                          medicineName: med.name,
                          currentStock: med.totalStock,
                          amount: 10,
                          targetUid: widget.targetUid,
                        );
                        _loadScheduleData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Refilled +10 units for ${med.name}")),
                          );
                        }
                      },
                      child: const Text("REFILL +10", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                )),
          const SizedBox(height: 20),
          const Text("Medication Adherence Tracker", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          Card(
            color: adherenceRate >= 80 ? Colors.blue.shade50 : Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Icon(
                Icons.insights,
                color: adherenceRate >= 80 ? const Color(0xFF2563EB) : Colors.red,
                size: 28,
              ),
              title: Text("Consistency Score: $adherenceRate%", style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                adherenceRate >= 80
                    ? "Great routine consistency! Keep following doctor instructions."
                    : "Low adherence detected. Missing doses can impact your health recovery.",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return EmptyStateWidget(
      icon: icon,
      title: title,
      subtitle: subtitle,
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> med, {required bool isMissed}) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isMissed ? Colors.red.shade200 : Colors.blue.shade200),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isMissed ? Colors.red.shade50 : Colors.blue.shade50,
          child: Icon(Icons.medication, color: isMissed ? Colors.red : const Color(0xFF2563EB)),
        ),
        title: Text(med["medicine_name"] ?? "Medicine", style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${isMissed ? 'Scheduled' : 'Due'} at: ${med["reminder_time"]}"),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isMissed ? Colors.red.shade700 : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(70, 32),
          ),
          onPressed: () async {
            await MedicineService.takeDose(med['reminder_id'], targetUid: widget.targetUid);
            _loadScheduleData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Dose logged for ${med['medicine_name']}")),
              );
            }
          },
          child: Text(isMissed ? "TAKE NOW" : "TAKE", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
