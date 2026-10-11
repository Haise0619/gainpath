import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_mobile/main.dart' as mobile;

void main() {
  testWidgets('missing desktop Firebase settings show a useful window',
      (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await mobile.launchGainPathApp(
        backendConfig: const BackendConfig(BackendMode.firebase),
      );
      await tester.pumpAndSettle();
      expect(find.text('Firebase is not configured for windows'), findsOneWidget);
      expect(find.textContaining('flutter run -d <android-device-id>'),
          findsOneWidget);
      expect(find.textContaining('flutter run -d windows'), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
