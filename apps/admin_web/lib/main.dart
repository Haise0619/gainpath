import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'app/admin_app.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';

export 'app/admin_app.dart' show GainPathAdminWebApp;

Future<void> main() => launchGainPathAdminApp();

Future<void> launchGainPathAdminApp({BackendConfig? backendConfig}) async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = backendConfig ?? const BackendConfig(BackendMode.firebase);
  if (config.isFirebase) {
    try {
      await initializeGainPathFirebase();
    } catch (_) {}
  }
  runApp(GainPathAdminWebApp(backendConfig: config));
}
