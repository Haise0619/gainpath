import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'package:gainpath_mobile/features/workout/application/shoulder_press_workout_session.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'shoulder_press_session_test.dart' show PressHarness;
import 'workout_voice_readiness_test.dart' show RetryAudio;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final scale in [1.0, 1.5]) {
    testWidgets(
        'voice preparation failure and explicit retry remain visible at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final h = PressHarness(), port = RetryAudio();
      final c = ShoulderPressWorkoutSession(
          scope: h.scope,
          activeScope: () => h.active,
          camera: h.camera,
          detectorFactory: () async => h.detector,
          audioPort: port,
          repository: h.repo,
          clockMicros: () => h.now,
          sessionId: 'voice-ui',
          exerciseId: 'dumbbell-shoulder-press-front-v1',
          publishedRoutineId: 'routine',
          detectorId: 'synthetic-press',
          detectorVersion: '1',
          sets: 1,
          reps: 5,
          provenance: WorkoutProvenance.recordedFixture);
      await c.start(consented: true, setupConfirmed: true);
      c.audio.setVoiceEnabled(true);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: RealWorkoutView(
              session: c,
              viewport: const SizedBox(),
              exerciseName: 'Shoulder Press',
              targetRepetitions: 5)));
      expect(find.text('Voice preparing · visual feedback active'),
          findsOneWidget);
      port.ready.complete(false);
      await tester.pump();
      expect(find.text('Voice unavailable · visual feedback active'),
          findsOneWidget);
      await tester.tap(find.byTooltip('Retry voice feedback'));
      await tester.pump();
      expect(port.retries, 1);
      port.ready.complete(true);
      await tester.pump();
      expect(find.text('Voice ready'), findsOneWidget);
      expect(port.played, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.close();
      c.dispose();
      h.dispose();
    });
  }
}
