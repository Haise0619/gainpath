import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/workout/application/routine_journey_controller.dart';
import 'package:gainpath_mobile/features/workout/data/workout_session_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/guided_timed_progress.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_journey.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_plan_signature.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_journey_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/workout_save_indicator.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore, measured;
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

import '../../../test_support/member_demo_render_fonts.dart'
    show flutterTestFontPath;

const _render = bool.fromEnvironment('GAINPATH_RENDER_COMPLETION');
const _image = 'assets/images/workout_hub_fallback.png';

Future<RoutineJourneyController> completionFixture(
    {bool long = false, bool partial = false}) async {
  final scope =
      SessionScope(userId: 'completion-fixture', organizationId: 'gainpath');
  final start = DateTime.utc(2026, 11, 15, 10, 6),
      end = DateTime.utc(2026, 11, 15, 10, 8);
  const media = 'https://example.com/workout.mp4';
  final routine = PublishedRoutine(
      id: 'routine',
      sourceBlueprintId: 'blueprint',
      title: long
          ? 'Full Body Strength, Mobility and Recovery — Weekend Training Session'
          : 'Full Body Foundations',
      estimatedMinutes: 10,
      schemaVersion: 2,
      exercises: [
        PublishedRoutineExercise(
            exerciseId: 'burpee',
            dayNumber: 1,
            name: long
                ? 'Burpee with a controlled full-body reach and reset'
                : 'Burpee',
            category: 'Cardio',
            sets: 1,
            reps: null,
            cue: '',
            imageUrl: _image,
            muscleGroup: 'Full body',
            entryId: 'timed',
            executionMode: ExerciseExecutionMode.videoGuidedTimed,
            durationSeconds: 40,
            videoUrl: media,
            mediaRevision: 1,
            mediaGeneration: '1',
            mediaValidation: const {
              'schemaVersion': 1,
              'videoUrl': media,
              'sourceRevision': 1,
              'generation': '1',
              'contentType': 'video/mp4'
            }),
        PublishedRoutineExercise(
            exerciseId: 'F3b8xIr8ynBDd3gEICKX',
            dayNumber: 1,
            name: long
                ? 'Bodyweight Squat — controlled range of motion'
                : 'Squat',
            category: 'Strength',
            sets: 1,
            reps: 3,
            cue: '',
            imageUrl: _image,
            muscleGroup: 'Legs',
            entryId: 'ai',
            executionMode: ExerciseExecutionMode.aiTracked),
      ]);
  final progress = GuidedTimedProgress(
      runId: 'timed-run',
      entryId: 'timed',
      entryIndex: 0,
      exerciseId: 'burpee',
      prescription: routine.exercises[0].prescription as TimedPrescription,
      mediaIdentity: guidedTimedMediaIdentity(
          videoUrl: media, mediaRevision: 1, mediaGeneration: '1'),
      startedAt: start,
      updatedAt: end,
      endedAt: end,
      phase: GuidedTimedPhase.completed,
      completedSetActiveMicroseconds: const [40000000]);
  final a = RoutineAttempt(
      id: 'completed-ui',
      scope: scope,
      routine: routine,
      day: 1,
      finished: true,
      startedAtMicros: start.microsecondsSinceEpoch,
      finishedAtMicros: end.microsecondsSinceEpoch,
      updatedAtMicros: end.microsecondsSinceEpoch,
      entries: [
        RoutineExerciseResult.timed(
            index: 0,
            status: RoutineExerciseStatus.timerCompleted,
            guided: progress),
        RoutineExerciseResult(
            index: 1,
            status: partial
                ? RoutineExerciseStatus.skipped
                : RoutineExerciseStatus.completed,
            sessionIds: partial ? [] : ['camera'],
            fullRepetitions: partial ? 0 : 3,
            partialRepetitions: 0,
            trackedDurationMicros: partial ? 0 : 8000000,
            manualSets: 0),
      ]);
  final store = MemoryJourneyStore(scope);
  await store.save(RoutineCheckpoint(
      id: a.id,
      scope: scope,
      routineId: routine.id,
      planSignature: routinePlanSignature(routine),
      day: 1,
      selectedIndex: 1,
      updatedAtMicros: a.updatedAtMicros,
      startedAtMicros: a.startedAtMicros,
      finished: true,
      attempt: a,
      guidedProgress: {0: progress},
      sessions: partial
          ? {}
          : {
              1: ['camera']
            },
      skipped: partial ? {1} : {}));
  final workouts = WorkoutSessionRepository(
      scope: scope,
      activeScope: () => scope,
      store: InMemoryWorkoutSessionStore(scope: scope),
      uploadGateway: UnavailableWorkoutUploadGateway());
  if (!partial) await workouts.saveLocal(measured(scope, 'camera', reps: 3));
  final c = RoutineJourneyController(
      scope: scope,
      activeScope: () => scope,
      routine: routine,
      store: store,
      workouts: workouts,
      newId: () => 'next-attempt');
  await c.openAttempt(a.id);
  return c;
}

