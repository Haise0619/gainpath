import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/application/between_exercise_rest_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/between_exercise_rest_screen.dart';
import 'package:gainpath_mobile/app/routing/between_exercise_rest_route.dart';
import 'published_tutorial_test.dart' show row;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('invalidated workout context disables continuation permanently',
      (tester) async {
    var allowed = true;
    await tester.pumpWidget(MaterialApp(
        home: BetweenExerciseRestRoute(
            previousExercise: 'Squat',
            upcomingExercise: row(),
            organizationId: 'gainpath',
            restSeconds: 30,
            canAdvance: () => allowed)));
    await tester.pump(const Duration(milliseconds: 100));
    allowed = false;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Workout interrupted'), findsOneWidget);
    final skip = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Skip Rest'));
    expect(skip.onPressed, isNull);
    allowed = true;
    await tester.pump(const Duration(milliseconds: 100));
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Skip Rest'))
            .onPressed,
        isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'rest route stays paused after foreground return and explicit skip returns advance',
      (tester) async {
    BetweenExerciseRestOutcome? outcome;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      outcome =
                          await Navigator.push<BetweenExerciseRestOutcome>(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => BetweenExerciseRestRoute(
                                      previousExercise: 'Squat',
                                      upcomingExercise: row(),
                                      organizationId: 'gainpath',
                                      restSeconds: 30,
                                      canAdvance: () => true)));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Resume Workout'), findsOneWidget);
    expect(outcome, isNull);
    await tester.tap(find.text('Skip Rest'));
    await tester.pumpAndSettle();
    expect(outcome, BetweenExerciseRestOutcome.advance);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'rest controls remain visible at 200 percent text on small screen',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => Duration.zero,
        canAdvance: () => true,
        onReady: () async {});
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
                padding: const EdgeInsets.only(bottom: 24)),
            child: child!),
        home: BetweenExerciseRestScreen(
            controller: c,
            previousExercise: 'Standing Lateral Raise',
            upcomingExercise: row(),
            organizationId: 'gainpath',
            onViewRoutine: () {})));
    expect(find.text('Pause Workout'), findsOneWidget);
    expect(find.text('Skip Rest'), findsOneWidget);
    expect(tester.getBottomRight(find.text('Skip Rest')).dy, lessThan(616));
    await tester.tap(find.text('Pause Workout'));
    await tester.pump();
    expect(find.text('Resume Workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });
  test('rest advances once only after countdown and readiness', () async {
    var now = Duration.zero, advances = 0;
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => now,
        canAdvance: () => true,
        onReady: () async {
          advances++;
        });
    now = const Duration(seconds: 29);
    await c.tick();
    expect(c.remainingSeconds, 1);
    expect(advances, 0);
    now = const Duration(seconds: 30);
    await Future.wait([c.tick(), c.tick(), c.skip()]);
    expect(advances, 1);
    expect(c.phase, BetweenExerciseRestPhase.preparing);
    c.dispose();
  });
  test('interruption pauses and explicit resume excludes elapsed absence',
      () async {
    var now = Duration.zero, allowed = true, advances = 0;
    final c = BetweenExerciseRestController(
        duration: const Duration(seconds: 30),
        monotonicNow: () => now,
        canAdvance: () => allowed,
        onReady: () async {
          advances++;
        });
    now = const Duration(seconds: 10);
    c.interrupt();
    allowed = false;
    now = const Duration(minutes: 5);
    await c.tick();
    expect(c.remainingSeconds, 20);
    allowed = true;
    await c.tick();
    expect(c.phase, BetweenExerciseRestPhase.paused);
    c.resume();
    now += const Duration(seconds: 20);
    await c.tick();
    expect(advances, 1);
    c.dispose();
  });
  test('skip cannot advance while blocked or after cancellation', () async {
    var allowed = false, advances = 0;
    final c = BetweenExerciseRestController(
        duration: Duration.zero,
        monotonicNow: () => Duration.zero,
        canAdvance: () => allowed,
        onReady: () async {
          advances++;
        });
    await c.skip();
    expect(advances, 0);
    allowed = true;
    c.cancel();
    await c.skip();
    expect(advances, 0);
    c.dispose();
  });
}
