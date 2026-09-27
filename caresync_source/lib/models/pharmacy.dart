import 'package:flutter/foundation.dart';

/// Represents a parsed pharmacy facility from OpenStreetMap Overpass data.
class Pharmacy {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double distanceInMeters;
  final String distanceText;
  final String? address;
  final String? phone;
  final String? openingHoursRaw;

  // Computed fields
  final bool? isOpen;
  final bool is24Hours;
  final String statusText;
  final String? statusDetail;

  const Pharmacy({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceInMeters,
    required this.distanceText,
    this.address,
    this.phone,
    this.openingHoursRaw,
    this.isOpen,
    required this.is24Hours,
    required this.statusText,
    this.statusDetail,
  });

  /// Factory constructor to parse an OSM Overpass element (node, way, or relation)
  /// and evaluate opening status based on reference time.
  factory Pharmacy.fromOsmJson({
    required Map<String, dynamic> json,
    required double userLat,
    required double userLng,
    required double distanceInMeters,
    required String distanceText,
    DateTime? referenceTime,
  }) {
    final tags = (json['tags'] as Map<String, dynamic>?) ?? {};

    // 1. Resolve coordinates
    double lat = 0.0;
    double lng = 0.0;
    if (json['lat'] != null && json['lon'] != null) {
      lat = (json['lat'] as num).toDouble();
      lng = (json['lon'] as num).toDouble();
    } else if (json['center'] != null) {
      lat = (json['center']['lat'] as num?)?.toDouble() ?? 0.0;
      lng = (json['center']['lon'] as num?)?.toDouble() ?? 0.0;
    }

    // 2. Resolve Name
    String name = (tags['name'] ??
            tags['name:en'] ??
            tags['int_name'] ??
            tags['brand'] ??
            tags['official_name'] ??
            '')
        .toString()
        .trim();

    if (name.isEmpty) {
      name = "Pharmacy";
    }

    // 3. Resolve Address
    final String? address = _parseOsmAddress(tags);

    // 4. Resolve Phone
    final String? rawPhone = tags['phone']?.toString().trim() ??
        tags['contact:phone']?.toString().trim() ??
        tags['contact:mobile']?.toString().trim() ??
        tags['mobile']?.toString().trim();
    final String? phone = (rawPhone != null && rawPhone.isNotEmpty) ? rawPhone : null;

    // 5. Resolve Opening Hours
    final String? openingHoursRaw = tags['opening_hours']?.toString().trim();
    final OpeningHoursEvaluation evaluation = OpeningHoursParser.evaluate(
      openingHoursRaw,
      referenceTime: referenceTime ?? DateTime.now(),
    );

    return Pharmacy(
      id: json['id']?.toString() ?? UniqueKey().toString(),
      name: name,
      lat: lat,
      lng: lng,
      distanceInMeters: distanceInMeters,
      distanceText: distanceText,
      address: address,
      phone: phone,
      openingHoursRaw: openingHoursRaw,
      isOpen: evaluation.isOpen,
      is24Hours: evaluation.is24Hours,
      statusText: evaluation.statusText,
      statusDetail: evaluation.statusDetail,
    );
  }

  /// Sanitized phone number for direct tel: intent dialing
  String? get dialablePhone {
    if (phone == null || phone!.trim().isEmpty) return null;
    final sanitized = phone!.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.length < 3) return null;
    return sanitized;
  }

  static String? _parseOsmAddress(Map<String, dynamic> tags) {
    if (tags['addr:full'] != null && tags['addr:full'].toString().trim().isNotEmpty) {
      return tags['addr:full'].toString().trim();
    }

    final List<String> parts = [];
    final String house = tags['addr:housenumber']?.toString().trim() ?? '';
    final String street = tags['addr:street']?.toString().trim() ?? '';
    if (house.isNotEmpty || street.isNotEmpty) {
      parts.add("$house $street".trim());
    }

    final String suburb = tags['addr:suburb']?.toString().trim() ??
        tags['addr:neighbourhood']?.toString().trim() ??
        tags['addr:district']?.toString().trim() ??
        '';
    if (suburb.isNotEmpty) parts.add(suburb);

    final String city = tags['addr:city']?.toString().trim() ??
        tags['addr:town']?.toString().trim() ??
        tags['addr:village']?.toString().trim() ??
        '';
    if (city.isNotEmpty) parts.add(city);

    final String state = tags['addr:state']?.toString().trim() ?? '';
    if (state.isNotEmpty) parts.add(state);

    final String postcode = tags['addr:postcode']?.toString().trim() ?? '';
    if (postcode.isNotEmpty) parts.add(postcode);

    if (parts.isEmpty) return null;
    return parts.join(', ');
  }
}

/// Evaluation result of OSM opening hours
class OpeningHoursEvaluation {
  final bool? isOpen;
  final bool is24Hours;
  final String statusText;
  final String? statusDetail;

