import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'api_service.dart';

// Top-level background handler for FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Handling background FCM message: ${message.messageId}");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String medicationChannelId = 'medicine_reminders_high_v2';
  static const String appointmentChannelId = 'appointment_reminders_v2';
  static const String caregiverChannelId = 'caregiver_alerts_v2';
  static const String emergencyChannelId = 'emergency_sos_high_v2';

  static Future<void> init() async {
    tz.initializeTimeZones();
    try {
      final offset = DateTime.now().timeZoneOffset;
      for (var loc in tz.timeZoneDatabase.locations.values) {
        if (loc.currentTimeZone.offset == offset.inMilliseconds) {
          tz.setLocalLocation(loc);
          break;
        }
      }
    } catch (_) {}

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        debugPrint("Notification tapped with payload: ${details.payload}");
      },
    );

    await _createNotificationChannels();
    await requestPermissions();

    // Initialize Firebase Cloud Messaging safely
    _initFirebaseMessaging();

    // Register token with Firestore
    ApiService.registerDeviceToken();
  }

  static Future<void> _createNotificationChannels() async {
    if (!Platform.isAndroid) return;

    final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          medicationChannelId,
          'Medication Reminders',
          description: 'Timely reminders for scheduled doses and medication tracking',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          appointmentChannelId,
          'Appointment Reminders',
          description: 'Upcoming doctor visit alerts and post-visit follow-up prompts',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          caregiverChannelId,
          'Caregiver & Family Alerts',
          description: 'Connection invitations and patient health routine updates',
          importance: Importance.high,
          enableVibration: true,
          playSound: true,
        ),
      );

      await androidImplementation.createNotificationChannel(
        const AndroidNotificationChannel(
          emergencyChannelId,
          'Emergency SOS Alerts',
          description: 'Critical emergency notifications and SOS broadcasts',
          importance: Importance.max,
          enableVibration: true,
          playSound: true,
        ),
      );
    }
  }

  static Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidImplementation = _notificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        final bool? areEnabled = await androidImplementation.areNotificationsEnabled();
        if (areEnabled != true) {
          await androidImplementation.requestNotificationsPermission();
        }
        try {
          await androidImplementation.requestExactAlarmsPermission();
        } catch (_) {}
      }
    }
  }

  static Future<void> _initFirebaseMessaging() async {
    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          final String title = notification.title ?? "CareSync Alert";
          final String body = notification.body ?? "You have a new health update";
          final String type = message.data['type'] ?? 'general';

          showImmediateNotification(
            title: title,
            body: body,
            type: type,
          );

          // If logged in, also record into in-app notification feed
          final uid = ApiService.currentUid;
          if (uid != null) {
            ApiService.sendInAppNotification(
              targetUid: uid,
              title: title,
              body: body,
              type: type,
              payload: message.data,
            );
          }
        }
      });

      // Handle token refreshes
      messaging.onTokenRefresh.listen((newToken) {
        ApiService.registerDeviceToken();
      });

      // Fetch initial token for debugging
      String? token = await messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (kDebugMode && token != null) {
        debugPrint("PRO FCM TOKEN: $token");
      }
    } catch (e) {
      debugPrint("FCM Initialization Warning: $e");
    }
  }

  /// Calculates a stable positive 32-bit integer ID from any string/int
  static int calculateNotificationId(dynamic input, [int salt = 0]) {
    if (input is int) {
      return ((input + salt).abs()) % 2147483647;
    }
    final str = input.toString();
    return ((str.hashCode + salt).abs()) % 2147483647;
  }

  /// Display an immediate local notification (e.g. for FCM foreground or SOS test)
  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String type = 'general',
    int? customId,
  }) async {
    String channelId = medicationChannelId;
    Importance importance = Importance.high;

    if (type == 'emergency' || type == 'sos') {
      channelId = emergencyChannelId;
      importance = Importance.max;
    } else if (type == 'appointment') {
      channelId = appointmentChannelId;
    } else if (type == 'caregiver') {
      channelId = caregiverChannelId;
    }

    final NotificationDetails notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        _getChannelName(channelId),
        importance: importance,
        priority: Priority.high,
        fullScreenIntent: importance == Importance.max,
      ),
    );

    final int notifId = customId ?? calculateNotificationId('$title$body${DateTime.now().minute}');
    await _notificationsPlugin.show(notifId, title, body, notificationDetails);
  }

  /// Schedule medicine reminder for both 15 mins before and exact due time
  static Future<void> scheduleMedicineReminder({
    required dynamic id,
    required String title,
    required String body,
    required String time,
  }) async {
    try {
      final now = DateTime.now();
      final timeParts = time.split(':');
      if (timeParts.length < 2) return;

      final hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);

      // 1. Advance reminder (15 mins prior)
      var advanceDate = DateTime(now.year, now.month, now.day, hour, minute)
          .subtract(const Duration(minutes: 15));
      if (advanceDate.isBefore(now)) {
        advanceDate = advanceDate.add(const Duration(days: 1));
      }

      final int advanceId = calculateNotificationId(id, 1000);
      await _notificationsPlugin.zonedSchedule(
        advanceId,
        title,
        "Upcoming in 15 mins: $body",
        tz.TZDateTime.from(advanceDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            medicationChannelId,
            'Medication Reminders',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );

      // 2. Exact dose time reminder
      var exactDate = DateTime(now.year, now.month, now.day, hour, minute);
      if (exactDate.isBefore(now)) {
        exactDate = exactDate.add(const Duration(days: 1));
      }

      final int exactId = calculateNotificationId(id, 2000);
      await _notificationsPlugin.zonedSchedule(
        exactId,
        "Time for your dose!",
        body,
        tz.TZDateTime.from(exactDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            medicationChannelId,
            'Medication Reminders',
            importance: Importance.max,
            priority: Priority.high,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (e) {
      debugPrint("scheduleMedicineReminder error: $e");
    }
  }

  /// Schedule generic one-shot reminder (e.g. appointment)
  static Future<void> scheduleGenericReminder({
    required dynamic id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String type = 'appointment',
  }) async {
    if (scheduledTime.isBefore(DateTime.now())) return;

    final String channelId = type == 'appointment' ? appointmentChannelId : caregiverChannelId;
    final int notifId = calculateNotificationId(id);

    try {
      await _notificationsPlugin.zonedSchedule(
        notifId,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _getChannelName(channelId),
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      debugPrint("scheduleGenericReminder error: $e");
    }
  }

  /// Cancel specific notification by dynamic ID
  static Future<void> cancelNotification(dynamic id, [int salt = 0]) async {
    try {
      final int notifId = calculateNotificationId(id, salt);
      await _notificationsPlugin.cancel(notifId);
    } catch (e) {
      debugPrint("cancelNotification error: $e");
    }
  }

  /// Cancel both advance and exact medicine reminders for a specific dose
  static Future<void> cancelMedicineReminders(dynamic medId) async {
    await cancelNotification(medId, 1000);
    await cancelNotification(medId, 2000);
  }

  static Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
    } catch (e) {
      debugPrint("cancelAllNotifications error: $e");
    }
  }

  static String _getChannelName(String channelId) {
    switch (channelId) {
      case medicationChannelId:
        return 'Medication Reminders';
      case appointmentChannelId:
        return 'Appointment Reminders';
      case caregiverChannelId:
        return 'Caregiver & Family Alerts';
      case emergencyChannelId:
        return 'Emergency SOS Alerts';
      default:
        return 'General Notifications';
    }
  }
}
