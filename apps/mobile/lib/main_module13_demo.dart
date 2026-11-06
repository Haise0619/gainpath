import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'firebase_options.dart';
import 'app/module13_demo_app.dart';
import 'infrastructure/firebase/firebase_auth_gateway.dart';
import 'infrastructure/firebase/firebase_demo_bootstrap.dart';
import 'infrastructure/firebase/firebase_demo_recommendation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const webKey = String.fromEnvironment('MODULE13_DEMO_WEB_API_KEY');
    const options = FirebaseOptions(
        apiKey: webKey,
        appId: '1:879719977530:web:d694147dcc998025959b03',
        messagingSenderId: '879719977530',
        projectId: 'gainpath-0619',
        authDomain: 'gainpath-0619.firebaseapp.com');
    final env = await initializeModule13DemoFirebase(
        kIsWeb ? options : DefaultFirebaseOptions.currentPlatform);
    final auth = FirebaseAuthRepository(ProvisionedDemoAuthGateway(
        FlutterFirebaseAuthGateway(
            auth: env.auth, firestore: env.firestore, functions: env.functions),
        emulator: env.emulator));
    runApp(Module13DemoMemberApp(
        authRepository: auth,
        repositories: (session, current) => FirebaseDemoMemberRepositories(
            createFirebaseDemoMemberTransport(
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
