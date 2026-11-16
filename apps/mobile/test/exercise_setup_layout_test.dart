import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/shoulder_press_setup_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'front setup keeps camera action reachable at 320px and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: ShoulderPressSetupScreen(
            exerciseName: 'Long shoulder press exercise name',
            sets: 1,
            reps: 1,
            restSeconds: 60,
            onStart: () => starts++)));
    expect(find.text('Front camera view required'), findsOneWidget);
    expect(find.textContaining('1 set × 1 rep'), findsOneWidget);
    expect(tester.getRect(find.text('Start camera')).bottom,
        lessThanOrEqualTo(616));
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Start camera'));
    await tester.pump();
    expect(starts, 1);
  });
}
