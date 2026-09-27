import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../models/medicine.dart';
import '../services/api_service.dart';
import '../services/medicine_service.dart';
import '../services/medical_passport_pdf_service.dart';

class MedicalPassportScreen extends StatefulWidget {
  final String? targetUid;
  final bool isReadOnly;

  const MedicalPassportScreen({
    super.key,
    this.targetUid,
    this.isReadOnly = false,
  });

  @override
  State<MedicalPassportScreen> createState() => _MedicalPassportScreenState();
}

class _MedicalPassportScreenState extends State<MedicalPassportScreen> {
  bool _isLoading = true;
  bool _isExporting = false;

  Map<String, dynamic>? _profile;
  List<Medicine> _medicines = [];
  List<Map<String, dynamic>> _bpLogs = [];
  List<Map<String, dynamic>> _sugarLogs = [];
  List<Map<String, dynamic>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadAllPassportData();
  }

  Future<void> _loadAllPassportData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getProfile(targetUid: widget.targetUid),
        MedicineService.getInventory(targetUid: widget.targetUid),
        ApiService.getBPHistory(targetUid: widget.targetUid),
        ApiService.getSugarHistory(targetUid: widget.targetUid),
        ApiService.getAppointments(targetUid: widget.targetUid),
      ]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>? ?? {};
          _medicines = results[1] as List<Medicine>;
          _bpLogs = results[2] as List<Map<String, dynamic>>;
          _sugarLogs = results[3] as List<Map<String, dynamic>>;
          _appointments = results[4] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading medical passport: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSharePdf() async {
    if (_profile == null) return;
    setState(() => _isExporting = true);
    try {
      await MedicalPassportPdfService.sharePdf(
        profile: _profile!,
        medicines: _medicines,
        bpLogs: _bpLogs,
        sugarLogs: _sugarLogs,
        appointments: _appointments,
        careSyncId: widget.targetUid ?? ApiService.currentUid,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error exporting PDF: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _handlePreviewPdf() async {
    if (_profile == null) return;
    setState(() => _isExporting = true);
    try {
      final pdfBytes = await MedicalPassportPdfService.generatePdf(
        profile: _profile!,
        medicines: _medicines,
        bpLogs: _bpLogs,
        sugarLogs: _sugarLogs,
        appointments: _appointments,
        careSyncId: widget.targetUid ?? ApiService.currentUid,
      );

      final patientName = (_profile!['name'] ?? _profile!['fullName'] ?? 'Patient')
          .toString()
          .replaceAll(RegExp(r'[^\w\s]+'), '')
          .replaceAll(' ', '_');

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'CareSync_Medical_Passport_$patientName.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error previewing PDF: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          "Patient Medical Passport",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF1E3A8A),
        actions: [
          if (!_isLoading) ...[
            IconButton(
              icon: const Icon(Icons.print_outlined, color: Colors.white),
              tooltip: "Print / Preview PDF",
              onPressed: _isExporting ? null : _handlePreviewPdf,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: "Share Medical Passport PDF",
              onPressed: _isExporting ? null : _handleSharePdf,
            ),
          ]
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF1E3A8A)),
                  SizedBox(height: 16),
                  Text("Aggregating clinical records...", style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllPassportData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ================= TOP HEADER CARD =================
                    _buildHeaderBanner(),

                    const SizedBox(height: 16),

                    // ================= EXPORT ACTION BAR =================
                    _buildActionBar(),

                    const SizedBox(height: 16),

                    // ================= PATIENT IDENTIFICATION CARD =================
                    _buildPatientIdCard(),

                    const SizedBox(height: 16),

                    // ================= EMERGENCY & ALLERGIES CARD =================
                    _buildEmergencyAllergiesCard(),

                    const SizedBox(height: 16),

                    // ================= CHRONIC CONDITIONS CARD =================
                    _buildChronicConditionsCard(),

                    const SizedBox(height: 16),

                    // ================= ACTIVE MEDICATIONS CARD =================
                    _buildMedicationsCard(),

                    const SizedBox(height: 16),

                    // ================= RECENT VITALS CARD =================
                    _buildVitalsCard(),

                    const SizedBox(height: 16),

                    // ================= UPCOMING APPOINTMENTS CARD =================
                    _buildAppointmentsCard(),

                    const SizedBox(height: 20),

                    // ================= CLINICAL DISCLAIMER =================
                    _buildDisclaimerCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderBanner() {
    final name = _profile?['name'] ?? _profile?['fullName'] ?? 'Patient';
    final uid = widget.targetUid ?? ApiService.currentUid ?? 'Not Available';
    final int? calculatedAge = ApiService.calculateAge(_profile?['dob'] ?? _profile?['age']);
    final ageStr = calculatedAge != null ? '$calculatedAge Years' : 'Age Not Provided';
    final bloodGroup = _profile?['blood_group'] ?? 'Unknown';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.medical_information_outlined, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "$ageStr • Blood Group: $bloodGroup",
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "CareSync ID: $uid",
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: uid));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text("CareSync ID copied!"),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFF1E3A8A),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Icon(Icons.copy, size: 16, color: Colors.white70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: _isExporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.share, size: 18, color: Colors.white),
                label: Text(
                  _isExporting ? "Preparing PDF..." : "Share Medical Passport PDF",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _isExporting ? null : _handleSharePdf,
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              icon: const Icon(Icons.print, color: Color(0xFF1E3A8A)),
              tooltip: "Print / Full Preview",
              onPressed: _isExporting ? null : _handlePreviewPdf,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientIdCard() {
    final int? calculatedAge = ApiService.calculateAge(_profile?['dob'] ?? _profile?['age']);
    final ageStr = calculatedAge != null ? "$calculatedAge Years" : "--";
    final dobStr = (_profile?['dob'] != null && _profile!['dob'].toString().trim().isNotEmpty)
        ? _profile!['dob'].toString().trim()
        : "--";
    final gender = _profile?['gender'] ?? "--";
    final bloodGroup = _profile?['blood_group'] ?? "--";
    final height = (_profile?['height'] != null && _profile!['height'] != 0) ? "${_profile!['height']} cm" : "--";
    final weight = (_profile?['weight'] != null && _profile!['weight'] != 0) ? "${_profile!['weight']} kg" : "--";

    return _buildSectionCard(
      title: "Patient Identification",
      icon: Icons.person_outline,
      iconColor: const Color(0xFF2563EB),
      children: [
        _buildInfoGridRow("Age", ageStr, "Date of Birth", dobStr),
        const Divider(height: 16),
        _buildInfoGridRow("Gender", gender, "Blood Group", bloodGroup),
        const Divider(height: 16),
        _buildInfoGridRow("Height", height, "Weight", weight),
      ],
    );
  }

  Widget _buildEmergencyAllergiesCard() {
    final emergencyName = _profile?['emergency_contact_name'] ?? _profile?['emergency_contact'] ?? "Not specified";
    final emergencyPhone = _profile?['emergency_phone'] ?? "Not specified";
    final allergies = (_profile?['allergies'] != null && _profile!['allergies'].toString().trim().isNotEmpty)
        ? _profile!['allergies'].toString().trim()
        : "None reported";

    final bool hasAllergies = allergies != "None reported";

    return _buildSectionCard(
      title: "Emergency Contact & Allergies",
      icon: Icons.emergency_outlined,
      iconColor: Colors.red.shade700,
      children: [
        _buildInfoGridRow("Contact Name", emergencyName, "Phone Number", emergencyPhone),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasAllergies ? Colors.red.shade50 : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasAllergies ? Colors.red.shade200 : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                hasAllergies ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                color: hasAllergies ? Colors.red.shade700 : Colors.green.shade600,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Known Allergies / Drug Sensitivities",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: hasAllergies ? Colors.red.shade900 : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      allergies,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: hasAllergies ? Colors.red.shade800 : const Color(0xFF64748B),
                        fontWeight: hasAllergies ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChronicConditionsCard() {
    final bool hasBP = _profile?['has_bp'] == 1 || _profile?['has_bp'] == true;
    final bool hasTB = _profile?['has_tb'] == 1 || _profile?['has_tb'] == true;
    final bool hasCancer = _profile?['has_cancer'] == 1 || _profile?['has_cancer'] == true;

    final String bpDetail = hasBP ? (_profile?['bp_medication'] ?? _profile?['bp_frequency'] ?? 'Daily management') : 'None';
    final String tbDetail = hasTB ? (_profile?['tb_status'] ?? 'Under Observation') : 'None';
    final String cancerDetail = hasCancer
        ? "${_profile?['cancer_type'] ?? 'Oncology'} (${_profile?['cancer_treatment_stage'] ?? 'Stage 1'})"
        : 'None';

    return _buildSectionCard(
      title: "Chronic Medical Conditions",
      icon: Icons.monitor_heart_outlined,
      iconColor: const Color(0xFF9333EA),
      children: [
        _buildConditionTile("Hypertension (Blood Pressure)", hasBP, bpDetail),
        const SizedBox(height: 8),
        _buildConditionTile("Tuberculosis (TB)", hasTB, tbDetail),
        const SizedBox(height: 8),
        _buildConditionTile("Cancer Care", hasCancer, cancerDetail),
      ],
    );
  }

  Widget _buildConditionTile(String title, bool isDiagnosed, String detail) {
    final bgColor = isDiagnosed ? Colors.purple.shade50 : const Color(0xFFF8FAFC);
    final borderColor = isDiagnosed ? Colors.purple.shade200 : const Color(0xFFE2E8F0);
    final textColor = isDiagnosed ? Colors.purple.shade900 : const Color(0xFF475569);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            isDiagnosed ? Icons.check_box : Icons.check_box_outline_blank,
            color: isDiagnosed ? const Color(0xFF9333EA) : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                if (isDiagnosed)
                  Text(
                    "Details: $detail",
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.purple.shade700,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDiagnosed ? Colors.purple.shade100 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isDiagnosed ? "DIAGNOSED" : "NOT REPORTED",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDiagnosed ? Colors.purple.shade900 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationsCard() {
    return _buildSectionCard(
      title: "Current Active Prescriptions (${_medicines.length})",
      icon: Icons.medication_outlined,
      iconColor: const Color(0xFF0D9488),
      children: [
        if (_medicines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text(
                "No active medications currently registered.",
                style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _medicines.length,
            separatorBuilder: (context, index) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final med = _medicines[index];
              final timingsList = (med.timings != null && med.timings!.isNotEmpty)
                  ? med.timings!
                  : (med.time != '--:--' ? [med.time] : <String>[]);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.medication_outlined, color: Color(0xFF0D9488), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            med.name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Dosage: ${med.dosage.isNotEmpty ? med.dosage : 'Standard dose'}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (timingsList.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: timingsList.map((t) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      "${med.totalStock} left",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: med.totalStock <= med.stockThreshold ? Colors.red : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildVitalsCard() {
    Map<String, dynamic>? latestBP = _bpLogs.isNotEmpty ? _bpLogs.first : null;
    Map<String, dynamic>? latestSugar = _sugarLogs.isNotEmpty ? _sugarLogs.first : null;

    return _buildSectionCard(
      title: "Latest Vital Signs",
      icon: Icons.health_and_safety_outlined,
      iconColor: const Color(0xFF2563EB),
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Blood Pressure",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestBP != null ? "${latestBP['systolic']}/${latestBP['diastolic']}" : "---",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E3A8A),
                      ),
                    ),
                    Text(
                      latestBP != null ? "mmHg${latestBP['pulse'] != null ? ' • ${latestBP['pulse']} bpm' : ''}" : "No logs recorded",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    if (latestBP != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "${latestBP['log_date'] ?? ''} ${latestBP['log_time'] ?? ''}".trim(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.blue, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          "Blood Sugar",
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      latestSugar != null ? "${latestSugar['sugar_level']}" : "---",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                    Text(
                      latestSugar != null ? "mg/dL (${latestSugar['test_type'] ?? 'Random'})" : "No logs recorded",
                      style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                    ),
                    if (latestSugar != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "${latestSugar['log_date'] ?? ''} ${latestSugar['log_time'] ?? ''}".trim(),
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppointmentsCard() {
    Map<String, dynamic>? upcoming = _appointments.isNotEmpty ? _appointments.first : null;

    return _buildSectionCard(
      title: "Upcoming Medical Appointment",
      icon: Icons.calendar_month_outlined,
      iconColor: const Color(0xFF0284C7),
      children: [
        if (upcoming == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              "No upcoming appointments scheduled.",
              style: GoogleFonts.poppins(fontSize: 13, color: const Color(0xFF64748B)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.event, color: Color(0xFF0284C7), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        upcoming['doctorName'] ?? upcoming['doctor'] ?? 'Doctor Consultation',
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                      ),
                      Text(
                        upcoming['hospitalName'] ?? upcoming['hospital'] ?? 'General Clinic',
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 14, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            upcoming['dateTime'] is DateTime
                                ? DateFormat('MMM d, yyyy • h:mm a').format(upcoming['dateTime'] as DateTime)
                                : upcoming['dateTime']?.toString() ?? 'Scheduled',
                            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.red.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "DISCLAIMER: For informational and emergency reference only. Verify with the treating physician. Data is aggregated from CareSync health records.",
              style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFF991B1B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGridRow(String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(val1, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              const SizedBox(height: 2),
              Text(val2, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
            ],
          ),
        ),
      ],
    );
  }
}
