import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:gainpath_data/gainpath_data.dart';

class Module13DemoFirebase {
  const Module13DemoFirebase(
      this.auth, this.firestore, this.functions, this.emulator);
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final bool emulator;
}

Future<Module13DemoFirebase> initializeModule13DemoFirebase(
    FirebaseOptions liveOptions) async {
  if (!const bool.fromEnvironment('MODULE13_DEMO_EMULATOR')) {
    throw StateError(
        'The separate Module 13 live demo architecture is superseded. Use the ordinary GainPath application.');
  }
  const emulator = bool.fromEnvironment('MODULE13_DEMO_EMULATOR');
  const liveApproved = bool.fromEnvironment('MODULE13_DEMO_ENABLE_LIVE');
  if (!emulator && !liveApproved) {
    throw StateError(
        'The controlled real-project demo has not been activated.');
  }
  if (!emulator && liveOptions.projectId != 'gainpath-0619') {
    throw StateError('Unexpected demo project.');
  }
  final app = await Firebase.initializeApp(
      name: 'gainpath-controlled-module13',
      options: emulator
          ? const FirebaseOptions(
              apiKey: 'emulator-only-key',
              appId: 'emulator-only-app',
              messagingSenderId: '000000',
              projectId: 'demo-gainpath-module13-demo',
              authDomain: 'localhost')
          : liveOptions);
  final auth = FirebaseAuth.instanceFor(app: app),
      db = FirebaseFirestore.instanceFor(app: app, databaseId: 'module13-demo'),
      functions =
          FirebaseFunctions.instanceFor(app: app, region: 'asia-southeast1');
  if (emulator) {
    await auth.useAuthEmulator('127.0.0.1', 19099);
    db.useFirestoreEmulator('127.0.0.1', 18119);
    functions.useFunctionsEmulator('127.0.0.1', 15019);
    const uid = String.fromEnvironment('MODULE13_DEMO_EMULATOR_UID');
    if (uid.isNotEmpty) {
      if (!RegExp(r'^demo-m13-(admin|coach-0[1-8]|member-(0[1-9]|1[0-8]))$')
          .hasMatch(uid)) {
        throw StateError('Designated fictional emulator account required.');
      }
      String part(Object value) =>
          base64UrlEncode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
      await auth.signInWithCustomToken(
          '${part({'alg': 'none', 'typ': 'JWT'})}.${part({
            'uid': uid,
            'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000
          })}.');
    }
  } else {
    if (const String.fromEnvironment('MODULE13_DEMO_EMULATOR_UID') != '') {
      throw StateError(
          'Emulator identity injection cannot be used in the real project.');
    }
    if (kIsWeb) {
      const mode = String.fromEnvironment('APP_CHECK_MODE'),
          site = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY'),
          debug = String.fromEnvironment('APP_CHECK_WEB_DEBUG_TOKEN');
      final WebProvider provider;
      if (mode == 'production' && site.isNotEmpty) {
        provider = ReCaptchaV3Provider(site);
      } else if (mode == 'debug' && debug.isNotEmpty) {
        provider = WebDebugProvider(debugToken: debug);
      } else {
        throw StateError(
            'An existing approved App Check provider is required.');
      }
      await FirebaseAppCheck.instanceFor(app: app)
          .activate(providerWeb: provider);
    } else {
      await FirebaseAppCheck.instanceFor(app: app)
          .activate(providerAndroid: const AndroidPlayIntegrityProvider());
    }
  }
  return Module13DemoFirebase(auth, db, functions, emulator);
}

/// Registration/reset flows are outside this isolated demo composition. Normal
/// application self-registration is untouched. No new live emails are sent.
class ProvisionedDemoAuthGateway
    implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  ProvisionedDemoAuthGateway(this.delegate, {required this.emulator});
  final FirebaseAuthGateway delegate;
  final bool emulator;
  @override
  Future<FirebaseAuthUser> signIn(
          {required String email, required String password}) =>
      delegate.signIn(email: email, password: password);
  @override
  Future<FirebaseAuthUser> register(
          {required String email,
          required String password,
          required String name}) =>
      Future.error(const AuthException(
          'Demo accounts must be provisioned by the approved seed process.'));
  @override
  Future<void> sendEmailVerification() => emulator
      ? delegate.sendEmailVerification()
      : Future.error(
          const AuthException('Use the designated verified demo account.'));
  @override
  Future<void> signOut() => delegate.signOut();
  @override
  Stream<FirebaseAuthUser?> get userChanges =>
      (delegate as FirebaseAuthSessionGateway).userChanges;
  @override
  Future<FirebaseAuthUser?> restoreUser() =>
      (delegate as FirebaseAuthSessionGateway).restoreUser();
}
