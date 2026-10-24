import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/main.dart' as admin;

void main() {
  testWidgets('normal launch requires no backend flag and attempts Firebase',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await admin.main();
      await tester.pumpAndSettle();
      expect(find.text('Firebase could not initialize'), findsOneWidget);
      expect(find.text('Backend configuration required'), findsNothing);
      expect(find.byType(admin.GainPathAdminWebApp), findsNothing);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
  testWidgets('Firebase failure remains visible without a sample-data fallback',
      (tester) async {
    var calls = 0;
    await admin.launchGainPathAdminApp(initializeFirebase: () async {
      calls++;
      throw StateError('unavailable');
    });
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.text('Firebase could not initialize'), findsOneWidget);
    expect(find.byType(admin.GainPathAdminWebApp), findsNothing);
  });
}
