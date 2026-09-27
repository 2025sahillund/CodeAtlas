import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/pharmacy.dart';
import '../../services/pharmacy_service.dart';

enum PharmacyFilter { all, openNow, hours24 }
enum PharmacySort { nearest, openNow, hours24 }

class NearbyPharmaciesScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const NearbyPharmaciesScreen({
    super.key,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<NearbyPharmaciesScreen> createState() => _NearbyPharmaciesScreenState();
}

class _NearbyPharmaciesScreenState extends State<NearbyPharmaciesScreen> {
  // Location & State
  Position? _currentPosition;
  double _searchRadiusMeters = 5000; // 5 km default
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPermissionDenied = false;
  bool _isServiceDisabled = false;

  // Data
  List<Pharmacy> _allPharmacies = [];
  PharmacyFilter _selectedFilter = PharmacyFilter.all;
  PharmacySort _selectedSort = PharmacySort.nearest;

  @override
  void initState() {
    super.initState();
    _initLocationAndFetch();
  }

  Future<void> _initLocationAndFetch() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isPermissionDenied = false;
      _isServiceDisabled = false;
      _allPharmacies = []; // Clear previous results to prevent stale cache
    });

    try {
      // 1. Check Location Services
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isServiceDisabled = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Check Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _isPermissionDenied = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isPermissionDenied = true;
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Resolve Position: Prioritize fresh GPS position first to avoid stale emulator cache
      Position? pos;
      String positionSource = 'fresh';

      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        positionSource = 'currentPosition (high accuracy)';
      } catch (e) {
        debugPrint("[CareSync Pharmacy] High accuracy GPS fix timeout: $e");
        try {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 4),
            ),
          );
          positionSource = 'currentPosition (medium accuracy)';
        } catch (e2) {
          debugPrint("[CareSync Pharmacy] Medium accuracy GPS fix timeout: $e2");
        }
      }

      // Fallback to last known position only if fresh fix completely failed
      if (pos == null) {
        try {
          pos = await Geolocator.getLastKnownPosition();
          if (pos != null) {
            positionSource = 'lastKnownPosition (cached)';
          }
        } catch (_) {}
      }

      if (pos == null) {
        if (mounted) {
          setState(() {
            _errorMessage = "Location unavailable. Please ensure GPS is active.";
            _isLoading = false;
          });
        }
        return;
      }

      // Detailed GPS Diagnostics Logging
      debugPrint("==================================================");
      debugPrint("[CareSync GPS Diagnostic Log]");
      debugPrint("Source: $positionSource");
      debugPrint("Latitude: ${pos.latitude}");
      debugPrint("Longitude: ${pos.longitude}");
      debugPrint("Accuracy: ${pos.accuracy} meters");
      debugPrint("Timestamp: ${pos.timestamp}");
      debugPrint("==================================================");

      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
      }

      await _fetchPharmacies(pos.latitude, pos.longitude);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to load nearby pharmacies. Please try again.";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchPharmacies(double lat, double lng) async {
    try {
      final pharmacies = await PharmacyService.fetchNearbyPharmacies(
        latitude: lat,
        longitude: lng,
        radiusInMeters: _searchRadiusMeters,
      );

      if (mounted) {
        setState(() {
          _allPharmacies = pharmacies;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Unable to load nearby pharmacies.";
          _isLoading = false;
        });
      }
    }
  }

  List<Pharmacy> get _filteredAndSortedPharmacies {
    List<Pharmacy> list = List.from(_allPharmacies);

    // Filter
    switch (_selectedFilter) {
      case PharmacyFilter.all:
        break;
      case PharmacyFilter.openNow:
        list = list.where((p) => p.isOpen == true).toList();
        break;
      case PharmacyFilter.hours24:
        list = list.where((p) => p.is24Hours).toList();
        break;
    }

    // Sort
    switch (_selectedSort) {
      case PharmacySort.nearest:
        list.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
        break;
      case PharmacySort.openNow:
        list.sort((a, b) {
          final aOpen = a.isOpen == true ? 0 : 1;
          final bOpen = b.isOpen == true ? 0 : 1;
          if (aOpen != bOpen) return aOpen.compareTo(bOpen);
          return a.distanceInMeters.compareTo(b.distanceInMeters);
        });
        break;
      case PharmacySort.hours24:
        list.sort((a, b) {
          final a24 = a.is24Hours ? 0 : 1;
          final b24 = b.is24Hours ? 0 : 1;
          if (a24 != b24) return a24.compareTo(b24);
          return a.distanceInMeters.compareTo(b.distanceInMeters);
        });
        break;
    }

    return list;
  }

  void _onRadiusChanged(double newRadius) {
    if (_searchRadiusMeters != newRadius) {
      setState(() {
        _searchRadiusMeters = newRadius;
        _isLoading = true;
      });
      if (_currentPosition != null) {
        _fetchPharmacies(_currentPosition!.latitude, _currentPosition!.longitude);
      } else {
        _initLocationAndFetch();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          "Nearby Pharmacies",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: "Refresh Pharmacies",
            onPressed: _initLocationAndFetch,
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF2563EB), Color(0xFF10B981)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _initLocationAndFetch,
        color: const Color(0xFF2563EB),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF2563EB)),
            const SizedBox(height: 18),
            Text(
              "Finding nearby pharmacies...",
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
            ),
            const SizedBox(height: 6),
            Text(
              "Querying OpenStreetMap data",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (_isServiceDisabled) {
      return _buildErrorCard(
        icon: Icons.location_off_rounded,
        title: "Location services disabled",
        message: "Please turn on your device GPS / location services to find pharmacies near you.",
        buttonText: "Open Location Settings",
        onPressed: () async {
          await Geolocator.openLocationSettings();
          _initLocationAndFetch();
        },
      );
    }

    if (_isPermissionDenied) {
      return _buildErrorCard(
        icon: Icons.location_disabled_rounded,
        title: "Location permission required",
        message: "Location permission is required to find nearby pharmacies.",
        buttonText: "Grant Location Permission",
        onPressed: () async {
          await Geolocator.openAppSettings();
          _initLocationAndFetch();
        },
      );
    }

    if (_errorMessage != null) {
      return _buildErrorCard(
        icon: Icons.cloud_off_rounded,
        title: "Unable to load nearby pharmacies",
        message: _errorMessage!,
        buttonText: "Retry",
        onPressed: _initLocationAndFetch,
      );
    }

    final filtered = _filteredAndSortedPharmacies;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header & Description
                Text(
                  "Find pharmacies near your current location",
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 10),

                // Informational Disclaimer Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "Informational only: CareSync lists real nearby facilities from OpenStreetMap. Please call the pharmacy to confirm medicine stock.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade900,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_currentPosition != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.pin_drop_rounded, size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 4),
                      Text(
                        "Device GPS: ${_currentPosition!.latitude.toStringAsFixed(4)}°, ${_currentPosition!.longitude.toStringAsFixed(4)}°",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 12),

                // Radius selection & Location chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.my_location_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 5),
                          Text(
                            "Radius:",
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text("5 km"),
                      selected: _searchRadiusMeters == 5000,
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: _searchRadiusMeters == 5000 ? Colors.white : Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) _onRadiusChanged(5000);
                      },
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text("10 km"),
                      selected: _searchRadiusMeters == 10000,
                      selectedColor: const Color(0xFF2563EB),
                      labelStyle: TextStyle(
                        color: _searchRadiusMeters == 10000 ? Colors.white : Colors.grey.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) _onRadiusChanged(10000);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Filter tabs: [ All ] [ Open Now ] [ 24 Hours ]
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip("All", PharmacyFilter.all),
                      const SizedBox(width: 8),
                      _buildFilterChip("Open Now", PharmacyFilter.openNow),
                      const SizedBox(width: 8),
                      _buildFilterChip("24 Hours", PharmacyFilter.hours24),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Sort dropdown row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${filtered.length} pharmac${filtered.length == 1 ? 'y' : 'ies'} found",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          "Sort: ",
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                        ),
                        DropdownButton<PharmacySort>(
                          value: _selectedSort,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF2563EB)),
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF2563EB),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          items: const [
                            DropdownMenuItem(value: PharmacySort.nearest, child: Text("Nearest")),
                            DropdownMenuItem(value: PharmacySort.openNow, child: Text("Open Now")),
                            DropdownMenuItem(value: PharmacySort.hours24, child: Text("24 Hours")),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _selectedSort = val);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Pharmacy list or empty state
        if (filtered.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildEmptyState(),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildPharmacyCard(filtered[index]),
                childCount: filtered.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(
          child: SizedBox(height: 30),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, PharmacyFilter filter) {
    final bool isSelected = _selectedFilter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : Colors.grey.shade300,
        ),
      ),
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: isSelected ? Colors.white : Colors.grey.shade800,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filter);
        }
      },
    );
  }

  Widget _buildPharmacyCard(Pharmacy pharmacy) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Name & Distance badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text("💊", style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pharmacy.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 2),
                          Text(
                            pharmacy.distanceText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Address
            if (pharmacy.address != null && pharmacy.address!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.place_outlined, size: 15, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      pharmacy.address!,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // Status Badge
            _buildStatusBadge(pharmacy),

            const SizedBox(height: 14),

            // Action Buttons: Call & Navigate
            Row(
              children: [
                // Call Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: pharmacy.dialablePhone != null ? const Color(0xFF2563EB) : Colors.grey,
                        side: BorderSide(
                          color: pharmacy.dialablePhone != null ? const Color(0xFF2563EB) : Colors.grey.shade300,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text(
                        "Call",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: pharmacy.dialablePhone != null
                          ? () => PharmacyService.launchPharmacyCall(pharmacy.dialablePhone!)
                          : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Navigate Button
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.navigation_rounded, size: 18),
                      label: const Text(
                        "Navigate",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () => PharmacyService.launchNavigation(
                        pharmacy.lat,
                        pharmacy.lng,
                        pharmacyName: pharmacy.name,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Pharmacy pharmacy) {
    if (pharmacy.is24Hours) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("🟢 ", style: TextStyle(fontSize: 10)),
            Text(
              "Open 24 hours",
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    }

    if (pharmacy.isOpen == true) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFDCFCE7),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🟢 ", style: TextStyle(fontSize: 10)),
            Text(
              "Open now${pharmacy.statusDetail != null ? ' • ${pharmacy.statusDetail}' : ''}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF15803D),
              ),
            ),
          ],
        ),
      );
    }

    if (pharmacy.isOpen == false) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("🔴 ", style: TextStyle(fontSize: 10)),
            Text(
              "Closed${pharmacy.statusDetail != null ? ' • ${pharmacy.statusDetail}' : ''}",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB91C1C),
              ),
            ),
          ],
        ),
      );
    }

    // Unknown / Hours unavailable
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("⚪ ", style: TextStyle(fontSize: 10)),
          Text(
            "Hours unavailable",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String title = "No pharmacies found nearby.";
    String message = "No pharmacies were found within ${_searchRadiusMeters >= 1000 ? '${(_searchRadiusMeters / 1000).toInt()} km' : '${_searchRadiusMeters.toInt()} m'}.";

    if (_selectedFilter == PharmacyFilter.hours24) {
      title = "No 24-hour pharmacies found";
      message = "No pharmacies with verified 24/7 opening hours found in this radius.";
    } else if (_selectedFilter == PharmacyFilter.openNow) {
      title = "No open pharmacies found";
      message = "No pharmacies currently open found in this radius.";
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_pharmacy_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.grey.shade800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchRadiusMeters < 10000)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.search, size: 18),
                label: const Text("Search within 10 km", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _onRadiusChanged(10000),
              )
            else
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Retry Search", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: _initLocationAndFetch,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard({
    required IconData icon,
    required String title,
    required String message,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: const Color(0xFF2563EB)),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onPressed,
              child: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
