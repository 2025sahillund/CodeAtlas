import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/emergency_places_service.dart';
import '../models/hospital.dart';

class SOSScreen extends StatefulWidget {
  final String? targetUid;
  final bool isReadOnly;
  const SOSScreen({super.key, this.targetUid, this.isReadOnly = false});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  bool sosActivated = false;
  int? countdown;
  Timer? timer;
  Map<String, dynamic>? userProfile;
  bool isLoading = true;

  // Real Map & Hospital state
  Position? currentPosition;
  List<Hospital> nearbyHospitals = [];
  Hospital? selectedHospital;
  bool isSearchingHospitals = false;
  String? hospitalErrorMessage;
  bool locationPermissionDenied = false;
  bool locationServiceDisabled = false;

  final MapController mapController = MapController();

  @override
  void initState() {
    super.initState();
    _initEmergencyFlow();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _initEmergencyFlow() async {
    await _loadEmergencyData();
    await _getCurrentLocationAndFetchHospitals();
  }

  Future<void> _loadEmergencyData() async {
    final data = await ApiService.getProfile(targetUid: widget.targetUid);
    if (mounted) {
      setState(() {
        userProfile = data;
        isLoading = false;
      });
    }
  }

  Future<void> _getCurrentLocationAndFetchHospitals() async {
    if (!mounted) return;
    setState(() {
      isSearchingHospitals = true;
      hospitalErrorMessage = null;
      locationPermissionDenied = false;
      locationServiceDisabled = false;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            locationServiceDisabled = true;
            isSearchingHospitals = false;
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              locationPermissionDenied = true;
              isSearchingHospitals = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            locationPermissionDenied = true;
            isSearchingHospitals = false;
          });
        }
        return;
      }

