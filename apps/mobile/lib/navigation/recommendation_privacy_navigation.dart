import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../infrastructure/firebase/firebase_demo_recommendation.dart';
import 'package:flutter/material.dart';
import '../features/recommendation/presentation/member/personalized_recommendation_settings_screen.dart';

/// Canonical accounts retain the disabled preview. Verified fictional sessions
/// obtain current consent and the reviewed notice through protected operations.
Future<void> openRecommendationPrivacyPreview(
    BuildContext context, bool Function() isCurrent) async {
  if (!isCurrent()) return;
  AuthBloc? auth;
  try {
    auth = context.read<AuthBloc>();
  } catch (_) {/* Preview can stand alone. */}
  final session = auth?.state.session;
  final repositories = session?.datasetScope == null
      ? null
      : FirebaseDemoMemberRepositories(
          firebaseFypDatasetTransport(session!.scope, isCurrent));
  final notice = await repositories?.notice();
  if (!context.mounted || !isCurrent()) return;
  await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalizedRecommendationSettingsScreen(
            isCurrent: isCurrent,
            repository: repositories?.consent,
            notice: notice),
      ));
}
