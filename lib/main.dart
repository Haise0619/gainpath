import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'app/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/auth/role_select_screen.dart';

void main() => runApp(const GainPathApp());

/// GainPath is one Flutter codebase compiled to two distinct experiences:
/// the Web target always opens straight into the Admin / Staff console,
/// while Windows desktop and mobile (Android/iOS) open into the Gym
/// Member / Fitness Coach role select, since those two roles share the
/// same on-the-go, touch-first surface. See lib/screens/auth for the
/// role-gated entry points this branches into.
class GainPathApp extends StatelessWidget {
  const GainPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kIsWeb ? 'GainPath Admin Console' : 'GainPath',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: kIsWeb ? const LoginScreen(role: AppRole.admin) : const OnboardingScreen(),
    );
  }
}
