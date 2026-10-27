import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_pose/gainpath_pose.dart';
import 'package:gainpath_mobile/features/workout/application/guided_workout_progress.dart';
import 'package:gainpath_mobile/features/workout/application/real_squat_session_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_view.dart';
import 'real_squat_session_test.dart' as support;
import 'squat_processing_controller_test.dart' as poses;

class _CountingDetector extends support.Detector {
  int resets = 0;
  @override
  Future<void> reset() async {
    resets++;
    await super.reset();
  }
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    if (const bool.fromEnvironment('GAINPATH_CAPTURE_UI')) {
      for (final entry in {
        'Roboto':
            'C:/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
        'MaterialIcons':
            'build/unit_test_assets/fonts/MaterialIcons-Regular.otf',
      }.entries) {
        final loader = FontLoader(entry.key)
          ..addFont(File(entry.value).readAsBytes().then(ByteData.sublistView));
        await loader.load();
      }
    }
  });
  for (final (size, textScale) in [
    (const Size(393, 873), 1.0),
    (const Size(412, 915), 1.0),
    (const Size(320, 640), 1.0),
    (const Size(320, 640), 1.6)
  ]) {
    testWidgets(
        'camera-first sheet preserves capture at $size, text $textScale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
      final camera = support.Camera(), detector = _CountingDetector();
      final c = RealSquatSessionController(
          scope: scope,
          activeScope: () => scope,
          camera: camera,
          detectorFactory: () async => detector,
          audioPort: poses.AudioSink(),
          repository: WorkoutSessionRepository(
              scope: scope,
              store: InMemoryWorkoutSessionStore(scope: scope),
              uploadGateway: UnavailableWorkoutUploadGateway(),
              activeScope: () => scope),
          clockMicros: () => 100000,
          sessionId: 'sheet',
          exerciseId: 'squat',
          publishedRoutineId: 'published',
          detectorId: 'fixture',
          detectorVersion: '1',
          provenance: WorkoutProvenance.recordedFixture,
          guidance: GuidedWorkoutProgress(sets: 3, repetitions: 8));
      await c.start(consented: true, setupConfirmed: true);
      camera.receive!(const PoseInput(timestampMicros: 100000));
      await tester.pump();
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('workout-ui-preview'),
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      padding: const EdgeInsets.only(top: 24, bottom: 24),
                      textScaler: TextScaler.linear(textScale)),
                  child: child!),
              home: RealWorkoutView(
                  session: c,
                  viewport: const ColoredBox(
                      key: ValueKey('fake-live-camera'), color: Colors.black),
                  exerciseName: 'Bodyweight squat',
                  targetRepetitions: 8,
                  uploadNotice: 'Private upload status'))));
      await tester.pumpAndSettle();
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(
          tester.getSize(find.byKey(const ValueKey('fake-live-camera'))).height,
          size.height);
      final collapsedTop = tester
          .getTopLeft(find.byKey(const ValueKey('workout-sheet-surface')))
          .dy;
      if (textScale == 1) {
        expect(collapsedTop, greaterThanOrEqualTo(size.height * .75));
      }
      Future<void> capture(String state) async {
        if (!const bool.fromEnvironment('GAINPATH_CAPTURE_UI')) return;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const ValueKey('workout-ui-preview')));
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
              'build/module2-camera-sheet-preview/$state-${size.width.toInt()}-$textScale.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('collapsed');
      expect(find.text('Private upload status'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);
      expect(find.byTooltip('End session'), findsOneWidget);
      await tester.drag(find.byKey(const ValueKey('workout-sheet-handle')),
          Offset(0, -size.height * .60));
      await tester.pumpAndSettle();
      expect(find.text('Full reps'), findsOneWidget);
      expect(find.text('Partial reps'), findsOneWidget);
      expect(find.text('Form guidance'), findsOneWidget);
      await capture('expanded');
      expect(camera.starts, 1);
      expect(camera.stops, 0);
      expect(detector.resets, 0);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pumpAndSettle();
      expect(c.isManuallyPaused, true);
      expect(find.byTooltip('Resume / retry camera'), findsOneWidget);
      await tester.tap(find.byTooltip('Resume / retry camera'));
      await tester.pumpAndSettle();
      expect(c.isManuallyPaused, false);
      await tester.tap(find.byTooltip('Collapse workout details'));
      await tester.pumpAndSettle();
      expect(find.text('Full reps'), findsNothing);
      await tester.drag(find.byKey(const ValueKey('workout-sheet-handle')),
          Offset(0, -size.height * .60));
      await tester.pumpAndSettle();
      await tester.drag(find.byKey(const ValueKey('workout-sheet-handle')),
          Offset(0, size.height * .65));
      await tester.pumpAndSettle();
      expect(find.text('Full reps'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await c.close();
      c.dispose();
    });
  }
}
