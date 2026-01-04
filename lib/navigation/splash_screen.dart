import 'package:flutter/material.dart';
import 'package:spendlytic_v2/screens/get_started_screen.dart';

/// Splash screen for Spendlytic.
/// Shows the app name and loading indicator before navigating.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();

    // ⏱ Change duration as needed to record longer
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const GetStartedScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// App name
            Text(
              'Spendlytic',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            /// Loading indicator
            CircularProgressIndicator(
              color: colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}
