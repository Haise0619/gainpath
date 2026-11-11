import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/measured_workout_session.dart';
import 'package:gainpath_mobile/features/workout/application/pose_preview_controller.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_audio_port.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'package:gainpath_pose/gainpath_pose.dart';

import 'real_squat_session_test.dart' show Camera, Detector;
import 'workout_voice_readiness_test.dart' show RetryAudio;

final _scope = SessionScope(userId: 'member', organizationId: 'gainpath');
const _cameraKey = ValueKey('live-camera');
const _counterKey = ValueKey('workout-rep-counter');

class _SlowClosingCamera extends Camera {
  final released = Completer<void>();

  @override
  Future<void> stop() async {
    await super.stop();
    await released.future;
  }
}

class _SquatFixture extends RealSquatSessionController {
  _SquatFixture(Camera camera, Detector detector, RetryAudio audio)
      : super(
            scope: _scope,
            activeScope: () => _scope,
            camera: camera,
            detectorFactory: () async => detector,
            audioPort: audio,
            repository: WorkoutSessionRepository(
                scope: _scope,
                store: InMemoryWorkoutSessionStore(scope: _scope),
                uploadGateway: UnavailableWorkoutUploadGateway(),
                activeScope: () => _scope),
            clockMicros: () => 100000,
            sessionId: 'live-camera-accessibility',
            exerciseId: 'squat',
            publishedRoutineId: 'routine',
            detectorId: 'fixture',
            detectorVersion: '1',
            provenance: WorkoutProvenance.recordedFixture,
            guidance: GuidedWorkoutProgress(sets: 3, repetitions: 8));

  WorkoutAnalysisView? fixtureAnalysis;

  @override
  WorkoutAnalysisView? get analysis => fixtureAnalysis;

  @override
  bool get analysisAvailable => fixtureAnalysis != null;

  void update({TrackingStatus health = TrackingStatus.healthy}) {
    fixtureAnalysis = WorkoutAnalysisView(
        repetitions: 0,
        partialRepetitions: 0,
        trackedDurationMicros: 0,
        rejectedDurationMicros: 0,
        formScorePercent: null,
        needsCalibration: false,
        health: health,
        cues: const [
          CueRequest(
              id: 'good',
              text: 'Good work',
              priority: CuePriority.encouragement),
          CueRequest(
              id: 'depth',
              text: 'Lower with control',
              priority: CuePriority.correction),
        ]);
    notifyListeners();
  }

  void cameraPhase(PosePreviewPhase phase) {
    preview.phase = phase;
    notifyListeners();
  }
}

Future<void> _mount(WidgetTester tester, _SquatFixture session, Size size,
    double scale, EdgeInsets safe) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await session.start(consented: true, setupConfirmed: true);
  await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              padding: safe,
              viewPadding: safe,
              textScaler: TextScaler.linear(scale)),
          child: child!),
      home: RealWorkoutView(
          session: session,
          viewport: const ColoredBox(key: _cameraKey, color: Colors.black),
          exerciseName: 'Bodyweight squat',
          targetRepetitions: 8)));
}

