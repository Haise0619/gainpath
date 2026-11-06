import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'firebase_options.dart';
import 'app/module13_demo_app.dart';
import 'infrastructure/firebase/firebase_auth_gateway.dart';
import 'infrastructure/firebase/firebase_demo_bootstrap.dart';
import 'infrastructure/firebase/firebase_demo_recommendation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final env =
        await initializeModule13DemoFirebase(DefaultFirebaseOptions.web);
    final auth = FirebaseAuthRepository(ProvisionedDemoAuthGateway(
        FlutterFirebaseAuthGateway(auth: env.auth, firestore: env.firestore),
        emulator: env.emulator));
    runApp(Module13DemoAdminApp(
        authRepository: auth,
        repositories: (session, current) => FirebaseDemoAdminRepositories(
            createFirebaseDemoAdminTransport(
                session: session,
                isCurrent: current,
                auth: env.auth,
                firestore: env.firestore,
                functions: env.functions,
                emulator: env.emulator))));
  } catch (_) {
    runApp(const MaterialApp(
        home: Scaffold(
            body: Center(
                child: Text(
                    'Controlled GainPath demo is unavailable. Verify its approved Firebase and App Check setup.')))));
  }
}
