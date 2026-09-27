class Hospital {
  final String id;
  final String name;
  final double lat;
  final double lng;
  final double distanceInMeters;
  final String distanceText;
  final String? phone;
  final String address;
  final bool isEmergencyReady;
  final String facilityType;
  final String? openingHours;

  const Hospital({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.distanceInMeters,
    required this.distanceText,
    this.phone,
    required this.address,
    required this.isEmergencyReady,
    required this.facilityType,
    this.openingHours,
  });

  /// Sanitized phone number for direct tel: intent dialing
  String? get dialablePhone {
    if (phone == null) return null;
    final sanitized = phone!.replaceAll(RegExp(r'[^\d+]'), '');
    return sanitized.isNotEmpty ? sanitized : null;
  }
}
