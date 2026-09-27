import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/context_selector_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_health_screen.dart';
import 'screens/caregiver/caregiver_home_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CareSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const FirebaseInitWrapper(),
    );
  }
}

class FirebaseInitWrapper extends StatefulWidget {
  const FirebaseInitWrapper({super.key});

  @override
  State<FirebaseInitWrapper> createState() => _FirebaseInitWrapperState();
}

class _FirebaseInitWrapperState extends State<FirebaseInitWrapper> {
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      NotificationService.init().catchError((e) => debugPrint("Notification Error: $e"));
      setState(() => _initialized = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Scaffold(body: Center(child: Text("Startup Error: $_error")));
    if (!_initialized) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));
    
    return const AuthWrapper();
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          final current = FirebaseAuth.instance.currentUser;
          if (current == null) {
            return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));
          }
        }

        final user = authSnapshot.data ?? FirebaseAuth.instance.currentUser;

        if (user == null) {
          return const WelcomeScreen();
        }

        return StreamBuilder<Map<String, dynamic>?>(
          stream: ApiService.userStream(user.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))));
            }

            final data = userSnapshot.data;

            // Resolve role with auto-healing for existing accounts
            String? role = data?['role'] as String?;
            if (role == null) {
              role = 'patient';
              ApiService.updateProfile({'role': 'patient', 'hasPersonalProfile': true});
            }

            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ApiService.activeConnectionsStream(user.uid),
              builder: (context, connSnapshot) {
                final connections = connSnapshot.data ?? [];
                final hasPersonal = ApiService.hasPersonalProfile(data);

                // Multi-context user with multiple connected accounts: context selector
                if (connections.isNotEmpty && (hasPersonal && connections.length > 1)) {
                  return ContextSelectorScreen(profile: data, connections: connections);
                }

                // Legacy single-context caregiver without personal data
                if (role == 'caregiver' && !hasPersonal) {
                  return const CaregiverHomeScreen();
                }

                // Primary flow: check if personal health onboarding is complete
                final bool onboarded = data?['personalOnboardingCompleted'] == true ||
                                       data?['onboardingCompleted'] == true ||
                                       ApiService.hasHealthData(data);
                if (onboarded) {
                  return const HomeScreen();
                } else {
                  return const OnboardingHealthScreen();
                }
              },
            );

          },
        );
      },
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String view = 'welcome';

  @override
  Widget build(BuildContext context) {
    if (view == 'login') return LoginScreen(onBack: () => setState(() => view = 'welcome'));
    if (view == 'signup') return SignUpScreen(onBack: () => setState(() => view = 'welcome'));

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Hero(
                tag: 'app_logo',
                child: Image.asset('lib/assets/logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.medical_services, size: 80, color: Color(0xFF2563EB))),
              ),
              const SizedBox(height: 24),
              Text("CareSync", style: GoogleFonts.poppins(fontSize: 40, fontWeight: FontWeight.bold)),
              const Text("Your Intelligent Health Companion", textAlign: TextAlign.center),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => setState(() => view = 'login'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: const Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => view = 'signup'),
                child: const Text("Create New Account", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
