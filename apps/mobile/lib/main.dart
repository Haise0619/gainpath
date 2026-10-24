import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'app/mobile_app.dart';
import 'infrastructure/firebase/firebase_bootstrap.dart';

export 'app/mobile_app.dart' show GainPathMobileApp;

Future<void> main() => launchGainPathApp();

Future<void> launchGainPathApp(
    {Future<void> Function()? initializeFirebase}) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await (initializeFirebase ?? initializeGainPathFirebase)();
  } on UnsupportedError {
    runApp(FirebaseSetupRequiredApp(platform: defaultTargetPlatform.name));
    return;
  } catch (_) {
    runApp(const BackendStartupErrorApp());
    return;
  }
  runApp(const GainPathMobileApp());
}

/// Keep a visible explanation when Firebase has no configuration for the
/// selected desktop or mobile platform. Never switch silently to demo data.
class FirebaseSetupRequiredApp extends StatelessWidget {
  const FirebaseSetupRequiredApp({super.key, required this.platform});

  final String platform;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'GainPath setup required',
        home: Scaffold(
          appBar: AppBar(title: const Text('GainPath')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.phonelink_erase, size: 48),
                    const SizedBox(height: 16),
                    Text('Firebase is not configured for $platform',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 12),
                    const Text(
                      'This project currently has Android Firebase settings. '
                      'Select an Android device to use the connected app.',
                    ),
                    const SizedBox(height: 16),
                    const SelectableText(
                      'flutter run -d <android-device-id>',
                    ),
                    const SizedBox(height: 24),
                    const Text(
                        'GainPath uses connected account data. No sample-account fallback is enabled.'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
