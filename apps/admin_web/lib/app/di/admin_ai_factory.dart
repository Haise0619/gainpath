import 'package:cloud_functions/cloud_functions.dart';

import '../../features/recommendation/application/admin_ai_repository.dart';
import '../../infrastructure/firebase/firebase_function_transport.dart';

AdminAiRepository createFirebaseAdminAi({
  required String organizationId,
  required bool Function() isCurrent,
}) =>
    AdminAiRepository(
      organizationId: organizationId,
      isCurrent: isCurrent,
      invoke: (operation, data) async {
        final result = await firebaseCallable(
          'module13AdminCommand',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
        ).call<Object?>({
          'schemaVersion': 1,
          'operation': operation,
          'data': data,
        });
        return result.data;
      },
      invokeCoachPhoto: (organizationId, coachId) async {
        final result =
            await firebaseCallable('getCoachPublishedPhotoCommand').call({
          'schemaVersion': 1,
          'organizationId': organizationId,
          'coachId': coachId,
        });
        return result.data;
      },
    );
