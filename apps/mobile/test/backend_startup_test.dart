import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/main.dart' as mobile;
import 'package:gainpath_mobile/infrastructure/firebase/firebase_app_check_readiness.dart';

void main() {
  test(
      'Android Studio debug runs use the registered native App Check provider without flags',
      () async {
    String? activated;
    final readiness = FirebaseAppCheckReadiness(
        supported: true,
        activate: (mode) async {
          activated = mode;
        },
        token: () async => 'test-provider-token');
    expect(await readiness.ensureReady(), isTrue);
    expect(activated, 'debug');
  });
  testWidgets('normal launch requires no backend flag and attempts Firebase',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await mobile.main();
      await tester.pumpAndSettle();
      expect(
          find.text('Firebase is not configured for windows'), findsOneWidget);
      expect(find.text('Backend configuration required'), findsNothing);
      expect(find.byType(mobile.GainPathMobileApp), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('Firebase failure remains visible without a sample-data fallback',
      (tester) async {
    var calls = 0;
    await mobile.launchGainPathApp(initializeFirebase: () async {
      calls++;
      throw StateError('unavailable');
    });
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Firebase could not initialize'), findsOneWidget);
    expect(find.byType(mobile.GainPathMobileApp), findsNothing);
  });
}
