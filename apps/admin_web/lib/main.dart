import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'app/admin_app.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';

export 'app/admin_app.dart' show GainPathAdminWebApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = BackendConfig.fromEnvironment();
  if (config.isFirebase) await initializeGainPathFirebase();
  runApp(GainPathAdminWebApp(backendConfig: config));
}
