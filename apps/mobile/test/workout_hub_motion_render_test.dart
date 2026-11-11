import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/app_check_in_dashboard.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'app_check_in_test.dart' show snapshotJson;
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;
import 'workout_hub_redesign_test.dart' show hubRoutine;

ScheduledWorkoutPreview hubScheduled(int completed) {
  final routine = hubRoutine('scheduled');
  return ScheduledWorkoutPreview(
      routine: routine,
      day: 1,
      dayKey: 'day-1',
      enrollmentId: 'enrollment',
      date: DateTime.utc(2026, 11, 12),
      snapshot: 'snapshot',
      inProgress: completed > 0,
      attempt: completed == 0
          ? null
          : RoutineAttempt(
              id: 'saved-attempt',
              scope: SessionScope(userId: 'member', organizationId: 'gym'),
              routine: routine,
              day: 1,
              finished: completed == 6,
              updatedAtMicros: 1,
              entries: List.generate(
                  6,
                  (i) => RoutineExerciseResult(
                      index: i,
                      status: i < completed
                          ? RoutineExerciseStatus.selfReportedCompleted
                          : RoutineExerciseStatus.notStarted,
                      sessionIds: const [],
                      fullRepetitions: 0,
                      partialRepetitions: 0,
                      trackedDurationMicros: 0,
                      manualSets: i < completed ? 2 : 0))));
}

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('responsive hub $width at $scale text', (t) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final key = GlobalKey();
        await t.pumpWidget(MaterialApp(
            key: UniqueKey(),
            theme: buildMemberTypographyTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    padding: const EdgeInsets.only(top: 24),
                    disableAnimations: true),
                child: child!),
            home: RepaintBoundary(
                key: key,
                child: Scaffold(
                    bottomNavigationBar:
                        NavigationBar(selectedIndex: 1, destinations: const [
                      NavigationDestination(
                          icon: Icon(Icons.home_outlined), label: 'Home'),
                      NavigationDestination(
                          icon: Icon(Icons.fitness_center), label: 'Workout'),
                      NavigationDestination(
                          icon: Icon(Icons.emoji_events_outlined),
                          label: 'Rewards'),
                      NavigationDestination(
                          icon: Icon(Icons.people_outline), label: 'Coaches'),
                      NavigationDestination(
                          icon: Icon(Icons.person_outline), label: 'Profile')
                    ]),
                    body: WorkoutPrepScreen(
                        live: true,
                        publishedRoutine: hubRoutine(),
                        onStartFree: () {},
                        onOpenPrograms: () {},
                        onOpenSettings: () {},
                        onOpenProgress: () {},
                        onOpenRoutineHistory: () {},
                        onBrowseEquipment: () {})))));
        await t.pumpAndSettle();
        t
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        if (scale == 1) {
          expect(find.text('Start workout').hitTestable(), findsOneWidget);
        }
        await captureHub(t, key, 'free-${width.toInt()}-$scale-top');
        await t.ensureVisible(find.text("Today's exercises"));
        await t.pumpAndSettle();
        await captureHub(t, key, 'free-${width.toInt()}-$scale-middle');
        await t.ensureVisible(find.text('View all 6 exercises'));
        await t.pumpAndSettle();
        await t.tap(find.text('View all 6 exercises'));
        await t.pumpAndSettle();
        await captureHub(t, key, 'free-${width.toInt()}-$scale-expanded');
        await t.ensureVisible(find.text('Camera setup'));
        await t.pumpAndSettle();
        await captureHub(t, key, 'free-${width.toInt()}-$scale-bottom');
        expect(t.takeException(), isNull);
      });
    }
  }
  for (final count in [0, 2, 6]) {
    testWidgets('scheduled saved progress $count renders truthfully',
        (t) async {
      final restore = await installFypOfflineFonts();
      addTearDown(restore);
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final key = GlobalKey();
      await t.pumpWidget(MaterialApp(
          theme: buildMemberTypographyTheme(),
          home: RepaintBoundary(
              key: key,
              child: WorkoutPrepScreen(
                  live: true,
                  scheduledWorkout: hubScheduled(count),
                  trainingPlanTitle: 'Foundations · 4 weeks',
                  nextScheduledWorkout: hubScheduled(count),
                  onStartScheduled: () {},
                  onOpenPrograms: () {}))));
      await t.pumpAndSettle();
      expect(
          find.text(count == 6
              ? 'View Workout Summary'
              : count == 0
                  ? 'Start workout'
                  : 'Continue workout'),
          findsOneWidget);
      if (count == 0) {
        expect(find.byKey(const ValueKey('workout-progress')), findsNothing);
      } else {
        expect(
            t
                .widget<LinearProgressIndicator>(
                    find.byKey(const ValueKey('workout-progress')))
                .value,
            count / 6);
      }
      await captureHub(t, key, 'scheduled-$count-top');
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('landscape and reduced motion preserve navigation and expansion',
      (t) async {
    t.view.physicalSize = const Size(844, 390);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c).copyWith(disableAnimations: true),
            child: child!),
        home: WorkoutPrepScreen(
            live: true, publishedRoutine: hubRoutine(), onStartFree: () {})));
    await t.pumpAndSettle();
    expect(find.byType(AnimatedSize), findsNothing);
    await t.ensureVisible(find.text('View all 6 exercises'));
    await t.pumpAndSettle();
    await t.tap(find.text('View all 6 exercises'));
    await t.pump();
    expect(find.text('Movement 6'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('switching identity clears old exercise progress and disclosure',
      (t) async {
    final selected = ValueNotifier(true);
    addTearDown(selected.dispose);
    await t.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
            valueListenable: selected,
            builder: (_, scheduled, __) => WorkoutPrepScreen(
                live: true,
                publishedRoutine: hubRoutine(),
                scheduledWorkout: scheduled ? hubScheduled(2) : null,
                trainingPlanTitle: 'Independent plan',
                nextScheduledWorkout: hubScheduled(2),
                onStartFree: () {},
                onStartScheduled: () {}))));
    await t.pumpAndSettle();
    expect(find.text('2 / 6'), findsOneWidget);
    selected.value = false;
    await t.pump();
    expect(find.text('2 / 6'), findsNothing);
    await t.pumpAndSettle();
    expect(find.text('Independent plan'), findsOneWidget);
    expect(find.text('Strength foundations free'), findsOneWidget);
    expect(find.byKey(const ValueKey('workout-progress')), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('render existing Rewards reference', (t) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final key = GlobalKey(),
        scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    await t.pumpWidget(MaterialApp(
        theme: buildMemberTypographyTheme(),
        home: RepaintBoundary(
            key: key,
            child: AppCheckInDashboard(
                state: AppCheckInState(
                    status: AppCheckInStatus.ready,
                    snapshot: AppCheckInSnapshot.fromJson(
                        snapshotJson(scope), scope)),
                onClaim: () async {},
                onRefresh: () async {}))));
    await t.pumpAndSettle();
    await captureHub(t, key, 'reference-rewards');
    expect(t.takeException(), isNull);
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_WORKOUT_MOTION'));
}

Future<void> captureHub(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('GAINPATH_RENDER_WORKOUT_MOTION')) return;
  expect(t.takeException(), isNull);
  await t.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('build/workout-hub-motion-preview/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
