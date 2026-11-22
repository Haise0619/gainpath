import '../../infrastructure/firebase/firebase_unified_admin.dart';
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_data/gainpath_data.dart' show Module13DemoUnavailable;
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import '../../features/recommendation/application/canonical_admin_recommendation_repository.dart';

typedef CanonicalAdminRecommendationFactory
    = CanonicalAdminRecommendationRepository? Function(
        AuthSession session, bool Function() isCurrent);

bool _canRetryLegacyList(Object error) =>
    error is Module13DemoUnavailable ||
    (error is FirebaseFunctionsException && error.code == 'invalid-argument');

/// The client flag only admits the server access probe. Server policy remains
/// authoritative and disabled until its reviewed runtime is supplied.
CanonicalAdminRecommendationRepository? createCanonicalAdminRecommendations(
  AuthSession session,
  bool Function() isCurrent, {
  bool enabled = const bool.fromEnvironment('GAINPATH_RECOMMENDATIONS_ENABLED'),
  CanonicalAdminInvoke? invoke,
  String? Function()? currentUid,
}) {
  if (!enabled || session.role != AppRole.admin) {
    return null;
  }
  if (session.datasetScope != null && enabled) {
    final transport = firebaseFypDatasetTransport(session.scope, isCurrent);
    return CanonicalAdminRecommendationRepository(
        organizationId: session.scope.organizationId,
        isCurrent: isCurrent,
        canRetryLegacyList: _canRetryLegacyList,
        invoke: invoke ??
            (operation, data) => transport.call('workout.$operation', data));
  }
  final uid = currentUid ?? () => FirebaseAuth.instance.currentUser?.uid;
  return CanonicalAdminRecommendationRepository(
      organizationId: session.scope.organizationId,
      isCurrent: () => isCurrent() && uid() == session.scope.userId,
      canRetryLegacyList: _canRetryLegacyList,
      invoke: invoke ??
          (operation, data) => UnifiedAdminTransport(
                      scope: session.scope,
                      isCurrent: isCurrent,
                      currentUid: uid)
                  .read('recommendations', {
                'operation': operation,
                'input': data,
              }));
}
