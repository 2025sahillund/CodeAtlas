import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'medicine_service.dart';
import '../models/app_notification.dart';

class ApiService {
  static const String baseUrl = "http://10.0.2.2:5000";
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static String? get currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// Reactive stream of the user's Firestore document
  static Stream<Map<String, dynamic>?> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) => doc.data());
  }

  /// Reactive stream of active caregiver connections where the user is caregiver
  static Stream<List<Map<String, dynamic>>> activeConnectionsStream(String uid) {
    return _db
        .collection('connections')
        .where('caregiverUid', isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final Set<String> seenPatients = {};
          final List<Map<String, dynamic>> connections = [];
          for (var doc in snapshot.docs) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            final pUid = data['patientUid'] as String? ?? '';
            if (pUid.isNotEmpty && !seenPatients.contains(pUid)) {
              seenPatients.add(pUid);
              connections.add(data);
            }
          }
          return connections;
        })
        .handleError((e) {
          debugPrint("Active connections stream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  /// Reactive stream of pending requests received by the patient
  static Stream<List<Map<String, dynamic>>> incomingRequestsStream(String patientUid) {
    return _db
        .collection('connections')
        .where('patientUid', isEqualTo: patientUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList();
        })
        .handleError((e) {
          debugPrint("Incoming requests stream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  /// Reactive stream of pending requests sent by the caregiver
  static Stream<List<Map<String, dynamic>>> outgoingRequestsStream(String caregiverUid) {
    return _db
        .collection('connections')
        .where('caregiverUid', isEqualTo: caregiverUid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList();
        })
        .handleError((e) {
          debugPrint("Outgoing requests stream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  /// Reactive stream of active caregivers currently monitoring the patient
  static Stream<List<Map<String, dynamic>>> patientActiveCaregiversStream(String patientUid) {
    return _db
        .collection('connections')
        .where('patientUid', isEqualTo: patientUid)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            return data;
          }).toList();
        })
        .handleError((e) {
          debugPrint("Patient active caregivers stream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  /// 🔥 Google Sign In Implementation
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
      
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      if (userCredential.user != null) {
        await syncUser();
      }
      return userCredential;
    } catch (e) {
      debugPrint("Google Sign-In Error: $e");
      rethrow;
    }
  }

  static Future<void> syncUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    final docRef = _db.collection('users').doc(user.uid);
    final doc = await docRef.get();
    final data = doc.data() ?? {};

    Map<String, dynamic> updates = {
      'lastLogin': FieldValue.serverTimestamp(),
      'email': user.email,
      'uid': user.uid,
    };

    // Preserve existing role if set; auto-heal for existing health profiles
    if (data['role'] != null) {
      updates['role'] = data['role'];
    } else if (hasPersonalProfile(data)) {
      updates['role'] = 'patient';
    }

    // Preserve or infer onboarding/profile flags
    if (data['hasPersonalProfile'] != null) {
      updates['hasPersonalProfile'] = data['hasPersonalProfile'];
    } else if (data['role'] == 'patient' || hasPersonalProfile(data)) {
      updates['hasPersonalProfile'] = true;
    }

    if (data['personalOnboardingCompleted'] != null) {
      updates['personalOnboardingCompleted'] = data['personalOnboardingCompleted'];
    } else if (data['onboardingCompleted'] != null) {
      updates['personalOnboardingCompleted'] = data['onboardingCompleted'];
    } else if (hasHealthData(data)) {
      updates['personalOnboardingCompleted'] = true;
    }

    // Use merge: true to preserve all existing health data, medicines, logs, etc.
    await docRef.set(updates, SetOptions(merge: true));

    // Backend sync
    try {
      await http.post(
        Uri.parse("$baseUrl/auth/sync_user"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "firebase_uid": user.uid,
          "email": user.email,
          "name": user.displayName ?? "User",
        }),
      ).timeout(const Duration(seconds: 3));
      
      await MedicineService.getInventory(); 
      await registerDeviceToken();
    } catch (_) {}
  }

  /// Called post-login from InitialSetupScreen for new accounts
  static Future<void> setInitialSetupChoice({required bool forMyself}) async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid!).set({
      'hasPersonalProfile': forMyself,
      'personalOnboardingCompleted': !forMyself, // Caregivers skip medical onboarding
      'role': forMyself ? 'patient' : 'caregiver', // Legacy support
    }, SetOptions(merge: true));
  }

  /// Marks personal health onboarding as finished
  static Future<void> completePersonalOnboarding() async {
    if (currentUid == null) return;
    await _db.collection('users').doc(currentUid!).set({
      'personalOnboardingCompleted': true,
      'onboardingCompleted': true, // Legacy compat
    }, SetOptions(merge: true));
  }

  static bool hasHealthData(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['age'] != null ||
           data['gender'] != null ||
           data['blood_group'] != null ||
           data['dob'] != null ||
           data['has_bp'] != null ||
           data['has_tb'] != null ||
           data['has_cancer'] != null;
  }

  static bool hasPersonalProfile(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['hasPersonalProfile'] == true ||
           data['personalOnboardingCompleted'] == true ||
           data['onboardingCompleted'] == true ||
           data['role'] == 'patient' ||
           hasHealthData(data);
  }

  static Future<bool> isNewUser() async {
    final uid = currentUid;
    if (uid == null) return true;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return true;
      if (data['role'] != null) return false;
      if (hasHealthData(data)) return false;
      final connections = await _db.collection('connections')
          .where('caregiverUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (connections.docs.isNotEmpty) return false;
      return true;
    } catch (e) {
      debugPrint("isNewUser error: $e");
      return true;
    }
  }

  static Future<List<Map<String, dynamic>>> getCaregiverConnections() async {
    final uid = currentUid;
    if (uid == null) return [];
    try {
      final snap = await _db.collection('connections')
          .where('caregiverUid', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint("getCaregiverConnections error: $e");
      return [];
    }
  }

  /// Send a connection request to a patient using their Firebase Auth UID (CareSync ID)
  static Future<Map<String, dynamic>> sendCaregiverRequest({
    required String patientUid,
    String? patientNickname,
    String? relationship,
  }) async {
    final uid = currentUid;
    if (uid == null) {
      return {'success': false, 'message': 'You must be logged in.'};
    }

    final trimmedUid = patientUid.trim();
    if (trimmedUid.isEmpty) {
      return {'success': false, 'message': 'Please enter a CareSync ID.'};
    }

    if (trimmedUid == uid) {
      return {'success': false, 'message': 'You cannot connect to your own CareSync ID.'};
    }

    try {
      // 1. Check if already actively connected to this patient
      final existingActive = await _db
          .collection('connections')
          .where('caregiverUid', isEqualTo: uid)
          .where('patientUid', isEqualTo: trimmedUid)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingActive.docs.isNotEmpty) {
        return {'success': false, 'message': 'You are already connected to this patient.'};
      }

      // 2. Check if a request is already pending
      final existingPending = await _db
          .collection('connections')
          .where('caregiverUid', isEqualTo: uid)
          .where('patientUid', isEqualTo: trimmedUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingPending.docs.isNotEmpty) {
        return {'success': false, 'message': 'A connection request is already pending for this patient.'};
      }

      // 3. Obtain caregiver's own profile info to present to the patient
      final currentUser = FirebaseAuth.instance.currentUser;
      final caregiverEmail = currentUser?.email ?? '';
      String caregiverName = currentUser?.displayName ?? '';
      if (caregiverName.isEmpty) {
        try {
          final userDoc = await _db.collection('users').doc(uid).get();
          final uData = userDoc.data();
          if (uData != null) {
            caregiverName = uData['name'] ?? uData['fullName'] ?? '';
          }
        } catch (_) {}
      }
      if (caregiverName.isEmpty) caregiverName = 'Caregiver';

      // 4. Safe lookup for patient display name from backend or user's nickname
      String displayName = (patientNickname != null && patientNickname.trim().isNotEmpty)
          ? patientNickname.trim()
          : '';

      if (displayName.isEmpty) {
        try {
          final res = await http.get(
            Uri.parse("$baseUrl/auth/profile/$trimmedUid"),
          ).timeout(const Duration(seconds: 2));
          if (res.statusCode == 200) {
            final body = jsonDecode(res.body);
            if (body is Map<String, dynamic>) {
              displayName = body['name'] ?? body['fullName'] ?? '';
            }
          }
        } catch (_) {}
      }

      if (displayName.isEmpty) {
        displayName = 'Patient (${trimmedUid.length > 6 ? trimmedUid.substring(0, 6) : trimmedUid})';
      }

      final docId = '${uid}_$trimmedUid';
      final connectionData = {
        'caregiverUid': uid,
        'caregiverEmail': caregiverEmail,
        'caregiverName': caregiverName,
        'patientUid': trimmedUid,
        'patientName': displayName,
        'relationship': (relationship != null && relationship.trim().isNotEmpty)
            ? relationship.trim()
            : 'Family Caregiver',
        'status': 'pending',
        'type': 'caregiver_request',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _db.collection('connections').doc(docId).set(connectionData, SetOptions(merge: true));

      // In-app notification to the patient about new request
      sendInAppNotification(
        targetUid: trimmedUid,
        title: "🤝 Caregiver Connection Request",
        body: "$caregiverName sent a request to connect as ${relationship ?? 'Family Caregiver'}.",
        type: "caregiver",
        referenceId: "caregiver_req_$docId",
      );

      return {
        'success': true,
        'message': 'Connection request sent to $displayName. Awaiting their approval.',
        'id': docId,
      };
    } catch (e) {
      debugPrint("sendCaregiverRequest error: $e");
      return {'success': false, 'message': 'Failed to send connection request: $e'};
    }
  }

  /// Connect a patient using their Firebase Auth UID (CareSync ID) - creates a pending request
  static Future<Map<String, dynamic>> connectPatientByUid({
    required String patientUid,
    String? patientName,
    String? relationship,
  }) async {
    return sendCaregiverRequest(
      patientUid: patientUid,
      patientNickname: patientName,
      relationship: relationship,
    );
  }

  /// Patient accepts or rejects an incoming caregiver connection request
  static Future<bool> respondToConnectionRequest({
    required String connectionId,
    required bool accept,
  }) async {
    final uid = currentUid;
    if (uid == null || connectionId.isEmpty) return false;
    try {
      if (accept) {
        final doc = await _db.collection('connections').doc(connectionId).get();
        final cData = doc.data();

        await _db.collection('connections').doc(connectionId).update({
          'status': 'active',
          'acceptedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Notify caregiver that patient accepted
        if (cData != null) {
          final cUid = cData['caregiverUid'] as String?;
          final pName = cData['patientName'] ?? 'Patient';
          if (cUid != null && cUid.isNotEmpty) {
            sendInAppNotification(
              targetUid: cUid,
              title: "✅ Connection Accepted!",
              body: "$pName has approved your connection request.",
              type: "caregiver",
              referenceId: "caregiver_acc_$connectionId",
            );
          }
        }
      } else {
        await _db.collection('connections').doc(connectionId).delete();
      }
      return true;
    } catch (e) {
      debugPrint("respondToConnectionRequest error: $e");
      return false;
    }
  }

  /// Cancel a pending connection request sent by the caregiver
  static Future<bool> cancelConnectionRequest(String connectionId) async {
    return disconnectPatientConnection(connectionId);
  }

  /// Disconnect / remove patient connection
  static Future<bool> disconnectPatientConnection(String connectionId, {String? patientUid}) async {
    if (connectionId.isEmpty) return false;
    final uid = currentUid;
    try {
      await _db.collection('connections').doc(connectionId).delete();
      if (uid != null && patientUid != null && patientUid.isNotEmpty) {
        try {
          await _db.collection('connections').doc('${uid}_$patientUid').delete();
        } catch (_) {}
      }
      return true;
    } catch (e) {
      debugPrint("disconnectPatientConnection error: $e");
      return false;
    }
  }


  /// Calculates current age from a DOB (date string, DateTime, or Timestamp).
  /// Returns null if DOB is missing, invalid, or in the future.
  static int? calculateAge(dynamic dob) {
    if (dob == null) return null;

    DateTime? birthDate;
    if (dob is DateTime) {
      birthDate = dob;
    } else if (dob is Timestamp) {
      birthDate = dob.toDate();
    } else if (dob is num) {
      if (dob > 0 && dob < 130) return dob.toInt();
      return null;
    } else if (dob is String) {
      final trimmed = dob.trim();
      if (trimmed.isEmpty ||
          trimmed == '--' ||
          trimmed == 'Not Set' ||
          trimmed == 'Not specified' ||
          trimmed == 'Not provided') {
        return null;
      }

      // If already a raw age string like "25"
      final directAge = int.tryParse(trimmed);
      if (directAge != null &&
          directAge > 0 &&
          directAge < 130 &&
          !trimmed.contains('-') &&
          !trimmed.contains('/') &&
          !trimmed.contains('.')) {
        return directAge;
      }

      // Standard ISO-8601 / YYYY-MM-DD
      birthDate = DateTime.tryParse(trimmed);

      // Handle custom formats: DD-MM-YYYY, DD/MM/YYYY, YYYY/MM/DD
      if (birthDate == null) {
        final parts = trimmed.split(RegExp(r'[-/.]'));
        if (parts.length == 3) {
          int? y, m, d;
          if (parts[0].length == 4) {
            y = int.tryParse(parts[0]);
            m = int.tryParse(parts[1]);
            d = int.tryParse(parts[2]);
          } else if (parts[2].length == 4) {
            d = int.tryParse(parts[0]);
            m = int.tryParse(parts[1]);
            y = int.tryParse(parts[2]);
          }
          if (y != null && m != null && d != null && m >= 1 && m <= 12 && d >= 1 && d <= 31) {
            try {
              birthDate = DateTime(y, m, d);
            } catch (_) {}
          }
        }
      }
    }

    if (birthDate == null) return null;

    final now = DateTime.now();
    if (birthDate.isAfter(now)) return null;

    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }

    if (age < 0 || age > 130) return null;
    return age;
  }

  static Future<Map<String, dynamic>?> getProfile({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return null;
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data()!;
        data['name'] = data['name'] ?? data['fullName'] ?? "User";
        data['email'] = data['email'] ?? "No Email";
        
        final computedAge = calculateAge(data['dob'] ?? data['date_of_birth'] ?? data['age']);
        if (computedAge != null) {
          data['age'] = computedAge;
        }

        return data;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> updateProfile(Map<String, dynamic> data) async {
    if (currentUid == null) return false;
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUid!).set(data, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint("updateProfile error: $e");
      rethrow;
    }
  }

  static Future<void> registerDeviceToken() async {
    if (currentUid == null) return;
    try {
      String? token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final deviceInfo = DeviceInfoPlugin();
      String deviceId = "unknown";
      if (Platform.isAndroid) {
        deviceId = (await deviceInfo.androidInfo).id;
      } else if (Platform.isIOS) {
        deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "ios_unknown";
      }
      await _db.collection('users').doc(currentUid!).collection('devices').doc(deviceId).set({
        'token': token,
        'platform': Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> logout([BuildContext? context]) async {
    if (currentUid != null) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        String deviceId = "unknown";
        if (Platform.isAndroid) {
          deviceId = (await deviceInfo.androidInfo).id;
        } else if (Platform.isIOS) {
          deviceId = (await deviceInfo.iosInfo).identifierForVendor ?? "ios_unknown";
        }
        await _db.collection('users').doc(currentUid!).collection('devices').doc(deviceId).delete();
      } catch (e) {
        debugPrint("Logout Cleanup Warning: $e");
      }
    }
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    if (context != null && context.mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
    }
  }

  static Future<String?> getUserRole() async {
    if (currentUid == null) return null;
    try {
      final doc = await _db.collection('users').doc(currentUid!).get();
      final data = doc.data();
      if (data == null) return null;
      if (data['role'] != null) return data['role'] as String?;
      if (hasPersonalProfile(data)) {
        await updateProfile({'role': 'patient', 'hasPersonalProfile': true});
        return 'patient';
      }
      return null;
    } catch (_) { return null; }
  }

  // --- HEALTH LOGS ---

  static Future<bool> logSugar(int level, String date, String time) async {
    if (currentUid == null) return false;
    try {
      await _db.collection('users').doc(currentUid!).collection('sugar_logs').add({
        'sugar_level': level,
        'log_date': date,
        'log_time': time,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>> getSugarHistory({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return [];
    try {
      final snap = await _db.collection('users').doc(uid)
          .collection('sugar_logs').orderBy('timestamp', descending: true).limit(20).get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) { return []; }
  }

  static Future<bool> deleteSugarLog(String logId, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || logId.isEmpty) return false;
    try {
      await _db.collection('users').doc(uid).collection('sugar_logs').doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint("deleteSugarLog error: $e");
      return false;
    }
  }

  static Future<bool> logBP(int systolic, int diastolic, int pulse, String date, String time) async {
    if (currentUid == null) return false;
    try {
      await _db.collection('users').doc(currentUid!).collection('bp_logs').add({
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'log_date': date,
        'log_time': time,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) { return false; }
  }

  static Future<List<Map<String, dynamic>>> getBPHistory({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return [];
    try {
      final snap = await _db.collection('users').doc(uid)
          .collection('bp_logs').orderBy('timestamp', descending: true).limit(20).get();
      return snap.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) { return []; }
  }

  static Future<bool> deleteBPLog(String logId, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || logId.isEmpty) return false;
    try {
      await _db.collection('users').doc(uid).collection('bp_logs').doc(logId).delete();
      return true;
    } catch (e) {
      debugPrint("deleteBPLog error: $e");
      return false;
    }
  }

  // --- REAL-TIME STREAMS FOR CAREGIVER MONITORING ---

  static Stream<List<Map<String, dynamic>>> sugarHistoryStream(String patientUid) {
    return _db
        .collection('users')
        .doc(patientUid)
        .collection('sugar_logs')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              d['id'] = doc.id;
              return d;
            }).toList())
        .handleError((e) {
          debugPrint("sugarHistoryStream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  static Stream<List<Map<String, dynamic>>> bpHistoryStream(String patientUid) {
    return _db
        .collection('users')
        .doc(patientUid)
        .collection('bp_logs')
        .orderBy('timestamp', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              d['id'] = doc.id;
              return d;
            }).toList())
        .handleError((e) {
          debugPrint("bpHistoryStream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  static Stream<List<Map<String, dynamic>>> todayDoseLogsStream(String patientUid) {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    return _db
        .collection('users')
        .doc(patientUid)
        .collection('medicine_logs')
        .where('log_date', isEqualTo: today)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              d['id'] = doc.id;
              return d;
            }).toList())
        .handleError((e) {
          debugPrint("todayDoseLogsStream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  static Stream<List<Map<String, dynamic>>> medicinesStream(String patientUid) {
    return _db
        .collection('users')
        .doc(patientUid)
        .collection('medicines')
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final d = Map<String, dynamic>.from(doc.data());
              if (!d.containsKey('medicine_name') || d['medicine_name'] == null) {
                d['medicine_name'] = doc.id;
              }
              d['id'] = doc.id;
              return d;
            }).toList())
        .handleError((e) {
          debugPrint("medicinesStream error: $e");
          return <Map<String, dynamic>>[];
        });
  }

  static Future<String?> addAppointment(Map<String, dynamic> appt, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return null;
    try {
      final docRef = await _db.collection('users').doc(uid).collection('appointments').add({
        ...appt,
        'status': appt['status'] ?? 'Upcoming',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      debugPrint("addAppointment error: $e");
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAppointments({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return [];
    try {
      final snap = await _db.collection('users').doc(uid)
          .collection('appointments').orderBy('dateTime', descending: false).get();
      return snap.docs.map((doc) {
        var data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        if (data['dateTime'] is Timestamp) {
          data['dateTime'] = (data['dateTime'] as Timestamp).toDate();
        } else if (data['dateTime'] is String) {
          data['dateTime'] = DateTime.tryParse(data['dateTime'] as String) ?? DateTime.now();
        }
        return data;
      }).toList();
    } catch (e) {
      debugPrint("getAppointments error: $e");
      return [];
    }
  }

  static Future<bool> updateAppointmentStatus({
    required String appointmentId,
    required String status,
    String? cancellationReason,
    DateTime? newDateTime,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || appointmentId.isEmpty) return false;
    try {
      final Map<String, dynamic> updates = {
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (status == 'Cancelled' && cancellationReason != null) {
        updates['cancellationReason'] = cancellationReason;
      }
      if (status == 'Completed') {
        updates['completedAt'] = FieldValue.serverTimestamp();
      }
      if (newDateTime != null) {
        updates['dateTime'] = Timestamp.fromDate(newDateTime);
      }
      await _db.collection('users').doc(uid).collection('appointments').doc(appointmentId).update(updates);
      return true;
    } catch (e) {
      debugPrint("updateAppointmentStatus error: $e");
      return false;
    }
  }

  static Future<bool> saveAppointmentFeedback({
    required String appointmentId,
    required Map<String, dynamic> feedback,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || appointmentId.isEmpty) return false;
    try {
      await _db.collection('users').doc(uid).collection('appointments').doc(appointmentId).update({
        'status': 'Completed',
        'completedAt': FieldValue.serverTimestamp(),
        'feedback': feedback,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      debugPrint("saveAppointmentFeedback error: $e");
      return false;
    }
  }

  static Future<bool> rescheduleAppointment({
    required String appointmentId,
    required DateTime newDateTime,
    String? targetUid,
  }) async {
    return updateAppointmentStatus(
      appointmentId: appointmentId,
      status: 'Rescheduled',
      newDateTime: newDateTime,
      targetUid: targetUid,
    );
  }

  static Future<bool> deleteAppointment(String id, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;
    try {
      await _db.collection('users').doc(uid).collection('appointments').doc(id).delete();
      return true;
    } catch (e) {
      debugPrint("deleteAppointment error: $e");
      return false;
    }
  }

  // --- IN-APP NOTIFICATIONS & FEED ---

  /// Realtime reactive stream of user notifications
  static Stream<List<AppNotification>> notificationsStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList())
        .handleError((e) {
          debugPrint("notificationsStream error: $e");
          return <AppNotification>[];
        });
  }

  /// Realtime unread notification count
  static Stream<int> unreadNotificationsCountStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length)
        .handleError((e) {
          debugPrint("unreadNotificationsCountStream error: $e");
          return 0;
        });
  }

  /// Send an in-app notification record to user's feed
  static Future<bool> sendInAppNotification({
    required String targetUid,
    required String title,
    required String body,
    required String type,
    String? referenceId,
    Map<String, dynamic>? payload,
  }) async {
    if (targetUid.isEmpty) return false;
    try {
      // Prevent rapid duplicates for same type & reference within 5 minutes
      if (referenceId != null && referenceId.isNotEmpty) {
        final fiveMinsAgo = DateTime.now().subtract(const Duration(minutes: 5));
        final existing = await _db
            .collection('users')
            .doc(targetUid)
            .collection('notifications')
            .where('referenceId', isEqualTo: referenceId)
            .where('createdAt', isGreaterThan: Timestamp.fromDate(fiveMinsAgo))
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          return true; // Already recorded recently
        }
      }

      await _db.collection('users').doc(targetUid).collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'referenceId': referenceId,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'payload': payload,
      });
      return true;
    } catch (e) {
      debugPrint("sendInAppNotification error: $e");
      return false;
    }
  }

  /// Mark specific notification as read
  static Future<bool> markNotificationAsRead(String notificationId, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || notificationId.isEmpty) return false;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      debugPrint("markNotificationAsRead error: $e");
      return false;
    }
  }

  /// Mark all notifications as read
  static Future<bool> markAllNotificationsAsRead({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;
    try {
      final unreadDocs = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (var doc in unreadDocs.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("markAllNotificationsAsRead error: $e");
      return false;
    }
  }

  /// Delete a notification
  static Future<bool> deleteNotification(String notificationId, {String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || notificationId.isEmpty) return false;
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();
      return true;
    } catch (e) {
      debugPrint("deleteNotification error: $e");
      return false;
    }
  }
}
