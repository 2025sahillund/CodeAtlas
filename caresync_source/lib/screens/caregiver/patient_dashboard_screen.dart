import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/api_service.dart';
import '../../services/medicine_service.dart';
import '../../models/medicine.dart';
import '../health_tracking_screen.dart';
import '../medicine_list_screen.dart';
import '../reports_screen.dart';
import '../appointments_screen.dart';
import '../alerts_screen.dart';
import '../sos_screen.dart';
import '../health_explorer/health_explorer_screen.dart';
import '../medical_passport_screen.dart';

class PatientDashboardScreen extends StatefulWidget {
  final String patientUid;
  final String patientName;

  const PatientDashboardScreen({
    super.key,
    required this.patientUid,
    required this.patientName,
  });

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  Map<String, dynamic>? _patientProfile;
  List<Map<String, dynamic>> _todaySchedule = [];
  List<Map<String, dynamic>> _bpHistory = [];
  List<Map<String, dynamic>> _sugarHistory = [];
  List<Medicine> _inventory = [];
  Map<String, dynamic> _stats = {"adherence_rate": 0, "total_logs": 0};
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;

  final List<dynamic> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _loadPatientData();
    _initRealTimeStreams();
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      try {
        sub.cancel();
      } catch (_) {}
    }
    super.dispose();
  }

  void _initRealTimeStreams() {
    // 1. Live Sugar stream
    final sugarSub = ApiService.sugarHistoryStream(widget.patientUid).listen((logs) {
      if (mounted) {
        setState(() {
          _sugarHistory = logs;
        });
      }
    });
    _subscriptions.add(sugarSub);

    // 2. Live BP stream
    final bpSub = ApiService.bpHistoryStream(widget.patientUid).listen((logs) {
      if (mounted) {
        setState(() {
          _bpHistory = logs;
        });
      }
    });
    _subscriptions.add(bpSub);

    // 3. Live Dose Logs & Schedule stream
    final doseSub = ApiService.todayDoseLogsStream(widget.patientUid).listen((_) async {
      final schedule = await MedicineService.getTodaySchedule(targetUid: widget.patientUid);
      final stats = await MedicineService.getRealStats(targetUid: widget.patientUid);
      if (mounted) {
        setState(() {
          _todaySchedule = schedule;
          _stats = stats;
        });
      }
    });
    _subscriptions.add(doseSub);

    // 4. Live Medicines & Inventory stream
    final medSub = ApiService.medicinesStream(widget.patientUid).listen((medsData) {
      if (mounted) {
        setState(() {
          _inventory = medsData.map((m) => Medicine.fromJson(m)).toList();
        });
      }
    });
    _subscriptions.add(medSub);
  }

  Future<void> _loadPatientData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        ApiService.getProfile(targetUid: widget.patientUid),
        ApiService.getBPHistory(targetUid: widget.patientUid),
        ApiService.getSugarHistory(targetUid: widget.patientUid),
        MedicineService.getTodaySchedule(targetUid: widget.patientUid),
        MedicineService.getInventory(targetUid: widget.patientUid),
        MedicineService.getRealStats(targetUid: widget.patientUid),
        ApiService.getAppointments(targetUid: widget.patientUid),
      ]);

      if (mounted) {
        setState(() {
          _patientProfile = results[0] as Map<String, dynamic>?;
          _bpHistory = results[1] as List<Map<String, dynamic>>;
          _sugarHistory = results[2] as List<Map<String, dynamic>>;
          _todaySchedule = results[3] as List<Map<String, dynamic>>;
          _inventory = results[4] as List<Medicine>;
          _stats = results[5] as Map<String, dynamic>;
          _appointments = results[6] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading patient dashboard data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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
    final String displayName = _patientProfile?['name'] ?? _patientProfile?['fullName'] ?? widget.patientName;
    final String latestBP = _bpHistory.isNotEmpty
        ? "${_bpHistory.first['systolic']}/${_bpHistory.first['diastolic']}"
        : "---";
    final String latestSugar = _sugarHistory.isNotEmpty
        ? "${_sugarHistory.first['sugar_level']} mg/dL"
        : "---";
    final int adherenceRate = _stats['adherence_rate'] ?? 0;
    final int totalMeds = _inventory.length;
    final int lowStockCount = _inventory.where((m) => m.totalStock <= m.stockThreshold).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadPatientData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// GRADIENT HEADER
              Container(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                          tooltip: "Back to Caregiver Home",
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock_outline, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                "Read-Only Mode",
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white24,
                          child: Text(
                            displayName.isNotEmpty ? displayName[0].toUpperCase() : 'P',
                            style: GoogleFonts.poppins(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                "Patient Health Dashboard",
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // CareSync ID pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.badge_outlined, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          const Text(
                            "CareSync ID: ",
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                          Expanded(
                            child: Text(
                              widget.patientUid,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: widget.patientUid));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Patient CareSync ID copied!"),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.copy, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Calendar day strip
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        final day = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1 - index));
                        final isToday = day.day == DateTime.now().day;
                        return Column(
                          children: [
                            Text(
                              "${day.day}",
                              style: TextStyle(
                                color: isToday ? Colors.white : Colors.white70,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isToday ? Colors.white : Colors.transparent,
                              ),
                              child: Text(
                                _weekdayInitial(day.weekday),
                                style: TextStyle(
                                  color: isToday ? const Color(0xFF2563EB) : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ],
                ),
              ),

              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(48.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// TOP 4 HEALTH TILES
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.favorite,
                              iconColor: Colors.red,
                              title: "Blood Pressure",
                              value: latestBP,
                              subtitle: _bpHistory.isNotEmpty ? "Latest log" : "No logs yet",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HealthTrackingScreen(
                                    targetUid: widget.patientUid,
                                    isReadOnly: true,
                                  ),
                                ),
                              ).then((_) => _loadPatientData()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.water_drop,
                              iconColor: Colors.orange,
                              title: "Blood Glucose",
                              value: latestSugar,
                              subtitle: _sugarHistory.isNotEmpty ? "Latest log" : "No logs yet",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HealthTrackingScreen(
                                    targetUid: widget.patientUid,
                                    isReadOnly: true,
                                  ),
                                ),
                              ).then((_) => _loadPatientData()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.analytics_outlined,
                              iconColor: Colors.green,
                              title: "Adherence",
                              value: "$adherenceRate%",
                              subtitle: "${_stats['total_logs'] ?? 0} doses tracked",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportsScreen(
                                    targetUid: widget.patientUid,
                                  ),
                                ),
                              ).then((_) => _loadPatientData()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildMetricTile(
                              icon: Icons.medication,
                              iconColor: Colors.blue,
                              title: "Medicines",
                              value: "$totalMeds Meds",
                              subtitle: lowStockCount > 0 ? "$lowStockCount low in stock" : "Inventory OK",
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => MedicineListScreen(
                                    targetUid: widget.patientUid,
                                    isReadOnly: true,
                                  ),
                                ),
                              ).then((_) => _loadPatientData()),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// TODAY'S MEDICATION SCHEDULE (READ-ONLY)
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        elevation: 1,
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.schedule, color: Color(0xFF2563EB), size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Today's Schedule",
                                        style: GoogleFonts.poppins(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    "${_todaySchedule.length} doses",
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (_todaySchedule.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(
                                    child: Text(
                                      "No scheduled doses for today.",
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ),
                                )
                              else
                                Column(
                                  children: _todaySchedule.map((med) {
                                    final bool isTaken = med['is_taken'] ?? false;
                                    final String medName = med['medicine_name'] ?? 'Medicine';
                                    final String time = med['reminder_time'] ?? '00:00';
                                    final String dosage = med['dosage'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isTaken ? Colors.green.shade50 : Colors.grey.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isTaken ? Colors.green.shade200 : Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.medication_liquid_outlined,
                                            color: isTaken ? Colors.green : const Color(0xFF2563EB),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  medName,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                    decoration: isTaken ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                Text(
                                                  "Due: $time${dosage.isNotEmpty ? ' • $dosage' : ''}",
                                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isTaken ? Colors.green : Colors.orange.shade100,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isTaken ? Icons.check : Icons.access_time,
                                                  size: 12,
                                                  color: isTaken ? Colors.white : Colors.orange.shade800,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isTaken ? "Taken" : "Scheduled",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isTaken ? Colors.white : Colors.orange.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// QUICK ACTIONS GRID
                      Text(
                        "Patient Health Records",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.5,
                        children: [
                          _buildActionTile(
                            icon: Icons.show_chart,
                            title: "Health Trends",
                            subtitle: "BP & Sugar logs",
                            color: const Color(0xFF2563EB),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HealthTrackingScreen(
                                  targetUid: widget.patientUid,
                                  isReadOnly: true,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.inventory_2_outlined,
                            title: "Medications",
                            subtitle: "$totalMeds in inventory",
                            color: const Color(0xFF16A34A),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicineListScreen(
                                  targetUid: widget.patientUid,
                                  isReadOnly: true,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.analytics,
                            title: "Adherence Report",
                            subtitle: "$adherenceRate% consistency",
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportsScreen(
                                  targetUid: widget.patientUid,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.event_note,
                            title: "Appointments",
                            subtitle: "${_appointments.length} scheduled",
                            color: Colors.teal,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AppointmentsScreen(
                                  targetUid: widget.patientUid,
                                  isReadOnly: true,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.notifications_active_outlined,
                            title: "Health Alerts",
                            subtitle: "Missed doses & refills",
                            color: Colors.orange,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AlertsScreen(
                                  targetUid: widget.patientUid,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.emergency_outlined,
                            title: "Emergency Info",
                            subtitle: "SOS & profile contacts",
                            color: Colors.red,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SOSScreen(
                                  targetUid: widget.patientUid,
                                  isReadOnly: true,
                                ),
                              ),
                            ).then((_) => _loadPatientData()),
                          ),
                          _buildActionTile(
                            icon: Icons.assignment_ind_outlined,
                            title: "Medical Passport",
                            subtitle: "Summary & PDF export",
                            color: const Color(0xFF1E3A8A),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => MedicalPassportScreen(
                                  targetUid: widget.patientUid,
                                  isReadOnly: true,
                                ),
                              ),
                            ),
                          ),
                          _buildActionTile(
                            icon: Icons.accessibility_new_rounded,
                            title: "Health Explorer",
                            subtitle: "Body & health education",
                            color: Colors.indigo,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HealthExplorerScreen(
                                  targetUid: widget.patientUid,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      /// PATIENT PROFILE / CONDITIONS BANNER
                      if (_patientProfile != null)
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_pin_outlined, color: Color(0xFF2563EB), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Patient Medical Overview",
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildProfileRow("Blood Group", _patientProfile?['blood_group'] ?? "Not specified"),
                                _buildProfileRow("Age", _patientProfile?['age'] != null ? "${_patientProfile?['age']} yrs" : "Not specified"),
                                _buildProfileRow("Gender", _patientProfile?['gender'] ?? "Not specified"),
                                _buildProfileRow(
                                  "Known Conditions",
                                  [
                                    if (_patientProfile?['has_bp'] == 1 || _patientProfile?['has_bp'] == true) "Hypertension",
                                    if (_patientProfile?['has_tb'] == 1 || _patientProfile?['has_tb'] == true) "Tuberculosis",
                                    if (_patientProfile?['has_cancer'] == 1 || _patientProfile?['has_cancer'] == true) "Cancer Care",
                                  ].join(", ").isEmpty ? "None reported" : [
                                    if (_patientProfile?['has_bp'] == 1 || _patientProfile?['has_bp'] == true) "Hypertension",
                                    if (_patientProfile?['has_tb'] == 1 || _patientProfile?['has_tb'] == true) "Tuberculosis",
                                    if (_patientProfile?['has_cancer'] == 1 || _patientProfile?['has_cancer'] == true) "Cancer Care",
                                  ].join(", "),
                                ),
                                if (_patientProfile?['emergency_contact'] != null &&
                                    _patientProfile!['emergency_contact'].toString().isNotEmpty)
                                  _buildProfileRow("Emergency Contact", _patientProfile!['emergency_contact'].toString()),
                              ],
                            ),
                          ),
                        ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: iconColor, size: 24),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios, size: 11, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.grey.shade900,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}
