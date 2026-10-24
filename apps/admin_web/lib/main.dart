import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'app/admin_app.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';

export 'app/admin_app.dart' show GainPathAdminWebApp;

Future<void> main() => launchGainPathAdminApp();

Future<void> launchGainPathAdminApp(
    {Future<void> Function()? initializeFirebase}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await (initializeFirebase ?? initializeGainPathFirebase)();
  } catch (_) {
    runApp(const BackendStartupErrorApp());
    return;
  }
  runApp(const GainPathAdminWebApp());
}
