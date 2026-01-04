import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:spendlytic_v2/screens/home_screen.dart';
import 'package:spendlytic_v2/screens/login_screen.dart';

class AuthLayout extends StatefulWidget {
  const AuthLayout({super.key});

  @override
  State<AuthLayout> createState() => _AuthLayoutState();
}

class _AuthLayoutState extends State<AuthLayout> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isVerified = false;
  String _biometricLabel = "Biometrics"; // Will change to 'Face ID' or 'Fingerprint'
  IconData _biometricIcon = Icons.fingerprint; // Default icon

  @override
  void initState() {
    super.initState();
    _checkBiometricType();
  }

  /// 🔍 Check if device supports Face ID or Fingerprint
  Future<void> _checkBiometricType() async {
    try {
      List<BiometricType> availableBiometrics = await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.contains(BiometricType.face)) {
        setState(() {
          _biometricLabel = "Face ID";
          _biometricIcon = Icons.face;
        });
      } else if (availableBiometrics.contains(BiometricType.fingerprint)) {
        setState(() {
          _biometricLabel = "Fingerprint";
          _biometricIcon = Icons.fingerprint;
        });
      }
    } catch (e) {
      debugPrint("Biometric Check Error: $e");
    }
  }

  /// 🔐 Trigger the Scanner
  Future<void> _authenticate() async {
    try {
      final bool didAuth = await _localAuth.authenticate(
        localizedReason: 'Please authenticate with $_biometricLabel to access Spendlytic',
        options: const AuthenticationOptions(
          stickyAuth: true, // Keeps dialog open if app goes background
          biometricOnly: true, // Don't allow PIN fallback (Higher Security)
        ),
      );

      if (didAuth) {
        setState(() => _isVerified = true);
      }
    } catch (e) {
      debugPrint("Auth Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session;

        // 1. NOT LOGGED IN -> Show Email/Password Screen
        if (session == null) {
          _isVerified = false; // Reset security
          return const LoginScreen();
        }

        // 2. LOGGED IN + VERIFIED -> Show Dashboard
        if (_isVerified) {
          return const HomeScreen();
        }

        // 3. LOGGED IN + NOT VERIFIED -> Show "Face ID" Lock Screen
        
        // Auto-trigger biometric prompt once when view loads
        WidgetsBinding.instance.addPostFrameCallback((_) {
           // Only auto-trigger if we haven't tried recently to avoid loop
           // (Simple implementation: Button is safer)
        });

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Security Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                
                const Text(
                  "Spendlytic Locked",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  "Authenticate with $_biometricLabel to continue",
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                // The Big "Face ID" Button
                SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _authenticate,
                    icon: Icon(_biometricIcon, color: Colors.white),
                    label: Text("Use $_biometricLabel"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Logout option (In case Face ID fails)
                TextButton(
                  onPressed: () async {
                    await Supabase.instance.client.auth.signOut();
                    // This will trigger the StreamBuilder to show LoginScreen
                  },
                  child: const Text("Log Out"),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}