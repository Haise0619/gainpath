import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../infrastructure/firebase/firebase_member_recommendations.dart';
import '../features/recommendation/application/recommendation_consent_repository.dart';
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
          firebaseFypDatasetTransport(session!.scope, isCurrent),
          workoutConsent: true);
  final canonical = session != null && session.datasetScope == null
      ? FirebaseMemberRecommendations(
          scope: session.scope, isCurrent: isCurrent)
      : null;
  RecommendationConsentNotice? notice;
  try {
    notice = repositories != null
        ? await repositories.notice()
        : await canonical?.notice();
  } catch (_) {
    // Existing grants can still be revoked when a reviewed new-grant notice is unavailable.
  }
  if (!context.mounted || !isCurrent()) return;
  await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalizedRecommendationSettingsScreen(
            isCurrent: isCurrent,
            repository: repositories?.consent ??
                (canonical?.enabled == true ? canonical!.consent : null),
            notice: notice),
      ));
}
