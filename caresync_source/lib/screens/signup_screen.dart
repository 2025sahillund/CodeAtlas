import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/api_service.dart';
import '../widgets/auth_widgets.dart';

class SignUpScreen extends StatefulWidget {
  final VoidCallback onBack;

  const SignUpScreen({super.key, required this.onBack});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  String email = '';
  String phone = '';
  String password = '';
  String confirmPassword = '';
  bool isLoading = false;
  bool agreeTerms = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  final Color primaryBlue = const Color(0xFF2563EB);
  final Color primaryGreen = const Color(0xFF22C55E);

  Future<void> createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!agreeTerms) {
      _showSnackBar("Please agree to the Terms & Privacy");
      return;
    }
    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    setState(() => isLoading = true);
    try {
      final normalizedEmail = email.trim().toLowerCase();
      UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      await credential.user?.updateDisplayName(name.trim());

      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'fullName': name.trim(),
        'email': normalizedEmail,
        'phone': phone.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });

      // Fix: Removed selectedRole as it is no longer accepted by ApiService.syncUser
      await ApiService.syncUser();

      // Reactive AuthWrapper handles routing automatically
      
    } on FirebaseAuthException catch (e) {
      if (mounted) _showSnackBar(e.message ?? "Signup failed", isError: true);
    } catch (e) {
      if (mounted) _showSnackBar("An unexpected error occurred", isError: true);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (isLoading) return;
    setState(() => isLoading = true);
    try {
      // Fix: Removed selectedRole as it is no longer accepted by ApiService.signInWithGoogle
      await ApiService.signInWithGoogle();
    } catch (e) {
      if (mounted) {
        _showSnackBar("Google Sign-In failed: $e", isError: true);
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.black87,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.15,
              child: CustomPaint(
                painter: WavePainter(
                  primaryBlue.withValues(alpha: isDark ? 0.2 : 0.1),
                  primaryGreen.withValues(alpha: isDark ? 0.2 : 0.1),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: primaryBlue, size: 20),
                    onPressed: widget.onBack,
                    padding: const EdgeInsets.all(16),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        Hero(
                          tag: 'app_logo',
                          child: Image.asset(
                            'lib/assets/logo.png',
                            height: 80,
                            errorBuilder: (context, error, stackTrace) => Icon(Icons.medical_services, size: 60, color: primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "CareSync",
                          style: GoogleFonts.poppins(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.headlineLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 30),
                        Text(
                          "Create Your Account",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              buildAuthTextField(
                                context: context,
                                label: "Full Name",
                                icon: Icons.person_outline,
                                onChanged: (val) => name = val,
                                validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                              ),
                              const SizedBox(height: 16),
                              buildAuthTextField(
                                context: context,
                                label: "Email Address",
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                onChanged: (val) => email = val,
                                validator: (val) => (val == null || !val.contains("@")) ? "Invalid email" : null,
                              ),
                              const SizedBox(height: 16),
                              buildAuthTextField(
                                context: context,
                                label: "Phone Number",
                                icon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                onChanged: (val) => phone = val,
                                validator: (val) => (val == null || val.isEmpty) ? "Required" : null,
                              ),
                              const SizedBox(height: 16),
                              buildAuthTextField(
                                context: context,
                                label: "Password",
                                icon: Icons.lock_outline,
                                isPassword: true,
                                showPassword: showPassword,
                                onTogglePassword: () => setState(() => showPassword = !showPassword),
                                onChanged: (val) => password = val,
                                validator: (val) => (val == null || val.length < 6) ? "Min 6 characters" : null,
                              ),
                              const SizedBox(height: 16),
                              buildAuthTextField(
                                context: context,
                                label: "Confirm Password",
                                icon: Icons.lock_outline,
                                isPassword: true,
                                showPassword: showConfirmPassword,
                                onTogglePassword: () => setState(() => showConfirmPassword = !showConfirmPassword),
                                onChanged: (val) => confirmPassword = val,
                                validator: (val) => (val != password) ? "Passwords don't match" : null,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Checkbox(
                                    value: agreeTerms,
                                    activeColor: primaryBlue,
                                    onChanged: (val) => setState(() => agreeTerms = val!),
                                  ),
                                  Expanded(
                                    child: Text("I agree to the Terms & Privacy Policy", style: GoogleFonts.poppins(fontSize: 12)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: isLoading ? null : createAccount,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 0,
                                  ),
                                  child: isLoading
                                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                      : const Text("Sign Up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        OutlinedButton(
                          onPressed: isLoading ? null : _signInWithGoogle,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            side: BorderSide(color: theme.dividerColor),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://www.gstatic.com/images/branding/googleg/1x/googleg_standard_color_128dp.png',
                                height: 24,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 24),
                              ),
                              const SizedBox(width: 12),
                              const Text("Sign up with Google", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account? "),
                            GestureDetector(
                              onTap: widget.onBack,
                              child: Text("Login", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
