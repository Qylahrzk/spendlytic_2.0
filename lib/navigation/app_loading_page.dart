import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Global loading page shown during async operations.
class AppLoadingPage extends StatelessWidget {
  const AppLoadingPage({super.key});

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
            /// Lottie animation
            Lottie.asset(
              'assets/animations/loading.json',
              height: 120,
              width: 120,
              repeat: true,
            ),

            const SizedBox(height: 24),

            /// Loading text
            Text(
              "Loading...",
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
