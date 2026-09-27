import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/medicine.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'api_service.dart';

class MedicineService {
  static const String baseUrl = "http://10.0.2.2:5000/medicines";

  static String? get currentUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// 🔥 CANONICAL INVENTORY: Fetch all medicines for user (Firestore master with local backup)
  static Future<List<Medicine>> getInventory({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return [];

    // 1. Primary Canonical Source: Cloud Firestore
    try {
      final snapshot = await FirebaseService.getMedicinesForUser(uid);
      if (snapshot.isNotEmpty) {
        final meds = snapshot.map((item) => Medicine.fromJson(item)).toList();
        return meds;
      }
    } catch (e) {
      debugPrint("Firestore getInventory error: $e");
    }

    // 2. Fallback / Sync from local backend if Firestore is empty or unreachable
    try {
      final response = await http
          .get(Uri.parse("$baseUrl/list/$uid"))
          .timeout(const Duration(milliseconds: 1500));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final meds = data.map((item) => Medicine.fromJson(item)).toList();
        if (meds.isNotEmpty) {
          // Sync to Firestore so cloud immediately stays populated
          for (var med in meds) {
            FirebaseService.saveMedicineToFirestore(med, med.timings ?? [], targetUid: uid);
          }
          return meds;
        }
      }
    } catch (_) {}

    return [];
  }

