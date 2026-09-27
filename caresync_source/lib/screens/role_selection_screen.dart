import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  final Function(String)? onRoleSelected;

  const RoleSelectionScreen({super.key, this.onRoleSelected});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  bool _isLoading = false;

  Future<void> _selectRole(String role) async {
    // If onRoleSelected is provided, we are in Pre-Auth mode (Welcome flow)
    if (widget.onRoleSelected != null) {
      widget.onRoleSelected!(role);
      return;
    }

    // Otherwise, we are in Post-Auth mode (Existing user with missing role)
    setState(() => _isLoading = true);
    try {
      // Logic handled reactively by AuthWrapper after Firestore update
      await ApiService.updateProfile({
        'role': role,
        if (role == 'patient') 'hasPersonalProfile': true,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving role: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Welcome to CareSync",
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "How will you use the app?",
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
              const SizedBox(height: 48),
              _buildRoleCard(
                title: "I am a Patient",
                description: "Manage my medications, logs, and SOS alerts.",
                icon: Icons.person,
                color: Colors.blue,
                onTap: () => _selectRole('patient'),
              ),
              const SizedBox(height: 20),
              _buildRoleCard(
                title: "I am a Caregiver",
                description: "Monitor health data for a family member.",
                icon: Icons.family_restroom,
                color: Colors.green,
                onTap: () => _selectRole('caregiver'),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}
