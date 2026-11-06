import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'firebase_function_transport.dart';

FypDatasetTransport firebaseFypDatasetTransport(
        SessionScope scope, bool Function() isCurrent) =>
    FypDatasetTransport(
        scope: scope,
        isCurrent: () =>
            isCurrent() &&
            FirebaseAuth.instance.currentUser?.uid == scope.userId &&
            FirebaseAuth.instance.currentUser?.emailVerified == true,
        invoke: (name, data) async =>
            (await firebaseCallable(name).call<Object?>(data)).data);