  const OpeningHoursEvaluation({
    required this.isOpen,
    required this.is24Hours,
    required this.statusText,
    this.statusDetail,
  });
}

/// Time interval in minutes from midnight (0 to 1440)
class TimeInterval {
  final int startMinutes;
  final int endMinutes;

  const TimeInterval(this.startMinutes, this.endMinutes);

  bool contains(int minute) {
    if (endMinutes >= startMinutes) {
      return minute >= startMinutes && minute < endMinutes;
    } else {
      // Overnight shift, e.g. 20:00 to 04:00 (1200 to 240)
      return minute >= startMinutes || minute < endMinutes;
    }
  }
}

/// Robust parser for standard OpenStreetMap opening_hours format.
class OpeningHoursParser {
  static const Map<String, int> _dayMap = {
    'mo': 1,
    'tu': 2,
    'we': 3,
    'th': 4,
    'fr': 5,
    'sa': 6,
    'su': 7,
  };

  /// Evaluates an OSM opening_hours string at the specified referenceTime.
  static OpeningHoursEvaluation evaluate(String? rawHours, {required DateTime referenceTime}) {
    if (rawHours == null || rawHours.trim().isEmpty) {
      return const OpeningHoursEvaluation(
        isOpen: null,
        is24Hours: false,
        statusText: "Hours unavailable",
        statusDetail: null,
      );
    }

    final normalized = rawHours.trim().toLowerCase();

    // 1. Strict 24/7 detection
    if (_isStrict24Hours(normalized)) {
      return const OpeningHoursEvaluation(
        isOpen: true,
        is24Hours: true,
        statusText: "Open 24 hours",
        statusDetail: null,
      );
    }

    // 2. Parse structured rules
    try {
      final schedule = _parseSchedule(normalized);
      if (schedule == null || schedule.isEmpty) {
        return const OpeningHoursEvaluation(
          isOpen: null,
          is24Hours: false,
          statusText: "Hours unavailable",
          statusDetail: null,
        );
      }

      final int currentWeekday = referenceTime.weekday; // 1 = Monday, 7 = Sunday
      final int currentMinute = referenceTime.hour * 60 + referenceTime.minute;

      final todayIntervals = schedule[currentWeekday];

      if (todayIntervals == null || todayIntervals.isEmpty) {
        // Today is closed/off
        return OpeningHoursEvaluation(
          isOpen: false,
          is24Hours: false,
          statusText: "Closed",
          statusDetail: _findNextOpenDetail(schedule, currentWeekday, currentMinute),
        );
      }

      // Check if open now
      for (final interval in todayIntervals) {
        if (interval.contains(currentMinute)) {
          final closeTimeStr = _formatMinutes(interval.endMinutes);
          return OpeningHoursEvaluation(
            isOpen: true,
            is24Hours: false,
            statusText: "Open now",
            statusDetail: "Closes at $closeTimeStr",
          );
        }
      }

      // If here, currently closed today. Find if opening later today or next scheduled day
      TimeInterval? nextToday;
      for (final interval in todayIntervals) {
        if (interval.startMinutes > currentMinute) {
          if (nextToday == null || interval.startMinutes < nextToday.startMinutes) {
            nextToday = interval;
          }
        }
      }

      if (nextToday != null) {
        final openTimeStr = _formatMinutes(nextToday.startMinutes);
        return OpeningHoursEvaluation(
          isOpen: false,
          is24Hours: false,
          statusText: "Closed",
          statusDetail: "Opens at $openTimeStr",
        );
      } else {
        return OpeningHoursEvaluation(
          isOpen: false,
          is24Hours: false,
          statusText: "Closed",
          statusDetail: _findNextOpenDetail(schedule, currentWeekday, currentMinute),
        );
      }
    } catch (_) {
      // If syntax is complex or fails parsing, never guess.
      return const OpeningHoursEvaluation(
        isOpen: null,
        is24Hours: false,
        statusText: "Hours unavailable",
        statusDetail: null,
      );
    }
  }

  /// Strictly determines if the opening hours represent 24/7 operation
  static bool _isStrict24Hours(String normalized) {
    if (normalized == '24/7') return true;
    if (normalized == '00:00-24:00' || normalized == '0:00-24:00') return true;
    if (normalized == 'mo-su 00:00-24:00' || normalized == 'mo-su 24/7') return true;
    if (normalized == 'mo-su,ph 00:00-24:00' || normalized == 'mo-su,ph 24/7') return true;
    if (normalized == 'mo-su 00:00-24:00; ph 00:00-24:00') return true;

    // Check if regex matches all days 00:00-24:00
    final allDaysPattern = RegExp(r'^(mo-su|daily|24/7|all)\s*(00:00-24:00|24/7)?$');
    if (allDaysPattern.hasMatch(normalized)) return true;

    return false;
  }

