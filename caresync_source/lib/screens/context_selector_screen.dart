import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'onboarding_health_screen.dart';
import 'caregiver/caregiver_home_screen.dart';
import 'caregiver/patient_dashboard_screen.dart';

class ContextSelectorScreen extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>>? connections;

  const ContextSelectorScreen({super.key, this.profile, this.connections});

  @override
  State<ContextSelectorScreen> createState() => _ContextSelectorScreenState();
}

class _ContextSelectorScreenState extends State<ContextSelectorScreen> {
  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _connections = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContexts();
  }

  Future<void> _loadContexts() async {
    if (widget.profile != null && widget.connections != null) {
      if (mounted) {
        setState(() {
          _profile = widget.profile;
          _connections = widget.connections!;
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final profile = await ApiService.getProfile();
      final connections = await ApiService.getCaregiverConnections();
      if (mounted) {
        setState(() {
          _profile = profile;
          _connections = connections;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("_loadContexts error: $e");
      if (mounted) {
        setState(() {
          _profile = null;
          _connections = [];
          _isLoading = false;
        });
      }
    }
  }

  bool get _hasPersonalProfile {
    if (_profile == null) return false;
    return ApiService.hasPersonalProfile(_profile);
  }

  List<_ContextItem> get _contexts {
    final List<_ContextItem> items = [];
    if (_hasPersonalProfile) {
      items.add(_ContextItem(
        label: 'You',
        subtitle: 'Manage your own health',
        icon: Icons.person,
        color: Colors.blue,
        onTap: () {
          final onboardingComplete = _profile?['personalOnboardingCompleted'] == true ||
                                     _profile?['onboardingCompleted'] == true ||
                                     ApiService.hasHealthData(_profile);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => onboardingComplete
                  ? const HomeScreen()
                  : const OnboardingHealthScreen(),
            ),
          );
        },
      ));
    }
    for (final conn in _connections) {
      final name = conn['patientName'] ?? conn['name'] ?? 'Connected Patient';
      final pUid = conn['patientUid'] as String? ?? '';
      items.add(_ContextItem(
        label: name,
        subtitle: 'Caregiver live health access',
        icon: Icons.family_restroom,
        color: Colors.green,
        onTap: () {
          if (pUid.isNotEmpty) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PatientDashboardScreen(
                  patientUid: pUid,
                  patientName: name,
                ),
              ),
            );
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CaregiverHomeScreen()),
            );
          }
        },
      ));
    }

    if (_profile?['role'] == 'caregiver' && _connections.isEmpty) {
      items.add(_ContextItem(
        label: 'Caregiver Dashboard',
        subtitle: 'Monitor connected patients',
        icon: Icons.family_restroom,
        color: Colors.green,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CaregiverHomeScreen()),
          );
        },
      ));
    }
    return items;
  }

  void _handleContextSelected(_ContextItem item) {
    item.onTap();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));
    }

    final contexts = _contexts;

    return Scaffold(
      appBar: AppBar(
        title: Text('Choose Context', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back',
                style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a profile to continue',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: contexts.length,
                  itemBuilder: (context, index) {
                    final item = contexts[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: InkWell(
                        onTap: () => _handleContextSelected(item),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            border: Border.all(color: item.color.withValues(alpha: 0.3), width: 2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: item.color.withValues(alpha: 0.1),
                                child: Icon(item.icon, color: item.color, size: 30),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.label,
                                      style: GoogleFonts.poppins(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      item.subtitle,
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.arrow_forward_ios, size: 16, color: item.color),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextItem {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ContextItem({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