      Position? pos;
      // 1. Try fast last known position first
      try {
        pos = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      if (pos != null && mounted) {
        setState(() {
          currentPosition = pos;
        });
      }

      // 2. Fetch fresh position with 6-second timeout
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 6),
          ),
        );
      } catch (e) {
        debugPrint("Fresh GPS fix timeout/warning: $e");
        if (pos == null) {
          try {
            pos = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 4),
              ),
            );
          } catch (_) {}
        }
      }

      if (pos == null) {
        if (mounted) {
          setState(() {
            hospitalErrorMessage = "Unable to resolve GPS coordinates. Please ensure device location is active.";
            isSearchingHospitals = false;
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          currentPosition = pos;
        });
      }

      // Query real nearby facilities via Overpass API
      final hospitals = await EmergencyPlacesService.fetchNearbyHospitals(
        latitude: pos.latitude,
        longitude: pos.longitude,
        radiusInMeters: 8000,
      );

      if (mounted) {
        setState(() {
          nearbyHospitals = hospitals;
          selectedHospital = hospitals.isNotEmpty ? hospitals.first : null;
          isSearchingHospitals = false;
        });

        if (hospitals.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              mapController.move(LatLng(pos!.latitude, pos.longitude), 14.0);
            } catch (_) {}
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching real hospitals: $e");
      if (mounted) {
        setState(() {
          hospitalErrorMessage = "Unable to load live healthcare facilities. Check connection.";
          isSearchingHospitals = false;
        });
      }
    }
  }

  void _selectHospital(Hospital hospital) {
    setState(() {
      selectedHospital = hospital;
    });
    try {
      mapController.move(LatLng(hospital.lat, hospital.lng), 15.0);
    } catch (_) {}
  }

  List<Marker> _buildMarkers() {
    if (currentPosition == null) return [];

    final List<Marker> list = [];

    // 1. User Location Pin
    list.add(
      Marker(
        point: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        width: 70,
        height: 70,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.shade700,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Text(
                "You",
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.person_pin_circle, color: Colors.blue, size: 36),
          ],
        ),
      ),
    );

    // 2. Real Hospital Markers
    for (final hospital in nearbyHospitals) {
      final bool isSelected = selectedHospital?.id == hospital.id;
      final Color pinColor = hospital.isEmergencyReady ? const Color(0xFFDC2626) : const Color(0xFFEA580C);

      list.add(
        Marker(
          point: LatLng(hospital.lat, hospital.lng),
          width: isSelected ? 80 : 60,
          height: isSelected ? 80 : 60,
          child: GestureDetector(
            onTap: () => _selectHospital(hospital),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: Column(
                children: [
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pinColor,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
                      ),
                      child: Text(
                        hospital.name.length > 14 ? "${hospital.name.substring(0, 14)}..." : hospital.name,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Icon(
                    Icons.local_hospital,
                    color: pinColor,
                    size: isSelected ? 38 : 28,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return list;
  }

  void startCountdown() {
    setState(() => countdown = 3);
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (countdown == 1) {
        t.cancel();
        activateSOS();
      } else {
        setState(() => countdown = countdown! - 1);
      }
    });
  }

  void cancelSOS() {
    timer?.cancel();
    setState(() => countdown = null);
  }

  void activateSOS() async {
    setState(() {
      countdown = null;
      sosActivated = true;
    });

    // 1. Trigger immediate emergency local alert
    try {
      await NotificationService.showImmediateNotification(
        title: "🚨 SOS Emergency Alert Active",
        body: "Emergency mode engaged. Nearby hospitals & medical details displayed.",
        type: "emergency",
      );
    } catch (_) {}

    // 2. Record in patient notification feed & broadcast to caregivers
    final uid = ApiService.currentUid;
    if (uid != null) {
      final String alertRef = "sos_${DateTime.now().millisecondsSinceEpoch}";
      ApiService.sendInAppNotification(
        targetUid: uid,
        title: "🚨 SOS Emergency Triggered",
        body: "Emergency SOS broadcast was activated. Nearby responders & hospitals located.",
        type: "emergency",
        referenceId: alertRef,
      );

      try {
        final connections = await ApiService.getCaregiverConnections();
        final patientName = userProfile?['name'] ?? userProfile?['fullName'] ?? 'Patient';
        for (var conn in connections) {
          final cUid = conn['caregiverUid'] as String?;
          if (cUid != null && cUid.isNotEmpty) {
            ApiService.sendInAppNotification(
              targetUid: cUid,
              title: "🚨 EMERGENCY ALERT: $patientName",
              body: "$patientName has triggered an Emergency SOS! Please check immediately.",
              type: "emergency",
              referenceId: "${alertRef}_$cUid",
            );
          }
        }
      } catch (e) {
        debugPrint("Error broadcasting SOS to caregivers: $e");
      }
    }
  }

  void deactivateSOS() => setState(() => sosActivated = false);

  @override
  Widget build(BuildContext context) {
    String bloodGroup = userProfile?['blood_group'] ?? "Not Set";
    final int? calculatedAge = ApiService.calculateAge(userProfile?['dob'] ?? userProfile?['age']);
    String ageText = calculatedAge != null ? "$calculatedAge Years" : "Not provided";
    String emergencyPhone = userProfile?['emergency_phone'] ?? userProfile?['emergency_contact'] ?? "Not Set";

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  /// HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const CircleAvatar(
                            backgroundColor: Colors.white24,
                            child: Icon(Icons.arrow_back, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 15),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Emergency SOS",
                                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                "Real-time medical assistance & nearest hospitals",
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        /// UNIFIED DIRECT EMERGENCY DISPATCH SECTION
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: const [
                                  Icon(Icons.phone_forwarded_rounded, color: Color(0xFFDC2626), size: 18),
                                  SizedBox(width: 8),
                                  Text(
                                    "Direct Emergency Dispatch (1-Tap Call)",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: _hotlineButton(
                                      icon: Icons.emergency,
                                      title: "112 National",
                                      subtitle: "All Emergency",
                                      color: const Color(0xFFDC2626),
                                      onTap: () => EmergencyPlacesService.launchEmergencyCall("112"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _hotlineButton(
                                      icon: Icons.local_hospital,
                                      title: "108 / 102",
                                      subtitle: "Ambulance",
                                      color: const Color(0xFFEA580C),
                                      onTap: () => EmergencyPlacesService.launchEmergencyCall("108"),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _hotlineButton(
                                      icon: Icons.local_police,
                                      title: "100 Police",
                                      subtitle: "Police Control",
                                      color: const Color(0xFF2563EB),
                                      onTap: () => EmergencyPlacesService.launchEmergencyCall("100"),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _hotlineButton(
                                      icon: Icons.contact_phone,
                                      title: "Contact",
                                      subtitle: emergencyPhone != "Not Set" ? emergencyPhone : "Set in Profile",
                                      color: const Color(0xFF16A34A),
                                      onTap: emergencyPhone != "Not Set"
                                          ? () => EmergencyPlacesService.launchEmergencyCall(emergencyPhone)
                                          : () => ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text("Please set Emergency Contact in Profile")),
                                              ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        /// SOS ACTIVATION INTERFACE
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (!sosActivated) ...[
                                  const Text(
                                    "Need Immediate Help?",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    "Press the button to broadcast emergency status",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey, fontSize: 13),
                                  ),
                                  const SizedBox(height: 20),
                                  if (countdown != null) ...[
                                    Center(
                                      child: Container(
                                        width: 110,
                                        height: 110,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFDC2626),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            countdown.toString(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 44,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    OutlinedButton(
                                      onPressed: cancelSOS,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                      ),
                                      child: const Text("Cancel SOS"),
                                    )
                                  ] else ...[
                                    Center(
                                      child: GestureDetector(
                                        onTap: widget.isReadOnly ? null : startCountdown,
                                        child: Container(
                                          width: 150,
                                          height: 150,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.red.withValues(alpha: 0.4),
                                                blurRadius: 18,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: const Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.warning_amber_rounded, size: 48, color: Colors.white),
                                              SizedBox(height: 4),
                                              Text(
                                                "SOS",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]
                                ] else ...[
                                  const Icon(Icons.warning, size: 64, color: Color(0xFFDC2626)),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "SOS ACTIVATED",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    "Emergency broadcast active. Your medical profile and coordinates are available.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.black87),
                                  ),
                                  const SizedBox(height: 16),
                                  OutlinedButton(
                                    onPressed: deactivateSOS,
                                    child: const Text("Deactivate SOS"),
                                  ),
                                ]
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// REAL NEARBY HOSPITALS MAP CARD
                        Card(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                                child: Row(
                                  children: [
                                    const Icon(Icons.local_hospital_outlined, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        "Real Nearby Hospitals & Facilities",
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ),
                                    if (isSearchingHospitals)
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.refresh, size: 20),
                                        onPressed: _getCurrentLocationAndFetchHospitals,
                                        tooltip: "Refresh nearby facilities",
                                      )
                                  ],
                                ),
                              ),

                              // Map Viewport
                              SizedBox(
                                height: 280,
                                width: double.infinity,
                                child: _buildMapContent(),
                              ),

                              // Selected Hospital Details Box
                              if (selectedHospital != null)
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  color: Colors.red.shade50,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  selectedHospital!.name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  selectedHospital!.address,
                                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFDC2626),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              selectedHospital!.distanceText,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (selectedHospital!.isEmergencyReady)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade100,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, color: Colors.green, size: 12),
                                                  SizedBox(width: 4),
                                                  Text("24/7 Emergency", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                                                ],
                                              ),
                                            ),
                                          const Spacer(),
                                          if (selectedHospital!.dialablePhone != null)
                                            ElevatedButton.icon(
                                              onPressed: () => EmergencyPlacesService.launchEmergencyCall(selectedHospital!.dialablePhone!),
                                              icon: const Icon(Icons.call, size: 14),
                                              label: const Text("Call"),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                minimumSize: const Size(60, 32),
                                              ),
                                            ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => EmergencyPlacesService.launchDirections(
                                              selectedHospital!.lat,
                                              selectedHospital!.lng,
                                              facilityName: selectedHospital!.name,
                                            ),
                                            icon: const Icon(Icons.directions, size: 14),
                                            label: const Text("Navigate"),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              minimumSize: const Size(60, 32),
                                            ),
                                          ),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// REAL HOSPITALS LIST & GOOGLE MAPS FALLBACK
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      "Discovered Facilities",
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      "${nearbyHospitals.length} Found",
                                      style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (isSearchingHospitals)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(child: CircularProgressIndicator()),
                                  )
                                else if (nearbyHospitals.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(Icons.location_off, size: 40, color: Colors.grey.shade400),
                                          const SizedBox(height: 8),
                                          Text(
                                            hospitalErrorMessage ?? "No hospitals found within search radius.",
                                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: nearbyHospitals.length > 5 ? 5 : nearbyHospitals.length,
                                    separatorBuilder: (context, index) => const Divider(height: 16),
                                    itemBuilder: (context, index) {
                                      final hospital = nearbyHospitals[index];
                                      final isSelected = selectedHospital?.id == hospital.id;

                                      return InkWell(
                                        onTap: () => _selectHospital(hospital),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.red.shade50 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                backgroundColor: hospital.isEmergencyReady ? Colors.red.shade100 : Colors.orange.shade100,
                                                child: Icon(
                                                  Icons.local_hospital,
                                                  color: hospital.isEmergencyReady ? const Color(0xFFDC2626) : const Color(0xFFEA580C),
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      hospital.name,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14,
                                                        color: isSelected ? const Color(0xFFDC2626) : Colors.black87,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      "${hospital.distanceText} • ${hospital.address}",
                                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (hospital.dialablePhone != null)
                                                IconButton(
                                                  icon: const Icon(Icons.phone, color: Colors.green, size: 20),
                                                  onPressed: () => EmergencyPlacesService.launchEmergencyCall(hospital.dialablePhone!),
                                                  tooltip: "Call ${hospital.name}",
                                                ),
                                              IconButton(
                                                icon: const Icon(Icons.directions, color: Color(0xFF2563EB), size: 20),
                                                onPressed: () => EmergencyPlacesService.launchDirections(hospital.lat, hospital.lng),
                                                tooltip: "Get Directions",
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: () {
                                      if (currentPosition != null) {
                                        EmergencyPlacesService.launchGoogleMapsNearby(
                                          currentPosition!.latitude,
                                          currentPosition!.longitude,
                                        );
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text("Location required to open Google Maps")),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.map, size: 16),
                                    label: const Text("Open All Nearby Hospitals in Google Maps"),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        /// MEDICAL SUMMARY CARD
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          elevation: 1,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text("Medical Info Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 10),
                                _medicalRow("Blood Type", bloodGroup),
                                _medicalRow("Age", ageText),
                                _medicalRow("Emergency Contact", emergencyPhone),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  )
                ],
              ),
            ),
    );
  }

  Widget _hotlineButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapContent() {
    if (locationServiceDisabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_disabled, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              const Text("Location Service is Disabled", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Geolocator.openLocationSettings();
                  _getCurrentLocationAndFetchHospitals();
                },
                child: const Text("Enable GPS"),
              ),
            ],
          ),
        ),
      );
    }

    if (locationPermissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.security, color: Colors.orange, size: 36),
              const SizedBox(height: 8),
              const Text("Location Permission Required", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  await Geolocator.openAppSettings();
                  _getCurrentLocationAndFetchHospitals();
                },
                child: const Text("Grant Permission"),
              ),
            ],
          ),
        ),
      );
    }

    if (currentPosition == null) {
      if (isSearchingHospitals) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 10),
              Text("Acquiring GPS position...", style: TextStyle(color: Colors.grey)),
            ],
          ),
        );
      } else {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_off, color: Colors.grey, size: 36),
                const SizedBox(height: 8),
                const Text("GPS Position Unavailable", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                  "Could not acquire coordinates. Ensure location is enabled on device.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _getCurrentLocationAndFetchHospitals,
                  icon: const Icon(Icons.my_location, size: 16),
                  label: const Text("Retry GPS"),
                ),
              ],
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.care_sync.app',
        ),
        MarkerLayer(markers: _buildMarkers()),
      ],
    );
  }

  Widget _medicalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
