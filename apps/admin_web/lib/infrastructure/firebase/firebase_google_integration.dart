import 'firebase_function_transport.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_data/gainpath_data.dart'
    show ScopedGoogleIntegrationRepository;

ScopedGoogleIntegrationRepository firebaseGoogleIntegration(
        SessionScope scope, bool Function() isCurrent) =>
    ScopedGoogleIntegrationRepository(
      organizationId: scope.organizationId,
      userId: scope.userId,
      isCurrent: isCurrent,
      currentUid: () => FirebaseAuth.instance.currentUser?.emailVerified == true
          ? FirebaseAuth.instance.currentUser?.uid
          : null,
      call: (name, data) async =>
          (await firebaseCallable(name).call<Map<String, dynamic>>(data)).data,
    );
