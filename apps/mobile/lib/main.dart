import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'app/mobile_app.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';

export 'app/mobile_app.dart' show GainPathMobileApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = BackendConfig.fromEnvironment();
  if (config.isFirebase) await initializeGainPathFirebase();
  runApp(GainPathMobileApp(backendConfig: config));
}
