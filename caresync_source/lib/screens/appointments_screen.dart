import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/appointment.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/empty_state_widget.dart';

class AppointmentsScreen extends StatefulWidget {
  final String? targetUid;
  final bool isReadOnly;
  const AppointmentsScreen({super.key, this.targetUid, this.isReadOnly = false});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Appointment> _appointments = [];
  bool _isLoading = true;

  final List<String> _specialtySuggestions = [
    'General Physician',
    'Cardiologist',
    'Diabetologist / Endocrinologist',
    'Orthopedic',
    'Neurologist',
    'Pulmonologist (Chest)',
    'Dermatologist',
    'ENT Specialist',
    'Ophthalmologist (Eye)',
    'Gastroenterologist',
    'Dentist',
    'Other Specialist',
  ];

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final rawData = await ApiService.getAppointments(targetUid: widget.targetUid);
      final List<Appointment> list = rawData.map((map) => Appointment.fromMap(map, map['id'])).toList();

      // Sort chronological
      list.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      if (mounted) {
        setState(() {
          _appointments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading appointments: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleAppointmentReminder(Appointment appt) async {
    final int notifId = appt.calculatedNotificationId;
    final DateTime scheduledReminderTime = appt.dateTime.subtract(const Duration(hours: 1));

    if (scheduledReminderTime.isAfter(DateTime.now())) {
      await NotificationService.scheduleGenericReminder(
        id: notifId,
        title: "Upcoming Appointment in 1 Hour",
        body: "With ${appt.doctorName} (${appt.specialty}) at ${appt.hospitalName}",
        scheduledTime: scheduledReminderTime,
      );
    }
  }

  Future<void> _cancelAppointmentReminder(Appointment appt) async {
    await NotificationService.cancelNotification(appt.calculatedNotificationId);
  }

  void _showAppointmentCreationChooser() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Add Doctor Appointment",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(modalCtx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Option 1: Schedule Upcoming Visit
            InkWell(
              onTap: () {
                Navigator.pop(modalCtx);
                _showAddAppointmentSheet();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.event_available, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Schedule Upcoming Visit",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF1E3A8A)),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Book a future doctor appointment with reminder alerts",
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Option 2: Add Past Doctor Visit
            InkWell(
              onTap: () {
                Navigator.pop(modalCtx);
                _showAddPastAppointmentSheet();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.history_edu, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Add Past Doctor Visit",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF14532D)),
                          ),
                          SizedBox(height: 3),
                          Text(
                            "Record a completed consultation, diagnosis & prescriptions",
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF16A34A)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPastAppointmentSheet() {
    final doctorController = TextEditingController();
    final hospitalController = TextEditingController();
    final purposeController = TextEditingController();
    final diagnosisController = TextEditingController();
    final medChangesController = TextEditingController();
    final testsController = TextEditingController();
    final instructionsController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    String selectedSpecialty = 'General Physician';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();
    DateTime? followUpDate;
    int clarityScore = 5;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.history_edu, color: Color(0xFF16A34A), size: 22),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Record Past Doctor Visit",
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              "Document completed consultation & clinical notes",
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Doctor Name
                TextField(
                  controller: doctorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Doctor's Name *",
                    hintText: "e.g. Dr. Ramesh Sharma",
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Specialty Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedSpecialty,
                  decoration: InputDecoration(
                    labelText: "Doctor Specialty",
                    prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _specialtySuggestions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedSpecialty = val);
                  },
                ),
                const SizedBox(height: 12),

                // Hospital / Clinic
                TextField(
                  controller: hospitalController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Hospital / Clinic Name *",
                    hintText: "e.g. City Hospital, Apollo Clinic",
                    prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Date & Time of Past Visit
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Color(0xFF16A34A)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedTime.format(ctx),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Purpose
                TextField(
                  controller: purposeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Purpose of Visit",
                    hintText: "e.g. Routine checkup, Knee pain, Fever review",
                    prefixIcon: const Icon(Icons.assignment_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Divider / Section: Clinical Findings & Notes
                const Divider(height: 24),
                const Row(
                  children: [
                    Icon(Icons.notes, size: 18, color: Color(0xFF16A34A)),
                    SizedBox(width: 6),
                    Text(
                      "Clinical Summary & Findings",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF16A34A)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Diagnosis / Findings *
                TextField(
                  controller: diagnosisController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Doctor's Diagnosis / Findings *",
                    hintText: "e.g. Stage 1 Hypertension, seasonal bronchitis",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Medication Changes
                TextField(
                  controller: medChangesController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Medication Changes / Prescriptions",
                    hintText: "e.g. Started Telmisartan 40mg daily, stopped Atenolol",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Prescribed Tests
                TextField(
                  controller: testsController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Prescribed Diagnostic Tests (Comma-separated)",
                    hintText: "e.g. CBC, Lipid Profile, Chest X-Ray",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Doctor Instructions
                TextField(
                  controller: instructionsController,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Doctor Instructions & Advice",
                    hintText: "e.g. Low sodium diet, 30 min brisk walk, monitor BP weekly",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Recommended Follow-Up Date
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: followUpDate ?? DateTime.now().add(const Duration(days: 14)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setSheetState(() => followUpDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.event_repeat, color: Color(0xFF16A34A), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            followUpDate == null
                                ? "Select Recommended Follow-Up Date (Optional)"
                                : "Follow-Up: ${DateFormat('MMM dd, yyyy').format(followUpDate!)}",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: followUpDate != null ? FontWeight.bold : FontWeight.normal,
                              color: followUpDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                        ),
                        if (followUpDate != null)
                          GestureDetector(
                            onTap: () => setSheetState(() => followUpDate = null),
                            child: const Icon(Icons.clear, size: 18, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Clarity Score
                const Text(
                  "Did you clearly understand the doctor's instructions?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= clarityScore ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 30,
                      ),
                      onPressed: () => setSheetState(() => clarityScore = starVal),
                    );
                  }),
                ),
                Center(
                  child: Text(
                    clarityScore == 5
                        ? "5/5 • Everything was clear & understood"
                        : clarityScore >= 3
                            ? "$clarityScore/5 • Mostly clear instructions"
                            : "$clarityScore/5 • Had some doubts / need follow-up",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 14),

                // Optional Phone & Address
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Doctor / Clinic Phone (Optional)",
                    hintText: "For direct calls from the app",
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: "Room / Building Address (Optional)",
                    hintText: "e.g. OPD Block, Room 204",
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 22),

                // Save Button
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (doctorController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter doctor's name")),
                      );
                      return;
                    }
                    if (hospitalController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter hospital or clinic name")),
                      );
                      return;
                    }
                    if (diagnosisController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please provide diagnosis or visit summary")),
                      );
                      return;
                    }

                    setSheetState(() => isSaving = true);

                    final combinedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final testsList = testsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    final apptMap = {
                      'doctorName': doctorController.text.trim(),
                      'specialty': selectedSpecialty,
                      'hospitalName': hospitalController.text.trim(),
                      'purpose': purposeController.text.trim().isEmpty ? 'Medical Consultation' : purposeController.text.trim(),
                      'doctorPhone': phoneController.text.trim(),
                      'clinicAddress': addressController.text.trim(),
                      'dateTime': combinedDateTime,
                      'status': 'Completed',
                      'completedAt': Timestamp.fromDate(DateTime.now()),
                      'feedback': {
                        'diagnosisSummary': diagnosisController.text.trim(),
                        'medicationChanges': medChangesController.text.trim(),
                        'prescribedTests': testsList,
                        'followUpDate': followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
                        'doctorInstructions': instructionsController.text.trim(),
                        'clarityScore': clarityScore,
                        'submittedAt': Timestamp.fromDate(DateTime.now()),
                      },
                    };

                    final String? newId = await ApiService.addAppointment(apptMap, targetUid: widget.targetUid);
                    if (newId != null) {
                      // Note: No reminder scheduled for past visits!
                      final uid = widget.targetUid ?? ApiService.currentUid;
                      if (uid != null) {
                        ApiService.sendInAppNotification(
                          targetUid: uid,
                          title: "🩺 Past Doctor Visit Recorded",
                          body: "Recorded completed visit with ${doctorController.text.trim()} ($selectedSpecialty) on ${DateFormat('MMM dd, yyyy').format(combinedDateTime)}",
                          type: "appointment",
                          referenceId: "appt_past_$newId",
                        );
                      }

                      if (modalCtx.mounted) Navigator.pop(modalCtx);
                      _loadAppointments();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Past visit with ${doctorController.text.trim()} recorded successfully!")),
                        );
                      }
                    } else {
                      setSheetState(() => isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Failed to record visit. Try again.")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Past Doctor Visit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAppointmentSheet() {
    final doctorController = TextEditingController();
    final hospitalController = TextEditingController();
    final purposeController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();

    String selectedSpecialty = 'General Physician';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Schedule Doctor Visit",
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Doctor Name
                TextField(
                  controller: doctorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Doctor's Name *",
                    hintText: "e.g. Dr. Ramesh Sharma",
                    prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Specialty Dropdown
                DropdownButtonFormField<String>(
                  initialValue: selectedSpecialty,
                  decoration: InputDecoration(
                    labelText: "Doctor Specialty",
                    prefixIcon: const Icon(Icons.medical_services_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _specialtySuggestions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) setSheetState(() => selectedSpecialty = val);
                  },
                ),
                const SizedBox(height: 12),

                // Hospital / Clinic
                TextField(
                  controller: hospitalController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Hospital / Clinic Name *",
                    hintText: "e.g. Apollo Clinic or City Hospital",
                    prefixIcon: const Icon(Icons.local_hospital_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Purpose
                TextField(
                  controller: purposeController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: "Purpose of Visit",
                    hintText: "e.g. Routine BP checkup, Chest pain review",
                    prefixIcon: const Icon(Icons.assignment_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Doctor / Clinic Phone
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Doctor / Clinic Phone (Optional)",
                    hintText: "For direct calls from the app",
                    prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Room / Clinic Address
                TextField(
                  controller: addressController,
                  decoration: InputDecoration(
                    labelText: "Room / Building Address (Optional)",
                    hintText: "e.g. OPD Block, Room 204",
                    prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF2563EB)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),

                // Date & Time pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => selectedDate = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(selectedDate),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: ctx,
                            initialTime: selectedTime,
                          );
                          if (picked != null) {
                            setSheetState(() => selectedTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, size: 18, color: Color(0xFF2563EB)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  selectedTime.format(ctx),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Save Button
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (doctorController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter the doctor's name")),
                      );
                      return;
                    }
                    if (hospitalController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter hospital or clinic name")),
                      );
                      return;
                    }

                    setSheetState(() => isSaving = true);

                    final combinedDateTime = DateTime(
                      selectedDate.year,
                      selectedDate.month,
                      selectedDate.day,
                      selectedTime.hour,
                      selectedTime.minute,
                    );

                    final apptMap = {
                      'doctorName': doctorController.text.trim(),
                      'specialty': selectedSpecialty,
                      'hospitalName': hospitalController.text.trim(),
                      'purpose': purposeController.text.trim().isEmpty ? 'Medical Consultation' : purposeController.text.trim(),
                      'doctorPhone': phoneController.text.trim(),
                      'clinicAddress': addressController.text.trim(),
                      'dateTime': combinedDateTime,
                      'status': 'Upcoming',
                    };

                    final String? newId = await ApiService.addAppointment(apptMap);
                    if (newId != null) {
                      final newAppt = Appointment.fromMap(apptMap, newId);
                      await _scheduleAppointmentReminder(newAppt);

                      final uid = widget.targetUid ?? ApiService.currentUid;
                      if (uid != null) {
                        ApiService.sendInAppNotification(
                          targetUid: uid,
                          title: "📅 Appointment Scheduled",
                          body: "Visit with ${doctorController.text.trim()} ($selectedSpecialty) on ${DateFormat('MMM dd, yyyy @ h:mm a').format(combinedDateTime)}",
                          type: "appointment",
                          referenceId: "appt_$newId",
                        );
                      }

                      if (modalCtx.mounted) Navigator.pop(modalCtx);
                      _loadAppointments();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Appointment with ${doctorController.text} scheduled!")),
                        );
                      }
                    } else {
                      setSheetState(() => isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Failed to schedule appointment. Try again.")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save & Set Reminder", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRescheduleDialog(Appointment appt) {
    DateTime newDate = appt.dateTime.isAfter(DateTime.now()) ? appt.dateTime : DateTime.now().add(const Duration(days: 1));
    TimeOfDay newTime = TimeOfDay.fromDateTime(appt.dateTime);
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.edit_calendar, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(child: Text("Reschedule Visit", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Doctor: ${appt.doctorName}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("Hospital: ${appt.hospitalName}", style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              const Text("Select New Date & Time:", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: newDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setDialogState(() => newDate = picked);
                      },
                      icon: const Icon(Icons.calendar_month, size: 16),
                      label: Text(DateFormat('MMM dd').format(newDate), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showTimePicker(context: ctx, initialTime: newTime);
                        if (picked != null) setDialogState(() => newTime = picked);
                      },
                      icon: const Icon(Icons.access_time, size: 16),
                      label: Text(newTime.format(ctx), style: const TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                final updatedDateTime = DateTime(
                  newDate.year,
                  newDate.month,
                  newDate.day,
                  newTime.hour,
                  newTime.minute,
                );

                final bool success = await ApiService.rescheduleAppointment(
                  appointmentId: appt.id,
                  newDateTime: updatedDateTime,
                  targetUid: widget.targetUid,
                );

                if (success) {
                  await _cancelAppointmentReminder(appt);
                  final updatedAppt = appt.copyWith(dateTime: updatedDateTime, status: 'Rescheduled');
                  await _scheduleAppointmentReminder(updatedAppt);

                  final uid = widget.targetUid ?? ApiService.currentUid;
                  if (uid != null) {
                    ApiService.sendInAppNotification(
                      targetUid: uid,
                      title: "🔄 Appointment Rescheduled",
                      body: "Rescheduled visit with ${appt.doctorName} to ${DateFormat('MMM dd, yyyy @ h:mm a').format(updatedDateTime)}",
                      type: "appointment",
                      referenceId: "appt_resched_${appt.id}_${updatedDateTime.millisecondsSinceEpoch}",
                    );
                  }

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _loadAppointments();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Appointment rescheduled & reminder updated!")),
                    );
                  }
                } else {
                  setDialogState(() => isSaving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to reschedule. Please try again.")),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Update Visit"),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(Appointment appt) {
    final reasonController = TextEditingController();
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: Colors.red),
              SizedBox(width: 8),
              Text("Cancel Appointment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Are you sure you want to cancel visit with ${appt.doctorName}?"),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: "Reason for cancellation (Optional)",
                  hintText: "e.g. Doctor unavailable, Feeling better",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Keep Visit"),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : () async {
                setDialogState(() => isSaving = true);
                final bool success = await ApiService.updateAppointmentStatus(
                  appointmentId: appt.id,
                  status: 'Cancelled',
                  cancellationReason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : 'Cancelled by user',
                  targetUid: widget.targetUid,
                );

                if (success) {
                  await _cancelAppointmentReminder(appt);

                  final uid = widget.targetUid ?? ApiService.currentUid;
                  if (uid != null) {
                    ApiService.sendInAppNotification(
                      targetUid: uid,
                      title: "❌ Appointment Cancelled",
                      body: "Visit with ${appt.doctorName} on ${DateFormat('MMM dd').format(appt.dateTime)} was cancelled.",
                      type: "appointment",
                      referenceId: "appt_cancel_${appt.id}",
                    );
                  }

                  if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                  _loadAppointments();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Appointment cancelled")),
                    );
                  }
                } else {
                  setDialogState(() => isSaving = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Cancel Visit"),
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackModal(Appointment appt) {
    final existing = appt.feedback;
    final diagnosisController = TextEditingController(text: existing?.diagnosisSummary ?? '');
    final medChangesController = TextEditingController(text: existing?.medicationChanges ?? '');
    final testsController = TextEditingController(text: existing?.prescribedTests.join(', ') ?? '');
    final instructionsController = TextEditingController(text: existing?.doctorInstructions ?? '');

    DateTime? followUpDate = existing?.followUpDate;
    int clarityScore = existing?.clarityScore ?? 5;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.medical_services_outlined, color: Color(0xFF16A34A)),
                        const SizedBox(width: 8),
                        Text(
                          existing != null ? "Edit Clinical Summary" : "Post-Visit Clinical Summary",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                Text(
                  "Doctor: ${appt.doctorName} (${appt.specialty}) • ${appt.hospitalName}",
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 16),

                // Diagnosis Summary
                TextField(
                  controller: diagnosisController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Doctor's Diagnosis & Findings *",
                    hintText: "e.g. BP regulated, mild throat inflammation noted",
                    prefixIcon: const Icon(Icons.psychology_alt_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Medication Changes
                TextField(
                  controller: medChangesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Medication Changes & Prescriptions",
                    hintText: "e.g. Increased Telmisartan to 40mg, discontinued Paracetamol",
                    prefixIcon: const Icon(Icons.medication_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Prescribed Lab Tests
                TextField(
                  controller: testsController,
                  decoration: InputDecoration(
                    labelText: "Prescribed Diagnostic Tests (Comma separated)",
                    hintText: "e.g. Lipid Profile, Fasting Blood Sugar, ECG",
                    prefixIcon: const Icon(Icons.science_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),

                // Dietary / Lifestyle Instructions
                TextField(
                  controller: instructionsController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: "Doctor's Lifestyle & Dietary Advice",
                    hintText: "e.g. Low sodium diet, 30 min daily brisk walking",
                    prefixIcon: const Icon(Icons.health_and_safety_outlined, color: Color(0xFF16A34A)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),

                // Follow-up Date selector
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat, color: Color(0xFF16A34A), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          followUpDate != null
                              ? "Next Review: ${DateFormat('MMM dd, yyyy').format(followUpDate!)}"
                              : "Recommended Follow-up Visit",
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: followUpDate ?? DateTime.now().add(const Duration(days: 14)),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setSheetState(() => followUpDate = picked);
                          }
                        },
                        child: Text(followUpDate != null ? "Change" : "Select Date"),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Clarity Score (1-5)
                const Text(
                  "Did you clearly understand the doctor's instructions?",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      icon: Icon(
                        starVal <= clarityScore ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: Colors.amber.shade700,
                        size: 32,
                      ),
                      onPressed: () => setSheetState(() => clarityScore = starVal),
                    );
                  }),
                ),
                Center(
                  child: Text(
                    clarityScore == 5
                        ? "5/5 • Everything was clear & understood"
                        : clarityScore >= 3
                            ? "$clarityScore/5 • Mostly clear instructions"
                            : "$clarityScore/5 • Had some doubts / need follow-up",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 20),

                // Submit Button
                ElevatedButton(
                  onPressed: isSaving ? null : () async {
                    if (diagnosisController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please provide doctor's diagnosis or summary")),
                      );
                      return;
                    }

                    setSheetState(() => isSaving = true);

                    final testsList = testsController.text
                        .split(',')
                        .map((t) => t.trim())
                        .where((t) => t.isNotEmpty)
                        .toList();

                    final feedbackObj = AppointmentFeedback(
                      diagnosisSummary: diagnosisController.text.trim(),
                      medicationChanges: medChangesController.text.trim(),
                      prescribedTests: testsList,
                      followUpDate: followUpDate,
                      doctorInstructions: instructionsController.text.trim(),
                      clarityScore: clarityScore,
                      submittedAt: DateTime.now(),
                    );

                    final bool success = await ApiService.saveAppointmentFeedback(
                      appointmentId: appt.id,
                      feedback: feedbackObj.toMap(),
                      targetUid: widget.targetUid,
                    );

                    if (success) {
                      await _cancelAppointmentReminder(appt);

                      final uid = widget.targetUid ?? ApiService.currentUid;
                      if (uid != null) {
                        ApiService.sendInAppNotification(
                          targetUid: uid,
                          title: "🩺 Clinical Visit Summary Saved",
                          body: "Completed visit with ${appt.doctorName}. Diagnosis & notes saved.",
                          type: "appointment",
                          referenceId: "appt_summary_${appt.id}",
                        );
                      }

                      if (modalCtx.mounted) Navigator.pop(modalCtx);
                      _loadAppointments();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Clinical visit summary saved successfully!")),
                        );
                      }
                    } else {
                      setSheetState(() => isSaving = false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Failed to save summary. Try again.")),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Save Clinical Summary", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showClinicalSummaryView(Appointment appt) {
    final fb = appt.feedback;
    if (fb == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFDCFCE7),
                        child: Icon(Icons.verified, color: Color(0xFF16A34A)),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Doctor Visit Summary",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            DateFormat('MMMM dd, yyyy • hh:mm a').format(appt.dateTime),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(modalCtx),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Doctor & Hospital Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_hospital, color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appt.doctorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("${appt.specialty} • ${appt.hospitalName}", style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildSummarySection("Diagnosis & Findings", fb.diagnosisSummary, Icons.psychology_alt_outlined, Colors.purple),
              const SizedBox(height: 12),

              if (fb.medicationChanges.isNotEmpty) ...[
                _buildSummarySection("Medication Adjustments", fb.medicationChanges, Icons.medication_outlined, Colors.blue),
                const SizedBox(height: 12),
              ],

              if (fb.prescribedTests.isNotEmpty) ...[
                _buildSummarySection("Prescribed Tests", fb.prescribedTests.join(', '), Icons.science_outlined, Colors.orange),
                const SizedBox(height: 12),
              ],

              if (fb.doctorInstructions.isNotEmpty) ...[
                _buildSummarySection("Doctor's Advice & Lifestyle", fb.doctorInstructions, Icons.health_and_safety_outlined, Colors.green),
                const SizedBox(height: 12),
              ],

              if (fb.followUpDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_repeat, color: Colors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Recommended Follow-up Date", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text(DateFormat('EEEE, MMMM dd, yyyy').format(fb.followUpDate!), style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Clarity Rating
              Row(
                children: [
                  const Text("Instruction Clarity: ", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ...List.generate(5, (index) => Icon(
                    index < fb.clarityScore ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber.shade700,
                    size: 18,
                  )),
                ],
              ),
              const SizedBox(height: 16),

              if (!widget.isReadOnly)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(modalCtx);
                      _showFeedbackModal(appt);
                    },
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text("Edit Visit Summary"),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection(String title, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.black87)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final upcomingList = _appointments.where((a) => a.isUpcomingOrActive).toList();
    final completedList = _appointments.where((a) => a.isCompleted).toList();
    final allList = _appointments;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            widget.isReadOnly ? "Patient Appointments" : "Doctor Appointments",
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          elevation: 0,
          actions: widget.isReadOnly
              ? null
              : [
                  IconButton(
                    icon: const Icon(Icons.history_edu, color: Colors.white),
                    tooltip: "Record Past Doctor Visit",
                    onPressed: _showAddPastAppointmentSheet,
                  ),
                ],
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF16A34A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            tabs: [
              Tab(text: "Upcoming"),
              Tab(text: "Completed"),
              Tab(text: "All / History"),
            ],
          ),
        ),
        floatingActionButton: widget.isReadOnly
            ? null
            : FloatingActionButton.extended(
                onPressed: _showAppointmentCreationChooser,
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text("Add Visit", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildAppointmentList(upcomingList, "No upcoming appointments scheduled.", isUpcomingTab: true),
                  _buildAppointmentList(completedList, "No completed doctor visits recorded yet.", isCompletedTab: true),
                  _buildAppointmentList(allList, "No appointment records found."),
                ],
              ),
      ),
    );
  }

  Widget _buildAppointmentList(
    List<Appointment> list,
    String emptyMessage, {
    bool isUpcomingTab = false,
    bool isCompletedTab = false,
  }) {
    if (list.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadAppointments,
        child: ListView(
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.12),
            EmptyStateWidget(
              icon: isCompletedTab ? Icons.assignment_turned_in_outlined : Icons.event_available,
              title: isCompletedTab
                  ? "No Completed Visits"
                  : isUpcomingTab
                      ? "No Upcoming Appointments"
                      : "No Visits Recorded",
              subtitle: emptyMessage,
              iconColor: isCompletedTab ? const Color(0xFF16A34A) : const Color(0xFF2563EB),
              actionLabel: isCompletedTab && !widget.isReadOnly
                  ? "Record Past Doctor Visit"
                  : isUpcomingTab && !widget.isReadOnly
                      ? "Schedule Upcoming Visit"
                      : null,
              onActionPressed: isCompletedTab && !widget.isReadOnly
                  ? _showAddPastAppointmentSheet
                  : isUpcomingTab && !widget.isReadOnly
                      ? _showAddAppointmentSheet
                      : null,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAppointments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 80),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final appt = list[index];
          return _buildAppointmentCard(appt);
        },
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appt) {
    Color statusColor;
    String statusLabel = appt.status;

    if (appt.isCompleted) {
      statusColor = const Color(0xFF16A34A);
      statusLabel = "Completed";
    } else if (appt.isCancelled) {
      statusColor = Colors.grey;
      statusLabel = "Cancelled";
    } else if (appt.status == 'Rescheduled') {
      statusColor = const Color(0xFFEA580C);
      statusLabel = "Rescheduled";
    } else if (appt.isPastDue) {
      statusColor = Colors.amber.shade800;
      statusLabel = "Past Due";
    } else {
      statusColor = const Color(0xFF2563EB);
      statusLabel = "Upcoming";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Doctor Name & Status Badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  child: Icon(
                    appt.isCompleted ? Icons.check_circle_outline : Icons.calendar_month,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.doctorName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${appt.specialty} • ${appt.hospitalName}",
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Date & Time
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Color(0xFF2563EB)),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEEE, MMM dd, yyyy • hh:mm a').format(appt.dateTime),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Purpose
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.assignment_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    "Purpose: ${appt.purpose}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                ),
              ],
            ),

            if (appt.clinicAddress.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      appt.clinicAddress,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ],

            if (appt.isCancelled && appt.cancellationReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Reason: ${appt.cancellationReason}",
                  style: TextStyle(fontSize: 11, color: Colors.red.shade800),
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Action Buttons Row
            Row(
              children: [
                // Direct Call button if phone exists
                if (appt.doctorPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final sanitized = appt.doctorPhone.replaceAll(RegExp(r'[^\d+]'), '');
                        final uri = Uri.parse('tel:$sanitized');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.phone, size: 14, color: Colors.green),
                      label: const Text("Call", style: TextStyle(fontSize: 12, color: Colors.green)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: const Size(50, 32),
                      ),
                    ),
                  ),

                // If Completed -> View Clinical Summary button
                if (appt.feedback != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showClinicalSummaryView(appt),
                      icon: const Icon(Icons.assignment_turned_in, size: 16),
                      label: const Text("View Clinical Summary", style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  )
                // If not completed & not cancelled & not read-only -> Action buttons
                else if (!widget.isReadOnly && !appt.isCancelled) ...[
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showFeedbackModal(appt),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text("Complete & Add Notes", style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.edit_calendar, color: Color(0xFF2563EB), size: 20),
                    tooltip: "Reschedule",
                    onPressed: () => _showRescheduleDialog(appt),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 20),
                    tooltip: "Cancel Visit",
                    onPressed: () => _showCancelDialog(appt),
                  ),
                ],

                // Delete button for patient
                if (!widget.isReadOnly)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                    tooltip: "Delete Record",
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text("Delete Appointment"),
                          content: const Text("Are you sure you want to delete this appointment record?"),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("Cancel")),
                            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        await _cancelAppointmentReminder(appt);
                        await ApiService.deleteAppointment(appt.id, targetUid: widget.targetUid);
                        _loadAppointments();
                      }
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
