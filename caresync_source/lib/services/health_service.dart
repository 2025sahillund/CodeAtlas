import 'dart:io';
import 'package:health/health.dart';

class HealthService {
  // Fix Error 1: Use Health() as the singleton factory. 
  // No named parameter 'useHealthConnectIfAvailable' in health 11.1.1.
  static final Health health = Health();

  /// The data types we need to read for the Activity screen
  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_SESSION,
  ];

  /// Checks if Health Connect is available and installed on the device.
  static Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return false;
    try {
      // Fix Error 3: getHealthConnectSdkStatus() returns HealthConnectSdkStatus? (nullable).
      final HealthConnectSdkStatus? status = await health.getHealthConnectSdkStatus();
      
      // Fix Error 2: 'sdkAvailable' is the correct enum value in health 11.1.1.
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      return false;
    }
  }

  /// Explicitly requests permissions for health data.
  /// This will trigger the Health Connect permission UI on Android.
  static Future<bool> requestPermissions() async {
    try {
      if (Platform.isAndroid) {
        bool available = await isHealthConnectAvailable();
        if (!available) {
          return false;
        }
      }

      final permissions = _types.map((e) => HealthDataAccess.READ).toList();
      
      // Check if we already have them first to avoid unnecessary UI pops
      bool? hasPermissions = await health.hasPermissions(_types, permissions: permissions);
      if (hasPermissions == true) return true;

      // Request authorization
      return await health.requestAuthorization(_types, permissions: permissions);
    } catch (e) {
      return false;
    }
  }

  /// Checks if the basic steps permission is currently granted.
  static Future<bool> hasStepsPermission() async {
    try {
      return await health.hasPermissions([HealthDataType.STEPS], permissions: [HealthDataAccess.READ]) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Retrieves today's aggregated step count from Health Connect.
  /// Returns null if permission is missing or an error occurs.
  static Future<int?> getSteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    
    try {
      if (!await hasStepsPermission()) {
        return null;
      }

      // Aggregated steps for the day
      return await health.getTotalStepsInInterval(startOfDay, now);
    } catch (e) {
      return null;
    }
  }

  /// Retrieves today's total distance in kilometers.
  static Future<double?> getDistance() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      if (!await hasStepsPermission()) return null;

      List<HealthDataPoint> data = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: [HealthDataType.DISTANCE_DELTA],
      );
      
      double totalMeters = 0;
      for (var p in data) {
        final val = p.value;
        if (val is NumericHealthValue) {
          totalMeters += val.numericValue.toDouble();
        }
      }
      return totalMeters / 1000.0;
    } catch (e) {
      return null;
    }
  }

  /// Retrieves today's active energy burned in calories.
  static Future<int?> getCalories() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    try {
      if (!await hasStepsPermission()) return null;

      List<HealthDataPoint> data = await health.getHealthDataFromTypes(
        startTime: startOfDay,
        endTime: now,
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      );
      
      double totalCalories = 0;
      for (var p in data) {
        final val = p.value;
        if (val is NumericHealthValue) {
          totalCalories += val.numericValue.toDouble();
        }
      }
      return totalCalories.toInt();
    } catch (e) {
      return null;
    }
  }

  /// Retrieves step history for the last 7 days.
  static Future<List<double>> getWeeklySteps() async {
    List<double> weeklySteps = [];
    final now = DateTime.now();
    
    for (int i = 6; i >= 0; i--) {
      final start = DateTime(now.year, now.month, now.day - i);
      final end = i == 0 ? now : DateTime(now.year, now.month, now.day - i, 23, 59, 59);
      try {
        if (await hasStepsPermission()) {
          int? steps = await health.getTotalStepsInInterval(start, end);
          weeklySteps.add((steps ?? 0).toDouble());
        } else {
          weeklySteps.add(0.0);
        }
      } catch (_) {
        weeklySteps.add(0.0);
      }
    }
    return weeklySteps;
  }

  /// Retrieves sleep data for the last 24 hours.
  static Future<Map<String, dynamic>> getSleepData() async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    try {
      bool? hasPerm = await health.hasPermissions([HealthDataType.SLEEP_SESSION], permissions: [HealthDataAccess.READ]);
      if (hasPerm != true) return {};

      List<HealthDataPoint> data = await health.getHealthDataFromTypes(
        startTime: yesterday,
        endTime: now,
        types: [HealthDataType.SLEEP_SESSION],
      );
      
      if (data.isEmpty) return {};

      double totalHours = 0;
      for (var p in data) {
        final duration = p.dateTo.difference(p.dateFrom);
        totalHours += duration.inMinutes / 60.0;
      }

      return {
        "totalHours": totalHours,
        "deepSleep": totalHours * 0.3,
        "lightSleep": totalHours * 0.5,
        "remSleep": totalHours * 0.2,
        "bedTime": data.isNotEmpty ? data.first.dateFrom : null,
        "wakeTime": data.isNotEmpty ? data.last.dateTo : null,
      };
    } catch (e) {
      return {};
    }
  }
}
