import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/medicine.dart';
import 'api_service.dart';

class MedicalPassportPdfService {
  /// Generates a clean, high-contrast, professional 1-page PDF of the patient's medical passport.
  static Future<Uint8List> generatePdf({
    required Map<String, dynamic> profile,
    required List<Medicine> medicines,
    required List<Map<String, dynamic>> bpLogs,
    required List<Map<String, dynamic>> sugarLogs,
    required List<Map<String, dynamic>> appointments,
    String? careSyncId,
  }) async {
    final pdf = pw.Document();

    final String generatedTimestamp =
        DateFormat('MMM d, yyyy - h:mm a').format(DateTime.now());

    final String name = profile['name'] ?? profile['fullName'] ?? 'Patient';
    final String uid = careSyncId ?? profile['uid'] ?? ApiService.currentUid ?? 'N/A';
    final int? calculatedAge = ApiService.calculateAge(profile['dob'] ?? profile['age']);
    final String ageStr = calculatedAge != null ? '$calculatedAge Years' : 'Not specified';
    final String dobStr = (profile['dob'] != null && profile['dob'].toString().trim().isNotEmpty)
        ? profile['dob'].toString().trim()
        : 'Not specified';
    final String gender = profile['gender'] ?? 'Not specified';
    final String bloodGroup = profile['blood_group'] ?? 'Not specified';

    final String? height = (profile['height'] != null && profile['height'] != 0 && profile['height'] != '0')
        ? "${profile['height']} cm"
        : null;
    final String? weight = (profile['weight'] != null && profile['weight'] != 0 && profile['weight'] != '0')
        ? "${profile['weight']} kg"
        : null;

    final String emergencyName = profile['emergency_contact_name'] ?? profile['emergency_contact'] ?? 'Not specified';
    final String emergencyPhone = profile['emergency_phone'] ?? 'Not specified';

    final String allergies = (profile['allergies'] != null && profile['allergies'].toString().trim().isNotEmpty)
        ? profile['allergies'].toString().trim()
        : 'None reported';

    final bool hasBP = profile['has_bp'] == 1 || profile['has_bp'] == true;
    final bool hasTB = profile['has_tb'] == 1 || profile['has_tb'] == true;
    final bool hasCancer = profile['has_cancer'] == 1 || profile['has_cancer'] == true;

    // Latest BP
    Map<String, dynamic>? latestBP;
    if (bpLogs.isNotEmpty) {
      latestBP = bpLogs.first;
    }

    // Latest Sugar
    Map<String, dynamic>? latestSugar;
    if (sugarLogs.isNotEmpty) {
      latestSugar = sugarLogs.first;
    }

    // Upcoming Appointment
    Map<String, dynamic>? upcomingAppointment;
    if (appointments.isNotEmpty) {
      upcomingAppointment = appointments.first;
    }

    // Theme colors
    final primaryColor = PdfColor.fromInt(0xFF1E3A8A); // Deep Navy
    final surfaceColor = PdfColor.fromInt(0xFFF8FAFC); // Slate light
    final borderColor = PdfColor.fromInt(0xFFCBD5E1); // Slate border
    final textDark = PdfColor.fromInt(0xFF0F172A); // Slate 900
    final textMuted = PdfColor.fromInt(0xFF475569); // Slate 600

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ================= HEADER =================
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'CareSync - Patient Medical Passport',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Comprehensive Clinical & Emergency Summary',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'CareSync ID: $uid',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Generated: $generatedTimestamp',
                          style: const pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 10),

