import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../navigation/feature_navigation.dart';
import '../../features/workout/presentation/shared/equipment_detail_screen.dart';
import '../../features/coaching/presentation/shared/coach_profile_screen.dart';
import '../../features/membership/presentation/shared/membership_dashboard_screen.dart';
import '../../features/membership/presentation/shared/billplz_checkout_screen.dart';
import '../../features/analytics/presentation/shared/progress_dashboard_screen.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../di/local_member_progress_factory.dart';
import 'member_progress_route.dart';

Route<dynamic>? buildFeatureRoute(RouteSettings settings,
    {bool firebase = false,
    LocalMemberProgressRepositoryFactory? progressRepositoryFactory}) {
  final args = settings.arguments;
  final legacyOnly = const {
    FeatureNavigation.equipment,
    FeatureNavigation.coach,
    FeatureNavigation.membership,
    FeatureNavigation.checkout,
  }.contains(settings.name);
  // Connected Coach/booking views use scoped application route builders.
  // These named destinations belong to the preserved prototype contracts.
  final Widget? destination = firebase && legacyOnly
      ? const Scaffold(
          body: Center(
              child: Text('This workflow is not connected to Firebase yet.')))
      : switch (settings.name) {
          FeatureNavigation.equipment when args is GymEquipment =>
            EquipmentDetailScreen(equipment: args),
          FeatureNavigation.coach when args is Coach =>
            CoachProfileScreen(coach: args),
          FeatureNavigation.membership => const MembershipDashboardScreen(),
          FeatureNavigation.progress => firebase
              ? Builder(builder: (context) {
                  final session = context.read<AuthBloc>().state.session;
                  if (session?.role != AppRole.member) {
                    return const Scaffold(
                        body: Center(
                            child: Text(
                                'Member progress is unavailable for this account.')));
                  }
                  return MemberProgressRoute(
                      scope: session!.scope,
                      repositoryFactory: progressRepositoryFactory ??
                          createLocalMemberProgressRepository);
                })
              : const ProgressDashboardScreen(),
          FeatureNavigation.checkout when args is CheckoutArguments =>
            BillplzCheckoutScreen(
                amount: args.amount, description: args.description),
          _ => null,
        };
  if (destination == null) return null;
  return MaterialPageRoute<dynamic>(
      settings: settings,
      builder: (_) => BlocBuilder<AuthBloc, AuthState>(
          builder: (context, auth) => AuthRolePolicy.canEnter(auth,
                  allowed: const {AppRole.member, AppRole.coach})
              ? destination
              : const Scaffold(
                  body: Center(child: Text('Sign in to continue.')))));
}
