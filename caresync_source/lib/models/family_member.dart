import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyMember {
  final String id;
  final String name;
  final String relation;
  final int age;
  final List<String> conditions;
  final String avatar;
  final DateTime? createdAt;
  final String? linkedEmail;
  final String? connectionStatus; // 'unlinked', 'pending', 'connected'
  final String? connectionId;

  FamilyMember({
    this.id = '',
    required this.name,
    required this.relation,
    required this.age,
    required this.conditions,
    required this.avatar,
    this.createdAt,
    this.linkedEmail,
    this.connectionStatus,
    this.connectionId,
  });

  factory FamilyMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return FamilyMember.fromMap(data, doc.id);
  }

  factory FamilyMember.fromMap(Map<String, dynamic> data, String id) {
    List<String> parsedConditions = [];
    if (data['conditions'] is List) {
      parsedConditions = (data['conditions'] as List)
          .map((c) => c.toString().trim())
          .where((c) => c.isNotEmpty)
          .toList();
    }

    DateTime? created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String);
    }

    return FamilyMember(
      id: id,
      name: data['name'] ?? '',
      relation: data['relation'] ?? 'Other',
      age: (data['age'] is num) ? (data['age'] as num).toInt() : int.tryParse(data['age']?.toString() ?? '0') ?? 0,
      conditions: parsedConditions,
      avatar: data['avatar'] ?? '👤',
      createdAt: created,
      linkedEmail: data['linkedEmail'] as String?,
      connectionStatus: data['connectionStatus'] as String? ?? 'unlinked',
      connectionId: data['connectionId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'relation': relation,
      'age': age,
      'conditions': conditions,
      'avatar': avatar,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'linkedEmail': linkedEmail,
      'connectionStatus': connectionStatus ?? 'unlinked',
      'connectionId': connectionId,
    };
  }

  FamilyMember copyWith({
    String? id,
    String? name,
    String? relation,
    int? age,
    List<String>? conditions,
    String? avatar,
    DateTime? createdAt,
    String? linkedEmail,
    String? connectionStatus,
    String? connectionId,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      name: name ?? this.name,
      relation: relation ?? this.relation,
      age: age ?? this.age,
      conditions: conditions ?? this.conditions,
      avatar: avatar ?? this.avatar,
      createdAt: createdAt ?? this.createdAt,
      linkedEmail: linkedEmail ?? this.linkedEmail,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      connectionId: connectionId ?? this.connectionId,
    );
  }
}
