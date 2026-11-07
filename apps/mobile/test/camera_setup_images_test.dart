import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/camera_setup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('each setup step shows its matching local image at large text',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: const CameraSetupScreen()));
    for (var step = 1; step <= 4; step++) {
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image).first);
      expect((image.image as AssetImage).assetName,
          'assets/images/camera_setup/camera_setup_step_$step.png');
      expect(image.fit, BoxFit.contain);
      expect(tester.takeException(), isNull);
      if (step < 4) {
        expect(
            tester.getRect(find.text('Next')).bottom, lessThanOrEqualTo(616));
        await tester.tap(find.text('Next'));
      }
    }
    expect(find.text('Got it'), findsOneWidget);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(
        (tester.widget<Image>(find.byType(Image).first).image as AssetImage)
            .assetName,
        'assets/images/camera_setup/camera_setup_step_3.png');
  });
}