  /// Parses schedule into a map of weekday (1-7) -> List of TimeInterval
  static Map<int, List<TimeInterval>>? _parseSchedule(String raw) {
    final Map<int, List<TimeInterval>> schedule = {};
    for (int i = 1; i <= 7; i++) {
      schedule[i] = [];
    }

    // Split rule blocks by semicolon
    final rules = raw.split(';').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (rules.isEmpty) return null;

    bool anyRuleParsed = false;

    for (final rule in rules) {
      // Check if off/closed
      final bool isOff = rule.endsWith('off') || rule.endsWith('closed');

      // Separate day portion and time portion
      // e.g. "mo-fr 09:00-18:00", "sa 09:00-14:00", "09:00-22:00"
      final parts = rule.split(RegExp(r'\s+'));
      if (parts.isEmpty) continue;

      List<int> targetDays = [];
      String timePart = '';

      // Check if first part is day specifier
      if (_isDayToken(parts[0])) {
        targetDays = _parseDays(parts[0]);
        if (parts.length > 1) {
          timePart = parts.sublist(1).join(' ');
        }
      } else {
        // No explicit day -> applies to all days (Mo-Su)
        targetDays = [1, 2, 3, 4, 5, 6, 7];
        timePart = rule;
      }

      if (isOff) {
        // Explicitly clear intervals for these days
        for (final day in targetDays) {
          schedule[day] = [];
        }
        anyRuleParsed = true;
        continue;
      }

      if (timePart.isEmpty) continue;

      final intervals = _parseTimeIntervals(timePart);
      if (intervals.isNotEmpty) {
        anyRuleParsed = true;
        for (final day in targetDays) {
          schedule[day]!.addAll(intervals);
        }
      }
    }

    return anyRuleParsed ? schedule : null;
  }

  static bool _isDayToken(String token) {
    final clean = token.toLowerCase().replaceAll(RegExp(r'[^a-z,-]'), '');
    if (clean.isEmpty) return false;
    for (final key in _dayMap.keys) {
      if (clean.contains(key)) return true;
    }
    return false;
  }

  static List<int> _parseDays(String dayStr) {
    final Set<int> result = {};
    final tokens = dayStr.split(',');

    for (final token in tokens) {
      final t = token.trim();
      if (t.contains('-')) {
        final range = t.split('-');
        if (range.length == 2) {
          final start = _dayMap[range[0].trim()];
          final end = _dayMap[range[1].trim()];
          if (start != null && end != null) {
            if (start <= end) {
              for (int d = start; d <= end; d++) {
                result.add(d);
              }
            } else {
              // Wrap around e.g. Fr-Mo (5,6,7,1)
              for (int d = start; d <= 7; d++) {
                result.add(d);
              }
              for (int d = 1; d <= end; d++) {
                result.add(d);
              }
            }
          }
        }
      } else {
        final d = _dayMap[t];
        if (d != null) result.add(d);
      }
    }

    return result.toList();
  }

  static List<TimeInterval> _parseTimeIntervals(String timeStr) {
    final List<TimeInterval> intervals = [];
    // e.g. "09:00-13:00, 16:00-20:00"
    final pieces = timeStr.split(',');

    for (final piece in pieces) {
      final p = piece.trim();
      final match = RegExp(r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})$').firstMatch(p);
      if (match != null) {
        final startH = int.parse(match.group(1)!);
        final startM = int.parse(match.group(2)!);
        final endH = int.parse(match.group(3)!);
        final endM = int.parse(match.group(4)!);

        final startMinutes = startH * 60 + startM;
        final endMinutes = (endH == 24 && endM == 0) ? 1440 : endH * 60 + endM;

        intervals.add(TimeInterval(startMinutes, endMinutes));
      }
    }

    return intervals;
  }

  static String? _findNextOpenDetail(Map<int, List<TimeInterval>> schedule, int currentDay, int currentMinute) {
    // Check next 6 days
    final List<String> dayNames = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int offset = 1; offset <= 7; offset++) {
      int nextDay = ((currentDay - 1 + offset) % 7) + 1;
      final intervals = schedule[nextDay];
      if (intervals != null && intervals.isNotEmpty) {
        final earliest = intervals.reduce((a, b) => a.startMinutes < b.startMinutes ? a : b);
        final timeStr = _formatMinutes(earliest.startMinutes);
        if (offset == 1) {
          return "Opens tomorrow at $timeStr";
        } else {
          return "Opens ${dayNames[nextDay]} at $timeStr";
        }
      }
    }
    return null;
  }

  static String _formatMinutes(int minutes) {
    if (minutes >= 1440) return "12:00 AM";
    final int h24 = minutes ~/ 60;
    final int m = minutes % 60;
    final String minuteStr = m.toString().padLeft(2, '0');

    final String period = h24 >= 12 ? "PM" : "AM";
    int h12 = h24 % 12;
    if (h12 == 0) h12 = 12;

    return "$h12:$minuteStr $period";
  }
}