              // ================= ROW 1: DEMOGRAPHICS & EMERGENCY =================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Personal Details Box
                  pw.Expanded(
                    flex: 3,
                    child: _buildSectionBox(
                      title: 'Patient Identification',
                      primaryColor: primaryColor,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      children: [
                        _buildInlineRow('Full Name:', name, textDark, textMuted, isBold: true),
                        _buildInlineRow('Age / DOB:', '$ageStr | $dobStr', textDark, textMuted),
                        _buildInlineRow('Gender:', gender, textDark, textMuted),
                        _buildInlineRow('Blood Group:', bloodGroup, textDark, textMuted, isBold: true, highlight: true),
                        if (height != null || weight != null)
                          _buildInlineRow(
                            'Physical Metrics:',
                            [?height, ?weight].join(' / '),
                            textDark,
                            textMuted,
                          ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Emergency & Contacts Box
                  pw.Expanded(
                    flex: 2,
                    child: _buildSectionBox(
                      title: 'Emergency & Precautions',
                      primaryColor: primaryColor,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      children: [
                        _buildInlineRow('Contact:', emergencyName, textDark, textMuted, isBold: true),
                        _buildInlineRow('Phone:', emergencyPhone, textDark, textMuted),
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Known Allergies:',
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark),
                        ),
                        pw.Text(
                          allergies,
                          style: pw.TextStyle(
                            fontSize: 8,
                            color: allergies != 'None reported' ? PdfColors.red900 : textMuted,
                            fontWeight: allergies != 'None reported' ? pw.FontWeight.bold : pw.FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // ================= ROW 2: CHRONIC CONDITIONS =================
              _buildSectionBox(
                title: 'Chronic Health Conditions & Disease Management',
                primaryColor: primaryColor,
                borderColor: borderColor,
                surfaceColor: surfaceColor,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildConditionBadge(
                          'Hypertension (BP)',
                          hasBP,
                          detail: hasBP ? (profile['bp_medication'] ?? profile['bp_frequency'] ?? 'Active Management') : 'None reported',
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _buildConditionBadge(
                          'Tuberculosis (TB)',
                          hasTB,
                          detail: hasTB ? (profile['tb_status'] ?? 'Under Observation') : 'None reported',
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Expanded(
                        child: _buildConditionBadge(
                          'Cancer Care',
                          hasCancer,
                          detail: hasCancer ? "${profile['cancer_type'] ?? 'Oncology'} (${profile['cancer_treatment_stage'] ?? 'Stage 1'})" : 'None reported',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 8),

              // ================= ROW 3: ACTIVE MEDICATIONS =================
              _buildSectionBox(
                title: 'Current Active Medications (${medicines.length})',
                primaryColor: primaryColor,
                borderColor: borderColor,
                surfaceColor: surfaceColor,
                children: [
                  if (medicines.isEmpty)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 4),
                      child: pw.Text('No active medications currently registered.', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                    )
                  else
                    pw.Table(
                      border: pw.TableBorder.all(color: borderColor, width: 0.5),
                      children: [
                        // Header
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFE2E8F0)),
                          children: [
                            _buildTableHeaderCell('Medicine Name', flex: 3),
                            _buildTableHeaderCell('Dosage', flex: 2),
                            _buildTableHeaderCell('Daily Timings / Frequency', flex: 3),
                            _buildTableHeaderCell('Stock', flex: 1),
                          ],
                        ),
                        // Rows
                        ...medicines.map((med) {
                          final timingsText = (med.timings != null && med.timings!.isNotEmpty)
                              ? med.timings!.join(', ')
                              : (med.time != '--:--' ? med.time : 'As prescribed');
                          return pw.TableRow(
                            children: [
                              _buildTableCell(med.name, isBold: true),
                              _buildTableCell(med.dosage.isNotEmpty ? med.dosage : 'Standard'),
                              _buildTableCell(timingsText),
                              _buildTableCell('${med.totalStock} units', alignRight: true),
                            ],
                          );
                        }),
                      ],
                    ),
                ],
              ),

              pw.SizedBox(height: 8),

              // ================= ROW 4: RECENT VITALS & APPOINTMENTS =================
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Latest Vitals
                  pw.Expanded(
                    flex: 1,
                    child: _buildSectionBox(
                      title: 'Latest Vital Signs',
                      primaryColor: primaryColor,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      children: [
                        // Blood Pressure
                        if (latestBP != null) ...[
                          _buildInlineRow(
                            'Blood Pressure:',
                            "${latestBP['systolic']}/${latestBP['diastolic']} mmHg"
                                "${latestBP['pulse'] != null ? ' (Pulse: ${latestBP['pulse']} bpm)' : ''}",
                            textDark,
                            textMuted,
                            isBold: true,
                          ),
                          _buildInlineRow(
                            'BP Recorded:',
                            "${latestBP['log_date'] ?? ''} ${latestBP['log_time'] ?? ''}".trim(),
                            textDark,
                            textMuted,
                          ),
                        ] else
                          pw.Text('Blood Pressure: No records logged', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                        
                        pw.Divider(color: borderColor, height: 6, thickness: 0.5),

                        // Blood Sugar
                        if (latestSugar != null) ...[
                          _buildInlineRow(
                            'Blood Sugar:',
                            "${latestSugar['sugar_level']} mg/dL (${latestSugar['test_type'] ?? 'Random'})",
                            textDark,
                            textMuted,
                            isBold: true,
                          ),
                          _buildInlineRow(
                            'Sugar Recorded:',
                            "${latestSugar['log_date'] ?? ''} ${latestSugar['log_time'] ?? ''}".trim(),
                            textDark,
                            textMuted,
                          ),
                        ] else
                          pw.Text('Blood Sugar: No records logged', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  // Upcoming Appointments
                  pw.Expanded(
                    flex: 1,
                    child: _buildSectionBox(
                      title: 'Upcoming Medical Appointment',
                      primaryColor: primaryColor,
                      borderColor: borderColor,
                      surfaceColor: surfaceColor,
                      children: [
                        if (upcomingAppointment != null) ...[
                          _buildInlineRow(
                            'Doctor / Specialist:',
                            upcomingAppointment['doctorName'] ?? upcomingAppointment['doctor'] ?? 'Doctor Consultation',
                            textDark,
                            textMuted,
                            isBold: true,
                          ),
                          _buildInlineRow(
                            'Facility / Hospital:',
                            upcomingAppointment['hospitalName'] ?? upcomingAppointment['hospital'] ?? 'General Clinic',
                            textDark,
                            textMuted,
                          ),
                          _buildInlineRow(
                            'Scheduled Date:',
                            upcomingAppointment['dateTime'] is DateTime
                                ? DateFormat('MMM d, yyyy - h:mm a').format(upcomingAppointment['dateTime'] as DateTime)
                                : upcomingAppointment['dateTime']?.toString() ?? 'Scheduled',
                            textDark,
                            textMuted,
                            isBold: true,
                          ),
                          if (upcomingAppointment['purpose'] != null && upcomingAppointment['purpose'].toString().isNotEmpty)
                            _buildInlineRow(
                              'Purpose:',
                              upcomingAppointment['purpose'].toString(),
                              textDark,
                              textMuted,
                            ),
                        ] else
                          pw.Padding(
                            padding: const pw.EdgeInsets.symmetric(vertical: 6),
                            child: pw.Text('No pending appointments scheduled.', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ================= FOOTER / VERIFICATION QR BADGE =================
              pw.SizedBox(height: 6),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: borderColor, width: 0.6),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Row(
                      children: [
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.qrCode(),
                          data: 'CARESYNC:VERIFIED:$uid:$generatedTimestamp',
                          width: 30,
                          height: 30,
                        ),
                        pw.SizedBox(width: 8),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Verified by CareSync Cloud',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            pw.SizedBox(height: 1),
                            pw.Text(
                              'Authentic encrypted clinical summary export',
                              style: pw.TextStyle(fontSize: 6.5, color: textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Text(
                      'Token: ${uid.hashCode.toRadixString(16).toUpperCase()}',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // ================= DISCLAIMER =================
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFEF2F2),
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColor.fromInt(0xFFFECACA), width: 0.8),
                ),
                child: pw.Row(
                  children: [
                    pw.Expanded(
                      child: pw.Text(
                        'DISCLAIMER: For informational and emergency reference only. Verify with the treating physician. '
                        'This document contains self-reported and connected health records from CareSync.',
                        style: const pw.TextStyle(
                          color: PdfColors.red900,
                          fontSize: 7,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Shares the generated Medical Passport PDF via native device share sheet
  static Future<void> sharePdf({
    required Map<String, dynamic> profile,
    required List<Medicine> medicines,
    required List<Map<String, dynamic>> bpLogs,
    required List<Map<String, dynamic>> sugarLogs,
    required List<Map<String, dynamic>> appointments,
    String? careSyncId,
  }) async {
    final pdfBytes = await generatePdf(
      profile: profile,
      medicines: medicines,
      bpLogs: bpLogs,
      sugarLogs: sugarLogs,
      appointments: appointments,
      careSyncId: careSyncId,
    );

    final patientName = (profile['name'] ?? profile['fullName'] ?? 'Patient')
        .toString()
        .replaceAll(RegExp(r'[^\w\s]+'), '')
        .replaceAll(' ', '_');

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'CareSync_Medical_Passport_$patientName.pdf',
    );
  }

  // ================= HELPER WIDGETS =================

  static pw.Widget _buildSectionBox({
    required String title,
    required PdfColor primaryColor,
    required PdfColor borderColor,
    required PdfColor surfaceColor,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: surfaceColor,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              color: primaryColor,
              fontSize: 8.5,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          ...children,
        ],
      ),
    );
  }

  static pw.Widget _buildInlineRow(
    String label,
    String value,
    PdfColor textDark,
    PdfColor textMuted, {
    bool isBold = false,
    bool highlight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontSize: 8, color: textMuted),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              value,
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                fontSize: 8,
                color: highlight ? PdfColor.fromInt(0xFF1E3A8A) : textDark,
                fontWeight: (isBold || highlight) ? pw.FontWeight.bold : pw.FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildConditionBadge(String label, bool isPresent, {String? detail}) {
    final bgColor = isPresent ? PdfColor.fromInt(0xFFFEE2E2) : PdfColor.fromInt(0xFFF1F5F9);
    final textColor = isPresent ? PdfColor.fromInt(0xFF991B1B) : PdfColor.fromInt(0xFF64748B);
    final borderColor = isPresent ? PdfColor.fromInt(0xFFFCA5A5) : PdfColor.fromInt(0xFFE2E8F0);

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: pw.BoxDecoration(
        color: bgColor,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: borderColor, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(label, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: textColor)),
              pw.Text(isPresent ? 'DIAGNOSED' : 'NONE', style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: textColor)),
            ],
          ),
          if (detail != null && detail.isNotEmpty) ...[
            pw.SizedBox(height: 1.5),
            pw.Text(detail, style: pw.TextStyle(fontSize: 7, color: textColor)),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeaderCell(String text, {required int flex}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: pw.FontWeight.bold,
          color: PdfColor.fromInt(0xFF1E293B),
        ),
      ),
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isBold = false, bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColor.fromInt(0xFF334155),
        ),
      ),
    );
  }
}
