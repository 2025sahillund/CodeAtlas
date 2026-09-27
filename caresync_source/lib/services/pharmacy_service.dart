import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/pharmacy.dart';

class PharmacyService {
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.openstreetmap.ru/cgi/interpreter',
  ];

  static const Map<String, String> _apiHeaders = {
    'Content-Type': 'application/x-www-form-urlencoded',
    'User-Agent': 'CareSync-PharmacyService/1.0 (https://caresync.app; contact@caresync.app)',
  };

  /// Queries real nearby pharmacies using OpenStreetMap Overpass API
  /// with automatic endpoint failover.
  ///
  /// Never generates synthetic fallback pharmacies.
  static Future<List<Pharmacy>> fetchNearbyPharmacies({
    required double latitude,
    required double longitude,
    double radiusInMeters = 5000,
    DateTime? referenceTime,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final bool isCustomClient = client != null;

    debugPrint("--------------------------------------------------");
    debugPrint("[CareSync PharmacyService] Querying Overpass");
    debugPrint("Target Coordinates: Lat $latitude, Lng $longitude");
    debugPrint("Search Radius: ${radiusInMeters.toInt()} meters");
    debugPrint("--------------------------------------------------");

    final query = '''
[out:json][timeout:15];
(
  node["amenity"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
  way["amenity"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
  relation["amenity"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
  node["healthcare"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
  way["healthcare"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
  relation["healthcare"="pharmacy"](around:${radiusInMeters.toInt()},$latitude,$longitude);
);
out center 60;
''';

    Exception? lastError;

    try {
      for (final endpoint in _overpassEndpoints) {
        try {
          final response = await httpClient
              .post(
                Uri.parse(endpoint),
                headers: _apiHeaders,
                body: {'data': query},
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final elements = data['elements'] as List<dynamic>? ?? [];
            final pharmacies = parseOverpassElements(
              elements,
              latitude,
              longitude,
              referenceTime: referenceTime,
            );
            return pharmacies;
          } else if (response.statusCode == 429 || response.statusCode >= 500) {
            debugPrint("Overpass mirror $endpoint busy/rate limited: ${response.statusCode}");
            lastError = Exception("Server error ${response.statusCode} on $endpoint");
            continue;
          } else {
            lastError = Exception("HTTP ${response.statusCode}");
          }
        } catch (e) {
          debugPrint("Overpass query attempt error on $endpoint: $e");
          lastError = (e is Exception) ? e : Exception(e.toString());
        }
      }
    } finally {
      if (!isCustomClient) {
        httpClient.close();
      }
    }

    // If all mirrors failed, throw error to let UI show real error state with retry
    throw lastError ?? Exception("Unable to reach OpenStreetMap Overpass servers");
  }

  /// Parses raw OSM JSON elements into Pharmacy instances,
  /// calculates exact distance, and removes duplicate nodes/ways.
  static List<Pharmacy> parseOverpassElements(
    List<dynamic> elements,
    double userLat,
    double userLng, {
    DateTime? referenceTime,
  }) {
    final List<Pharmacy> results = [];
    final Set<String> seenIdentifiers = {};

    for (final el in elements) {
      if (el is! Map<String, dynamic>) continue;

      // Extract coordinates
      double? lat;
      double? lng;

      if (el['lat'] != null && el['lon'] != null) {
        lat = (el['lat'] as num).toDouble();
        lng = (el['lon'] as num).toDouble();
      } else if (el['center'] != null && el['center'] is Map) {
        lat = (el['center']['lat'] as num?)?.toDouble();
        lng = (el['center']['lon'] as num?)?.toDouble();
      }

      if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
        continue;
      }

      // Calculate distance
      final double distanceMeters = Geolocator.distanceBetween(userLat, userLng, lat, lng);
      final String distanceText = distanceMeters < 1000
          ? "${distanceMeters.round()} m"
          : "${(distanceMeters / 1000).toStringAsFixed(1)} km";

      final pharmacy = Pharmacy.fromOsmJson(
        json: el,
        userLat: userLat,
        userLng: userLng,
        distanceInMeters: distanceMeters,
        distanceText: distanceText,
        referenceTime: referenceTime,
      );

      // Deduplicate nearby nodes/ways with identical name within 30m
      final String dedupeKey = "${pharmacy.name.toLowerCase().trim()}_${(pharmacy.lat * 1000).round()}_${(pharmacy.lng * 1000).round()}";
      if (seenIdentifiers.contains(dedupeKey)) {
        continue;
      }
      seenIdentifiers.add(dedupeKey);

      results.add(pharmacy);
    }

    // Default sort: nearest first
    results.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
    return results;
  }

  /// Launch phone call dialer with sanitized phone number
  static Future<bool> launchPharmacyCall(String phoneNumber) async {
    final sanitized = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (sanitized.length < 3) return false;

    final Uri uri = Uri.parse('tel:$sanitized');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Pharmacy call launch error: $e");
    }
    return false;
  }

  /// Launch turn-by-turn map navigation
  static Future<bool> launchNavigation(
    double destinationLat,
    double destinationLng, {
    String? pharmacyName,
  }) async {
    final encodedName = Uri.encodeComponent(pharmacyName ?? "Pharmacy");
    
    // 1. Try native geo: intent first
    final Uri geoUri = Uri.parse("geo:$destinationLat,$destinationLng?q=$destinationLat,$destinationLng($encodedName)");
    try {
      if (await canLaunchUrl(geoUri)) {
        return await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}

    // 2. Fallback to Google Maps web / universal navigation URL
    final Uri mapsUrl = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$destinationLat,$destinationLng",
    );
    try {
      if (await canLaunchUrl(mapsUrl)) {
        return await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint("Navigation launch error: $e");
    }
    return false;
  }
}
