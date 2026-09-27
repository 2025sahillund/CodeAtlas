import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // medication, appointment, caregiver, emergency, vitals, general
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
    this.payload,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return AppNotification.fromMap(data, doc.id);
  }

  factory AppNotification.fromMap(Map<String, dynamic> data, [String? docId]) {
    DateTime created = DateTime.now();
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    } else if (data['createdAt'] is DateTime) {
      created = data['createdAt'] as DateTime;
    }

    return AppNotification(
      id: docId ?? data['id'] ?? '',
      title: data['title'] ?? 'CareSync Notification',
      body: data['body'] ?? '',
      type: data['type'] ?? 'general',
      referenceId: data['referenceId'],
      isRead: data['isRead'] == true,
      createdAt: created,
      payload: data['payload'] is Map ? Map<String, dynamic>.from(data['payload'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'referenceId': referenceId,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'payload': payload,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    String? referenceId,
    bool? isRead,
    DateTime? createdAt,
    Map<String, dynamic>? payload,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      referenceId: referenceId ?? this.referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      payload: payload ?? this.payload,
    );
  }
}