void main() {
  for (final (size, scale, long, partial, name) in [
    (const Size(390, 844), 1.0, false, false, 'portrait'),
    (const Size(320, 640), 1.0, true, false, 'small-long'),
    (const Size(320, 640), 2.0, true, false, 'large-text'),
    (const Size(844, 390), 1.0, false, false, 'landscape'),
    (const Size(390, 844), 1.0, false, true, 'partial'),
  ]) {
    testWidgets('completion layout, expansion and truthful rewards: $name',
        (tester) async {
      if (_render) {
        final restore = await tester.runAsync(installFypOfflineFonts);
        addTearDown(restore!);
        await tester.runAsync(() async {
          for (final (family, path) in [
            ('MaterialIcons', flutterTestFontPath('MaterialIcons-Regular.otf')),
            ('Barlow', 'assets/fonts/Barlow-Regular.ttf'),
            ('BarlowCondensed', 'assets/fonts/BarlowCondensed-Regular.ttf'),
          ]) {
            await (FontLoader(family)
                  ..addFont(
                      File(path).readAsBytes().then(ByteData.sublistView)))
                .load();
          }
          final codec =
              await ui.instantiateImageCodec(await File(_image).readAsBytes());
          final frame = await codec.getNextFrame();
          final key = await const AssetImage(_image)
              .obtainKey(ImageConfiguration.empty);
          PaintingBinding.instance.imageCache.putIfAbsent(
              key,
              () => OneFrameImageStreamCompleter(
                  Future.value(ImageInfo(image: frame.image))));
          codec.dispose();
        });
      }
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await completionFixture(long: long, partial: partial);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: _render ? buildMemberTypographyTheme() : ThemeData(),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  padding: const EdgeInsets.only(top: 24, bottom: 24)),
              child: child!),
          home: RepaintBoundary(
              key: key,
              child: RoutineJourneyScreen(
                  controller: c,
                  onTrack: (_) async {},
                  onTutorial: (_) async {},
                  onViewHistory: () {},
                  onOpenSettings: () {},
                  saveStatusBuilder: (_) => const WorkoutSaveIndicator(
                      status: BackupRecordStatus.backedUp)))));
      await tester.pumpAndSettle();
      Future<void> capture(String suffix) async {
        if (!_render) return;
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('build/workout-completion-visuals')
            ..createSync(recursive: true);
          await File('${dir.path}/$name-$suffix.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('hero');
      final exerciseName = c.routine.exercises[0].name;
      await tester.scrollUntilVisible(
          find.text(exerciseName).hitTestable(), 150);
      await tester.pumpAndSettle();
      await capture('exercises');
      await tester.tap(find.text(exerciseName));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find
              .text('Timer recorded. Repetitions and form were not assessed.')
              .hitTestable(),
          100);
      expect(
          find.text('Timer recorded. Repetitions and form were not assessed.'),
          findsOneWidget);
      await tester.scrollUntilVisible(
          find.text('Workout rewards · Not active').hitTestable(), 150);
      await tester.pumpAndSettle();
      await capture('rewards');
      expect(
          find.text(
              'This workout does not add redeemable points. You can still progress toward training badges.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });
  }
}
