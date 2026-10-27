import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/domain/curl_arm_metrics.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/curl_arm_setup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'small-screen setup chooses right-only without starting capture early',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    CurlArmMode? mode;
    CurlSide? side;
    await tester.pumpWidget(MaterialApp(
        home: CurlArmSetupScreen(
            exerciseName: 'Standing single-arm dumbbell curl',
            sets: 2,
            reps: 5,
            onStart: (m, s) {
              mode = m;
              side = s;
            })));
    expect(mode, isNull);
    expect(find.text('5 reps per arm per set'), findsOneWidget);
    await tester.tap(find.text('Right only'));
    await tester.pump();
    await tester.ensureVisible(find.text('Start camera'));
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(mode, CurlArmMode.rightOnly);
    expect(side, CurlSide.right);
    expect(tester.takeException(), isNull);
  });
  testWidgets('both-arm setup permits starting with the right arm',
      (tester) async {
    CurlArmMode? mode;
    CurlSide? side;
    await tester.pumpWidget(MaterialApp(
        home: CurlArmSetupScreen(
            exerciseName: 'Curl',
            sets: 1,
            reps: 5,
            onStart: (m, s) {
              mode = m;
              side = s;
            })));
    await tester.tap(find.text('Right arm'));
    await tester.pump();
    await tester.tap(find.text('Start camera'));
    expect(mode, CurlArmMode.both);
    expect(side, CurlSide.right);
  });
}
