import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import '../../features/recommendation/application/canonical_admin_recommendation_repository.dart';
import '../../infrastructure/firebase/firebase_function_transport.dart';

typedef CanonicalAdminRecommendationFactory
    = CanonicalAdminRecommendationRepository? Function(
        AuthSession session, bool Function() isCurrent);

/// The client flag only admits the server access probe. Server policy remains
/// authoritative and disabled until its reviewed runtime is supplied.
CanonicalAdminRecommendationRepository? createCanonicalAdminRecommendations(
  AuthSession session,
  bool Function() isCurrent, {
  bool enabled = const bool.fromEnvironment('GAINPATH_RECOMMENDATIONS_ENABLED'),
  CanonicalAdminInvoke? invoke,
  String? Function()? currentUid,
}) {
  if (!enabled ||
      session.datasetScope != null ||
      session.role != AppRole.admin) {
    return null;
  }
  final uid = currentUid ?? () => FirebaseAuth.instance.currentUser?.uid;
  return CanonicalAdminRecommendationRepository(
      organizationId: session.scope.organizationId,
      isCurrent: () => isCurrent() && uid() == session.scope.userId,
      invoke: invoke ??
          (operation, data) async =>
              (await firebaseCallable('module13AdminCommand').call<Object?>({
                'schemaVersion': 1,
                'operation': operation,
                'data': data
              }))
                  .data);
}
