import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import '../models/family_member.dart';

class FirebaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static String? get uid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Sync Profile to Firestore
  static Future<void> syncProfileToFirestore(Map<String, dynamic> profileData) async {
    if (uid == null) return;
    await _db.collection('users').doc(uid).set(profileData, SetOptions(merge: true));
  }

  /// Fetch Profile from Firestore
  static Future<Map<String, dynamic>?> getProfileFromFirestore() async {
    if (uid == null) return null;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  /// Save Medicine to Firestore
  static Future<void> saveMedicineToFirestore(Medicine medicine, List<String> times, {String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return;
    
    final Map<String, dynamic> data = {
      'medicine_name': medicine.name,
      'total_stock': medicine.totalStock,
      'stock_threshold': medicine.stockThreshold,
      'updated_at': FieldValue.serverTimestamp(),
    };
    if (medicine.dosage.isNotEmpty && medicine.dosage != 'N/A') {
      data['dosage'] = medicine.dosage;
    }
    if (times.isNotEmpty) {
      data['timings'] = times;
    } else if (medicine.timings != null && medicine.timings!.isNotEmpty) {
      data['timings'] = medicine.timings;
    }
    await _db.collection('users').doc(effectiveUid).collection('medicines').doc(medicine.name).set(
      data,
      SetOptions(merge: true),
    );
  }

  /// Fetch Medicines from Firestore for current user
  static Future<List<Map<String, dynamic>>> getMedicinesFromFirestore() async {
    if (uid == null) return [];
    return getMedicinesForUser(uid!);
  }

  /// Generic fetch for a specific user (supports caregiver mode)
  static Future<List<Map<String, dynamic>>> getMedicinesForUser(String targetUid) async {
    try {
      final snapshot = await _db.collection('users').doc(targetUid).collection('medicines').get();
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        if (!data.containsKey('medicine_name') || data['medicine_name'] == null || (data['medicine_name'] as String).isEmpty) {
          data['medicine_name'] = doc.id;
        }
        return data;
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete Medicine from Firestore
  static Future<void> deleteMedicineFromFirestore(String medicineName, {String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return;
    await _db.collection('users').doc(effectiveUid).collection('medicines').doc(medicineName).delete();
  }

  /// Log Medicine Dose Taken to Firestore
  static Future<void> logDoseTakenToFirestore({
    required String medicineName,
    required String reminderTime,
    String? targetUid,
  }) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = '${today}_${medicineName}_$reminderTime'.replaceAll(':', '-');
    
    await _db.collection('users').doc(effectiveUid).collection('medicine_logs').doc(docId).set({
      'medicine_name': medicineName,
      'reminder_time': reminderTime,
      'log_date': today,
      'status': 'taken',
      'taken_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete / Revert Medicine Dose Taken from Firestore (Undo Dose)
  static Future<void> deleteDoseLogFromFirestore({
    required String medicineName,
    required String reminderTime,
    String? targetUid,
  }) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final docId = '${today}_${medicineName}_$reminderTime'.replaceAll(':', '-');
    
    try {
      await _db.collection('users').doc(effectiveUid).collection('medicine_logs').doc(docId).delete();
    } catch (e) {
      debugPrint("deleteDoseLogFromFirestore error: $e");
    }
  }

  /// Fetch today's dose logs from Firestore
  static Future<List<Map<String, dynamic>>> getTodayDoseLogsFromFirestore({String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return [];
    final today = DateTime.now().toIso8601String().substring(0, 10);
    try {
      final snapshot = await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('medicine_logs')
          .where('log_date', isEqualTo: today)
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Fetch all dose logs for stats from Firestore
  static Future<List<Map<String, dynamic>>> getAllDoseLogsFromFirestore({String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('medicine_logs')
          .get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Log Sugar to Firestore
  static Future<void> logSugarToFirestore(int level, String date, String time) async {
    if (uid == null) return;
    await _db.collection('users').doc(uid).collection('sugar_logs').add({
      'sugar_level': level,
      'log_date': date,
      'log_time': time,
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  // --- FAMILY MEMBERS ---

  /// Reactive stream of family members for current or target user
  static Stream<List<FamilyMember>> getFamilyMembersStream({String? targetUid}) {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) {
      return Stream.value([]);
    }
    return _db
        .collection('users')
        .doc(effectiveUid)
        .collection('family_members')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList())
        .handleError((error) {
          return <FamilyMember>[];
        });
  }

  /// Fetch all family members once
  static Future<List<FamilyMember>> getFamilyMembers({String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return [];
    try {
      final snapshot = await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('family_members')
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs.map((doc) => FamilyMember.fromFirestore(doc)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a family member to Firestore
  static Future<bool> addFamilyMember(FamilyMember member, {String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null) return false;
    try {
      await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('family_members')
          .add(member.toFirestore());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Update an existing family member in Firestore
  static Future<bool> updateFamilyMember(FamilyMember member, {String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null || member.id.isEmpty) return false;
    try {
      await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('family_members')
          .doc(member.id)
          .set(member.toFirestore(), SetOptions(merge: true));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Delete a family member from Firestore
  static Future<bool> deleteFamilyMember(String memberId, {String? targetUid}) async {
    final effectiveUid = targetUid ?? uid;
    if (effectiveUid == null || memberId.isEmpty) return false;
    try {
      await _db
          .collection('users')
          .doc(effectiveUid)
          .collection('family_members')
          .doc(memberId)
          .delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Send a connection invitation to a family member's CareSync account
  static Future<bool> sendFamilyInvitation({
    required FamilyMember member,
    required String targetEmail,
  }) async {
    if (uid == null || member.id.isEmpty) return false;
    final normalizedEmail = targetEmail.trim().toLowerCase();
    try {
      // 1. Create a pending connection record in /connections
      final connectionRef = await _db.collection('connections').add({
        'senderUid': uid,
        'senderEmail': _auth.currentUser?.email ?? '',
        'patientUid': uid,
        'recipientEmail': normalizedEmail,
        'caregiverEmail': normalizedEmail,
        'relationship': member.relation,
        'familyMemberName': member.name,
        'familyMemberId': member.id,
        'status': 'pending',
        'type': 'family_invitation',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Update the local family member doc with pending status
      await _db
          .collection('users')
          .doc(uid)
          .collection('family_members')
          .doc(member.id)
          .set({
        'linkedEmail': normalizedEmail,
        'connectionStatus': 'pending',
        'connectionId': connectionRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Cancel an invitation or disconnect a family member
  static Future<bool> cancelFamilyInvitation({
    required FamilyMember member,
  }) async {
    if (uid == null || member.id.isEmpty) return false;
    try {
      // Delete connection document if present
      if (member.connectionId != null && member.connectionId!.isNotEmpty) {
        try {
          await _db.collection('connections').doc(member.connectionId).delete();
        } catch (_) {}
      }

      // Reset family member connection fields
      await _db
          .collection('users')
          .doc(uid)
          .collection('family_members')
          .doc(member.id)
          .update({
        'linkedEmail': FieldValue.delete(),
        'connectionStatus': 'unlinked',
        'connectionId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}


