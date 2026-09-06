import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:gainpath/features/identity/application/auth_bloc.dart';
import 'package:gainpath/features/identity/domain/repositories/member_profile_repository.dart';
import 'package:gainpath/features/membership/domain/repositories/membership_repository.dart';
import 'package:gainpath/features/membership/application/membership_bloc.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:gainpath/features/gamification/application/gamification_bloc.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/features/coaching/application/booking_bloc.dart';
import 'package:gainpath/app/di/app_repositories.dart';
import 'package:gainpath/app/theme/theme.dart';
import 'package:gainpath/core/domain/app_role.dart';
import 'package:gainpath/features/identity/presentation/shared/login_screen.dart';
import 'package:gainpath/features/identity/presentation/shared/onboarding_screen.dart';

/// GainPath is one Flutter codebase compiled to two distinct experiences:
/// the Web target always opens straight into the Admin / Staff console,
/// while Windows desktop and mobile (Android/iOS) open into the Gym
/// Member / Fitness Coach role select, since those two roles share the
/// same on-the-go, touch-first surface. See features/identity/presentation
/// for the role-gated entry points this branches into.
class GainPathApp extends StatelessWidget {
  const GainPathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppRepositories(
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => AuthBloc()),
          BlocProvider(
            create: (context) =>
                BookingBloc(context.read<BookingRepository>())..add(const BookingsRequested()),
          ),
          BlocProvider(
            create: (context) => GamificationBloc(context.read<GamificationRepository>()),
          ),
          BlocProvider(
            create: (context) => MembershipBloc(
              context.read<MembershipRepository>(),
              memberName: context.read<MemberProfileRepository>().memberName,
            ),
          ),
        ],
        child: MaterialApp(
          title: kIsWeb ? 'GainPath Admin Console' : 'GainPath',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: kIsWeb ? const LoginScreen(role: AppRole.admin) : const OnboardingScreen(),
        ),
      ),
    );
  }
}
