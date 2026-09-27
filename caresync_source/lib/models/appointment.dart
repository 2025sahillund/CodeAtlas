import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentFeedback {
  final String diagnosisSummary;
  final String medicationChanges;
  final List<String> prescribedTests;
  final DateTime? followUpDate;
  final String doctorInstructions;
  final int clarityScore; // 1 to 5
  final DateTime submittedAt;

  AppointmentFeedback({
    required this.diagnosisSummary,
    this.medicationChanges = '',
    this.prescribedTests = const [],
    this.followUpDate,
    this.doctorInstructions = '',
    this.clarityScore = 5,
    required this.submittedAt,
  });

  factory AppointmentFeedback.fromMap(Map<String, dynamic> map) {
    DateTime? fDate;
    if (map['followUpDate'] is Timestamp) {
      fDate = (map['followUpDate'] as Timestamp).toDate();
    } else if (map['followUpDate'] is String) {
      fDate = DateTime.tryParse(map['followUpDate'] as String);
    } else if (map['followUpDate'] is DateTime) {
      fDate = map['followUpDate'] as DateTime;
    }

    DateTime subAt = DateTime.now();
    if (map['submittedAt'] is Timestamp) {
      subAt = (map['submittedAt'] as Timestamp).toDate();
    } else if (map['submittedAt'] is String) {
      subAt = DateTime.tryParse(map['submittedAt'] as String) ?? DateTime.now();
    } else if (map['submittedAt'] is DateTime) {
      subAt = map['submittedAt'] as DateTime;
    }

    List<String> tests = [];
    if (map['prescribedTests'] is List) {
      tests = (map['prescribedTests'] as List).map((e) => e.toString()).toList();
    } else if (map['prescribedTests'] is String && (map['prescribedTests'] as String).isNotEmpty) {
      tests = (map['prescribedTests'] as String)
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return AppointmentFeedback(
      diagnosisSummary: map['diagnosisSummary'] ?? '',
      medicationChanges: map['medicationChanges'] ?? '',
      prescribedTests: tests,
      followUpDate: fDate,
      doctorInstructions: map['doctorInstructions'] ?? '',
      clarityScore: (map['clarityScore'] as num?)?.toInt() ?? 5,
      submittedAt: subAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'diagnosisSummary': diagnosisSummary,
      'medicationChanges': medicationChanges,
      'prescribedTests': prescribedTests,
      'followUpDate': followUpDate != null ? Timestamp.fromDate(followUpDate!) : null,
      'doctorInstructions': doctorInstructions,
      'clarityScore': clarityScore,
      'submittedAt': Timestamp.fromDate(submittedAt),
    };
  }
}

class Appointment {
  final String id;
  final String doctorName;
  final String specialty;
  final String hospitalName;
  final String clinicAddress;
  final String doctorPhone;
  final DateTime dateTime;
  final String purpose;
  final String status; // Upcoming, Completed, Cancelled, Rescheduled, Missed
  final String? cancellationReason;
  final DateTime? completedAt;
  final AppointmentFeedback? feedback;
  final int? notificationId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Appointment({
    required this.id,
    required this.doctorName,
    this.specialty = 'General Physician',
    required this.hospitalName,
    this.clinicAddress = '',
    this.doctorPhone = '',
    required this.dateTime,
    required this.purpose,
    this.status = 'Upcoming',
    this.cancellationReason,
    this.completedAt,
    this.feedback,
    this.notificationId,
    this.createdAt,
    this.updatedAt,
  });

  /// Derives stable 32-bit positive integer notification ID
  int get calculatedNotificationId => notificationId ?? (id.hashCode.abs() % 2147483647);

  /// Helper to check if an upcoming appointment has passed its scheduled time
  bool get isPastDue => (status == 'Upcoming' || status == 'Rescheduled') && DateTime.now().isAfter(dateTime);

  /// Normalized status helper for UI filters
  bool get isUpcomingOrActive => (status == 'Upcoming' || status == 'Rescheduled') && !isPastDue;
  bool get isCompleted => status == 'Completed' || feedback != null;
  bool get isCancelled => status == 'Cancelled';

  factory Appointment.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Appointment.fromMap(data, doc.id);
  }

  factory Appointment.fromMap(Map<String, dynamic> data, [String? docId]) {
    DateTime parsedDt = DateTime.now();
    if (data['dateTime'] is Timestamp) {
      parsedDt = (data['dateTime'] as Timestamp).toDate();
    } else if (data['dateTime'] is String) {
      parsedDt = DateTime.tryParse(data['dateTime'] as String) ?? DateTime.now();
    } else if (data['dateTime'] is DateTime) {
      parsedDt = data['dateTime'] as DateTime;
    }

    DateTime? compAt;
    if (data['completedAt'] is Timestamp) {
      compAt = (data['completedAt'] as Timestamp).toDate();
    } else if (data['completedAt'] is String) {
      compAt = DateTime.tryParse(data['completedAt'] as String);
    } else if (data['completedAt'] is DateTime) {
      compAt = data['completedAt'] as DateTime;
    }

    AppointmentFeedback? fb;
    if (data['feedback'] is Map) {
      fb = AppointmentFeedback.fromMap(Map<String, dynamic>.from(data['feedback'] as Map));
    }

    String rawStatus = data['status'] ?? 'Upcoming';
    // Auto-detect completed if feedback already exists
    if (fb != null && rawStatus == 'Upcoming') {
      rawStatus = 'Completed';
    }

    return Appointment(
      id: docId ?? data['id'] ?? '',
      doctorName: data['doctorName'] ?? '',
      specialty: data['specialty'] ?? (data['doctorSpecialty'] ?? 'General Physician'),
      hospitalName: data['hospitalName'] ?? '',
      clinicAddress: data['clinicAddress'] ?? '',
      doctorPhone: data['doctorPhone'] ?? '',
      dateTime: parsedDt,
      purpose: data['purpose'] ?? '',
      status: rawStatus,
      cancellationReason: data['cancellationReason'],
      completedAt: compAt,
      feedback: fb,
      notificationId: (data['notificationId'] as num?)?.toInt(),
      createdAt: data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] is Timestamp ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'doctorName': doctorName,
      'specialty': specialty,
      'hospitalName': hospitalName,
      'clinicAddress': clinicAddress,
      'doctorPhone': doctorPhone,
      'dateTime': Timestamp.fromDate(dateTime),
      'purpose': purpose,
      'status': status,
      'cancellationReason': cancellationReason,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'feedback': feedback?.toMap(),
      'notificationId': calculatedNotificationId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Appointment copyWith({
    String? id,
    String? doctorName,
    String? specialty,
    String? hospitalName,
    String? clinicAddress,
    String? doctorPhone,
    DateTime? dateTime,
    String? purpose,
    String? status,
    String? cancellationReason,
    DateTime? completedAt,
    AppointmentFeedback? feedback,
    int? notificationId,
  }) {
    return Appointment(
      id: id ?? this.id,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      hospitalName: hospitalName ?? this.hospitalName,
      clinicAddress: clinicAddress ?? this.clinicAddress,
      doctorPhone: doctorPhone ?? this.doctorPhone,
      dateTime: dateTime ?? this.dateTime,
      purpose: purpose ?? this.purpose,
      status: status ?? this.status,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      completedAt: completedAt ?? this.completedAt,
      feedback: feedback ?? this.feedback,
      notificationId: notificationId ?? this.notificationId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