  /// 🔥 CANONICAL SCHEDULE: Derived directly from the same inventory records + today's logs
  static Future<List<Map<String, dynamic>>> getTodaySchedule({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return [];

    try {
      // 1. Fetch the exact same canonical inventory
      final inventory = await getInventory(targetUid: uid);
      if (inventory.isEmpty) return [];

      // 2. Fetch today's dose logs to check taken status
      final todayLogs = await FirebaseService.getTodayDoseLogsFromFirestore(targetUid: uid);
      final Set<String> takenKeys = {};
      for (var log in todayLogs) {
        final mName = (log['medicine_name'] as String? ?? '').toLowerCase();
        final rTime = log['reminder_time'] as String? ?? '';
        takenKeys.add('${mName}_$rTime');
      }

      // 3. Build unified schedule from canonical medicines
      final List<Map<String, dynamic>> schedule = [];
      for (var med in inventory) {
        final medName = med.name;
        final dosage = med.dosage;
        final timesList = med.timings != null && med.timings!.isNotEmpty ? med.timings! : ['08:00'];

        for (var t in timesList) {
          if (t.trim().isNotEmpty) {
            final cleanTime = t.trim();
            final isTaken = takenKeys.contains('${medName.toLowerCase()}_$cleanTime');

            String notifTime = cleanTime;
            try {
              final parts = cleanTime.split(':');
              final hour = int.parse(parts[0]);
              final minute = int.parse(parts[1]);
              final dt = DateTime(2026, 1, 1, hour, minute).subtract(const Duration(minutes: 15));
              notifTime = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } catch (_) {}

            schedule.add({
              'reminder_id': '${medName}_$cleanTime',
              'medicine_name': medName,
              'dosage': dosage,
              'reminder_time': cleanTime,
              'notification_time': notifTime,
              'is_taken': isTaken,
              'current_stock': med.totalStock,
              'stock_threshold': med.stockThreshold,
            });
          }
        }
      }

      schedule.sort((a, b) => (a['reminder_time'] as String).compareTo(b['reminder_time'] as String));
      return schedule;
    } catch (e) {
      debugPrint("getTodaySchedule error: $e");
      return [];
    }
  }

  /// 🔥 CANONICAL ADD: Writes to Firestore master record and mirrors to local backend
  static Future<bool> addMedicine({
    required String name,
    required String dosage,
    required List<String> times,
    required int stock,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    final med = Medicine(
      name: name,
      dosage: dosage,
      totalStock: stock,
      timings: times,
    );

    // 1. Primary Write: Cloud Firestore
    try {
      await FirebaseService.saveMedicineToFirestore(med, times, targetUid: uid);
    } catch (e) {
      debugPrint("Firestore addMedicine error: $e");
    }

    // 2. Local backend mirror (if reachable)
    try {
      await http.post(
        Uri.parse("$baseUrl/add"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_uid": uid,
          "medicine_name": name,
          "dosage": dosage,
          "times": times,
          "stock": stock,
        }),
      ).timeout(const Duration(milliseconds: 1500));
    } catch (_) {}

    // 3. Schedule local notification alarms
    for (var t in times) {
      NotificationService.scheduleMedicineReminder(
        id: '${name}_$t',
        title: 'Medicine Reminder: $name',
        body: 'Time to take your scheduled dose of $name ($t)',
        time: t,
      );
    }

    return true;
  }

  /// 🔥 CANONICAL UPDATE: Updates medicine details in Firestore, resets notifications, mirrors to backend
  static Future<bool> updateMedicine({
    int? medicineId,
    required String oldName,
    required String newName,
    required String dosage,
    required List<String> newTimes,
    List<String>? oldTimes,
    required int stock,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    // 1. Cancel previous notifications
    if (oldTimes != null) {
      for (var t in oldTimes) {
        NotificationService.cancelMedicineReminders('${oldName}_$t');
      }
    } else {
      NotificationService.cancelMedicineReminders(oldName);
    }

    final med = Medicine(
      id: medicineId,
      name: newName,
      dosage: dosage,
      totalStock: stock,
      timings: newTimes,
    );

    // 2. Primary Write: Cloud Firestore
    try {
      if (oldName.toLowerCase() != newName.toLowerCase()) {
        await FirebaseService.deleteMedicineFromFirestore(oldName, targetUid: uid);
      }
      await FirebaseService.saveMedicineToFirestore(med, newTimes, targetUid: uid);
    } catch (e) {
      debugPrint("Firestore updateMedicine error: $e");
    }

    // 3. Schedule new notifications
    for (var t in newTimes) {
      NotificationService.scheduleMedicineReminder(
        id: '${newName}_$t',
        title: 'Medicine Reminder: $newName',
        body: 'Time to take your scheduled dose of $newName ($t)',
        time: t,
      );
    }

    // 4. Local backend mirror (if reachable)
    if (medicineId != null) {
      try {
        await http.put(
          Uri.parse("$baseUrl/update/$medicineId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "medicine_name": newName,
            "dosage": dosage,
            "times": newTimes,
            "stock": stock,
          }),
        ).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return true;
  }

  /// 🔥 CANONICAL TAKE DOSE: Logs dose taken in Firestore & decrements inventory stock
  static Future<bool> takeDose(dynamic reminderId, {String? medicineName, int? currentStock, String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    String? medName = medicineName;
    String? rTime;

    if (reminderId is String && reminderId.contains('_')) {
      final parts = reminderId.split('_');
      if (medName == null || medName.isEmpty) {
        medName = parts[0];
      }
      rTime = parts.sublist(1).join('_');
    }

    // 1. Update Firestore Dose Log & Stock
    if (medName != null) {
      try {
        await FirebaseService.logDoseTakenToFirestore(
          medicineName: medName,
          reminderTime: rTime ?? '08:00',
          targetUid: uid,
        );

        final currentMeds = await getInventory(targetUid: uid);
        final match = currentMeds.firstWhere(
          (m) => m.name.toLowerCase() == medName!.toLowerCase(),
          orElse: () => Medicine(name: medName!, dosage: '', totalStock: currentStock ?? 20),
        );

        final newStock = (match.totalStock - 1).clamp(0, 99999);
        await FirebaseService.saveMedicineToFirestore(
          Medicine(
            name: match.name,
            dosage: match.dosage,
            totalStock: newStock,
            stockThreshold: match.stockThreshold,
            timings: match.timings,
          ),
          match.timings ?? [],
          targetUid: uid,
        );

        // Trigger immediate low stock notification if at or below threshold
        if (newStock <= match.stockThreshold) {
          NotificationService.showImmediateNotification(
            title: "Low Stock Alert: ${match.name}",
            body: "Only $newStock unit${newStock == 1 ? '' : 's'} remaining (Threshold: ${match.stockThreshold}). Tap to refill.",
            type: "medication",
            customId: NotificationService.calculateNotificationId('low_stock_${match.name}'),
          );
          ApiService.sendInAppNotification(
            targetUid: uid,
            title: "Low Stock Alert: ${match.name}",
            body: "Only $newStock unit${newStock == 1 ? '' : 's'} remaining (Threshold: ${match.stockThreshold}). Tap to refill.",
            type: "medication",
            referenceId: "stock_${match.name}",
          );
        }
      } catch (e) {
        debugPrint("takeDose Firestore error: $e");
      }
    }

    // 2. Local Backend Mirror (if applicable)
    if (reminderId is int) {
      try {
        await http.post(Uri.parse("$baseUrl/take/$reminderId")).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return true;
  }

  /// 🔥 CANONICAL UNDO DOSE: Reverses dose taken log in Firestore & increments inventory stock by 1
  static Future<bool> undoDose(
    dynamic reminderId, {
    String? medicineName,
    String? reminderTime,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    String? medName = medicineName;
    String? rTime = reminderTime;

    if (reminderId is String && reminderId.contains('_')) {
      final parts = reminderId.split('_');
      if (medName == null || medName.isEmpty) {
        medName = parts[0];
      }
      if (rTime == null || rTime.isEmpty) {
        rTime = parts.sublist(1).join('_');
      }
    }

    if (medName != null) {
      try {
        final cleanTime = rTime ?? '08:00';

        // 1. Duplicate Undo Protection: verify that dose is actually recorded as taken today
        final todayLogs = await FirebaseService.getTodayDoseLogsFromFirestore(targetUid: uid);
        final isRecordedTaken = todayLogs.any((log) {
          final lName = (log['medicine_name'] as String? ?? '').toLowerCase();
          final lTime = log['reminder_time'] as String? ?? '';
          return lName == medName!.toLowerCase() && lTime == cleanTime && log['status'] == 'taken';
        });

        if (!isRecordedTaken) {
          // Already undone or not logged as taken today; avoid duplicate stock restoration
          return true;
        }

        // 2. Delete dose log from Firestore
        await FirebaseService.deleteDoseLogFromFirestore(
          medicineName: medName,
          reminderTime: cleanTime,
          targetUid: uid,
        );

        // 3. Restore medicine stock (+1)
        final currentMeds = await getInventory(targetUid: uid);
        final match = currentMeds.firstWhere(
          (m) => m.name.toLowerCase() == medName!.toLowerCase(),
          orElse: () => Medicine(name: medName!, dosage: '', totalStock: 20),
        );

        final newStock = (match.totalStock + 1).clamp(0, 99999);
        await FirebaseService.saveMedicineToFirestore(
          Medicine(
            name: match.name,
            dosage: match.dosage,
            totalStock: newStock,
            stockThreshold: match.stockThreshold,
            timings: match.timings,
          ),
          match.timings ?? [],
          targetUid: uid,
        );
      } catch (e) {
        debugPrint("undoDose Firestore error: $e");
        return false;
      }
    }

    return true;
  }

  /// 🔥 CANONICAL DEDUCT STOCK: Manually decrements inventory stock without creating dose log or changing adherence
  static Future<bool> deductStock({
    int? medicineId,
    required String medicineName,
    required int currentStock,
    required int amount,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null || amount <= 0) return false;

    // 1. Update Firestore Master Record
    try {
      final currentMeds = await getInventory(targetUid: uid);
      final match = currentMeds.firstWhere(
        (m) => m.name.toLowerCase() == medicineName.toLowerCase(),
        orElse: () => Medicine(name: medicineName, dosage: '', totalStock: currentStock),
      );

      final newStock = (match.totalStock - amount).clamp(0, 99999);
      final timings = match.timings ?? [];

      await FirebaseService.saveMedicineToFirestore(
        Medicine(
          name: match.name,
          dosage: match.dosage,
          totalStock: newStock,
          stockThreshold: match.stockThreshold,
          timings: timings,
        ),
        timings,
        targetUid: uid,
      );

      // Re-ensure local notifications for this medicine remain registered
      for (var t in timings) {
        NotificationService.scheduleMedicineReminder(
          id: '${match.name}_$t',
          title: 'Medicine Reminder: ${match.name}',
          body: 'Time to take your scheduled dose of ${match.name} ($t)',
          time: t,
        );
      }

      // Trigger immediate low stock notification if at or below threshold
      if (newStock <= match.stockThreshold) {
        NotificationService.showImmediateNotification(
          title: "Low Stock Alert: ${match.name}",
          body: "Only $newStock unit${newStock == 1 ? '' : 's'} remaining (Threshold: ${match.stockThreshold}). Tap to refill.",
          type: "medication",
          customId: NotificationService.calculateNotificationId('low_stock_${match.name}'),
        );
        ApiService.sendInAppNotification(
          targetUid: uid,
          title: "Low Stock Alert: ${match.name}",
          body: "Only $newStock unit${newStock == 1 ? '' : 's'} remaining (Threshold: ${match.stockThreshold}). Tap to refill.",
          type: "medication",
          referenceId: "stock_${match.name}",
        );
      }
    } catch (e) {
      debugPrint("deductStock Firestore error: $e");
      return false;
    }

    // 2. Local backend mirror (if reachable)
    if (medicineId != null) {
      try {
        await http.post(
          Uri.parse("$baseUrl/refill/$medicineId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"amount": -amount}),
        ).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return true;
  }

  /// 🔥 CANONICAL REFILL: Increments stock in Firestore master record
  static Future<bool> refillStock({
    int? medicineId,
    required String medicineName,
    required int currentStock,
    int amount = 10,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    // 1. Update Firestore Master Record
    try {
      final currentMeds = await getInventory(targetUid: uid);
      final match = currentMeds.firstWhere(
        (m) => m.name.toLowerCase() == medicineName.toLowerCase(),
        orElse: () => Medicine(name: medicineName, dosage: '', totalStock: currentStock),
      );

      final newStock = match.totalStock + amount;
      final timings = match.timings ?? [];

      await FirebaseService.saveMedicineToFirestore(
        Medicine(
          name: match.name,
          dosage: match.dosage,
          totalStock: newStock,
          stockThreshold: match.stockThreshold,
          timings: timings,
        ),
        timings,
        targetUid: uid,
      );

      // Re-ensure local notifications for this medicine remain registered
      for (var t in timings) {
        NotificationService.scheduleMedicineReminder(
          id: '${match.name}_$t',
          title: 'Medicine Reminder: ${match.name}',
          body: 'Time to take your scheduled dose of ${match.name} ($t)',
          time: t,
        );
      }
    } catch (e) {
      debugPrint("refillStock Firestore error: $e");
      return false;
    }

    // 2. Local backend mirror
    if (medicineId != null) {
      try {
        await http.post(
          Uri.parse("$baseUrl/refill/$medicineId"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({"amount": amount}),
        ).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return true;
  }

  /// 🔥 CANONICAL DELETE: Removes medicine from Firestore master record & cancels local reminders
  static Future<bool> deleteMedicine({
    int? medicineId,
    required String medicineName,
    List<String>? timings,
    String? targetUid,
  }) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return false;

    // 1. Cancel local notifications for all scheduled times
    if (timings != null) {
      for (var t in timings) {
        NotificationService.cancelMedicineReminders('${medicineName}_$t');
      }
    }

    // 2. Delete from Firestore Master Record
    try {
      await FirebaseService.deleteMedicineFromFirestore(medicineName, targetUid: uid);
    } catch (e) {
      debugPrint("deleteMedicine Firestore error: $e");
      return false;
    }

    // 3. Local backend mirror
    if (medicineId != null) {
      try {
        await http.delete(Uri.parse("$baseUrl/delete/$medicineId")).timeout(const Duration(milliseconds: 1500));
      } catch (_) {}
    }

    return true;
  }

  /// 🔥 CANONICAL STATS: Real adherence from Firestore logs and inventory
  static Future<Map<String, dynamic>> getRealStats({String? targetUid}) async {
    final uid = targetUid ?? currentUid;
    if (uid == null) return {"adherence_rate": 0, "total_logs": 0};

    try {
      final allLogs = await FirebaseService.getAllDoseLogsFromFirestore(targetUid: uid);
      final inventory = await getInventory(targetUid: uid);

      final totalLogs = allLogs.length;
      int adherence = 0;
      if (totalLogs > 0) {
        final takenCount = allLogs.where((l) => l['status'] == 'taken').length;
        adherence = ((takenCount / totalLogs) * 100).round().clamp(0, 100);
      } else if (inventory.isNotEmpty) {
        adherence = 100;
      }

      return {
        "adherence_rate": adherence,
        "total_logs": totalLogs,
      };
    } catch (_) {
      return {"adherence_rate": 0, "total_logs": 0};
    }
  }
}