void main() {
  testWidgets('calibrated live Squat announces Ready once in Full Coaching',
      (tester) async {
    final audio = RetryAudio()..ready.complete(true);
    final session = _SquatFixture(Camera(), Detector(), audio);
    await _mount(tester, session, const Size(360, 720), 1, EdgeInsets.zero);
    session.setVoiceMode(WorkoutVoiceMode.fullCoaching, persist: false);
    await tester.pump();
    expect(audio.played, isEmpty);
    session.update();
    await tester.pump();
    expect(audio.played.map((cue) => cue.text), ['Ready.']);
    session.update();
    await tester.pump();
    expect(audio.played, hasLength(1));
    await tester.pumpWidget(const SizedBox());
    await session.close();
    session.dispose();
  });

  for (final control in ['Back', 'Stop', 'System back']) {
    testWidgets('$control can leave Squat while unavailable camera closes',
        (tester) async {
      final camera = _SlowClosingCamera();
      final session = _SquatFixture(camera, Detector(), RetryAudio());
      await session.start(consented: true, setupConfirmed: true);
      session.cameraPhase(PosePreviewPhase.failure);
      await tester.pumpWidget(MaterialApp(
          home: Builder(builder: (context) {
        return Scaffold(
            body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                        builder: (_) => RealWorkoutView(
                            session: session,
                            viewport: const SizedBox(),
                            exerciseName: 'Squat',
                            targetRepetitions: 8))),
                child: const Text('Open Squat')));
      })));
      await tester.tap(find.text('Open Squat'));
      await tester.pumpAndSettle();
      expect(find.text('CAMERA UNAVAILABLE'), findsOneWidget);
      if (control == 'System back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(
            control == 'Back' ? find.byTooltip(control) : find.text(control));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave exercise'));
      await tester.pumpAndSettle();
      expect(find.text('Open Squat'), findsOneWidget);
      expect(camera.released.isCompleted, isFalse);
      expect(session.viewPhase, MeasuredWorkoutPhase.closed);
      camera.released.complete();
      await tester.pump();
      session.dispose();
    });
  }

  testWidgets('rest time and manual controls fit 320px at 200% text',
      (tester) async {
    final session = _SquatFixture(Camera(), Detector(), RetryAudio());
    await _mount(tester, session, const Size(320, 640), 2,
        const EdgeInsets.only(top: 24, bottom: 24));
    session.cameraPhase(PosePreviewPhase.tracking);
    session.setRestSeconds(20);
    session.guidance!.observe(8, nowMicros: 100000);
    session.update();
    await tester.pumpAndSettle();
    expect(find.text('REST'), findsOneWidget);
    final counter = tester.widget<Text>(find.byKey(_counterKey));
    expect(counter.textSpan!.toPlainText(), '20 s');
    expect(find.byTooltip('Skip rest & start set 2'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Pause'));
    await tester.pumpAndSettle();
    expect(find.text('PAUSED'), findsOneWidget);
    expect(find.byTooltip('Resume / retry camera'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await session.close();
    session.dispose();
  });

  for (final shortSide in [320.0, 360.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final landscape in [false, true]) {
        testWidgets(
            'live controls fit $shortSide, $scale×, landscape=$landscape',
            (tester) async {
          final size = landscape ? Size(640, shortSide) : Size(shortSide, 640);
          final safe = landscape
              ? const EdgeInsets.fromLTRB(24, 0, 16, 20)
              : const EdgeInsets.fromLTRB(0, 24, 0, 24);
          final session = _SquatFixture(Camera(), Detector(), RetryAudio());
          await _mount(tester, session, size, scale, safe);
          session.cameraPhase(PosePreviewPhase.tracking);
          session.update();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          final previewSize = tester.getSize(find.byKey(_cameraKey));
          expect(previewSize.height, size.height);
          if (landscape) {
            expect(previewSize.width, lessThan(size.width));
          } else {
            expect(previewSize.width, size.width);
          }
          expect(find.text('READY'), findsOneWidget);
          expect(find.text('Lower with control'), findsOneWidget);
          expect(find.text('Good work'), findsNothing);
          expect(find.text('SET 1 / 3'), findsOneWidget);
          final counter = find.byKey(_counterKey);
          expect(tester.widget<Text>(counter).style!.fontSize,
              greaterThanOrEqualTo(36));
          final usable = Rect.fromLTRB(safe.left, safe.top,
              size.width - safe.right, size.height - safe.bottom);
          final status = tester.getRect(find.text('READY'));
          for (final control in [
            find.byTooltip('Pause'),
            find.byTooltip('End session')
          ]) {
            expect(usable.contains(tester.getTopLeft(control)), isTrue);
            expect(
                usable.contains(
                    tester.getBottomRight(control) - const Offset(.1, .1)),
                isTrue);
            expect(status.overlaps(tester.getRect(control)), isFalse);
            if (landscape) {
              expect(
                  tester
                      .getRect(find.byKey(_cameraKey))
                      .overlaps(tester.getRect(control)),
                  isFalse);
            }
            expect(tester.getSize(control).height, greaterThanOrEqualTo(48));
          }

          await tester.tap(find.byTooltip('Expand workout details'));
          await tester.pumpAndSettle();
          expect(find.text('Full reps'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.tap(find.byTooltip('Collapse workout details'));
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Pause'));
          await tester.pumpAndSettle();
          expect(find.text('PAUSED'), findsOneWidget);
          expect(find.text('Resume'), findsOneWidget);
          await tester.tap(find.byTooltip('Resume / retry camera'));
          await tester.pumpAndSettle();
          expect(session.isManuallyPaused, isFalse);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await session.close();
          session.dispose();
        });
      }
    }
  }

  testWidgets('opening, camera failure, tracking loss and voice retry at 200%',
      (tester) async {
    final camera = Camera(), audio = RetryAudio();
    final session = _SquatFixture(camera, Detector(), audio);
    await _mount(tester, session, const Size(320, 640), 2,
        const EdgeInsets.only(top: 24, bottom: 24));
    session.cameraPhase(PosePreviewPhase.opening);
    await tester.pump();
    expect(find.text('OPENING CAMERA'), findsOneWidget);
    session.preview.errorMessage = 'Camera could not start.';
    session.cameraPhase(PosePreviewPhase.failure);
    await tester.pump();
    expect(find.text('CAMERA UNAVAILABLE'), findsOneWidget);
    expect(find.text('Camera could not start.'), findsOneWidget);
    await tester.tap(find.byTooltip('Resume / retry camera'));
    await tester.pump();
    session.preview.errorMessage = null;
    session.cameraPhase(PosePreviewPhase.tracking);
    session.update(health: TrackingStatus.lost);
    await tester.pump();
    expect(find.text('TRACKING LOST'), findsOneWidget);
    expect(
        find.textContaining('shoulder, hip, knee and ankle'), findsOneWidget);
    expect(find.text('Lower with control'), findsNothing);

    session.processing.audio.setVoiceEnabled(true);
    await tester.pump();
    expect(
        find.text('Voice preparing · visual feedback active'), findsOneWidget);
    audio.ready.complete(false);
    await tester.pump();
    expect(find.text('Voice unavailable · visual feedback active'),
        findsOneWidget);
    await tester.tap(find.byTooltip('Retry voice feedback'));
    await tester.pump();
    expect(audio.retries, 1);
    audio.ready.complete(true);
    await tester.pump();
    expect(find.text('Voice ready'), findsOneWidget);
    session.processing.audio.setVoiceEnabled(false);
    await tester.pump();
    expect(find.text('Voice ready'), findsNothing);
    expect(find.text('TRACKING LOST'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await session.close();
    session.dispose();
  });
}
