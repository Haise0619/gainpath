import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/application/workout_hub_program.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/routine_attempt.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('render redesigned Today exercises section and capture screenshot',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 2.0, 915 * 2.0);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final routine = PublishedRoutine.fromDocument('testing-routine', {
      'schemaVersion': 2,
      'kind': 'routine_v2',
      'status': 'published',
      'sourceBlueprintId': 'testing-blueprint',
      'title': 'Testing',
      'estimatedMinutes': 30,
      'exercises': [
        {
          'entryId': 'e-1',
          'exerciseId': 'burpee',
          'name': 'Burpee',
          'category': 'Cardio',
          'dayNumber': 1,
          'sets': 1,
          'durationSeconds': 40,
          'restSeconds': 30,
          'executionMode': 'videoGuidedTimed',
        },
        {
          'entryId': 'e-2',
          'exerciseId': 'dumbbell_shoulder_press_front_v1',
          'name': 'Dumbbell Shoulder Press',
          'category': 'Strength',
          'dayNumber': 1,
          'sets': 1,
          'reps': 3,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
        },
        {
          'entryId': 'e-3',
          'exerciseId': 'squat',
          'name': 'Squat',
          'category': 'Strength',
          'dayNumber': 1,
          'sets': 1,
          'reps': 3,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
        },
        {
          'entryId': 'e-4',
          'exerciseId': 'standing_calf_raise_side_v1',
          'name': 'Standing Calf Raise',
          'category': 'Strength',
          'dayNumber': 1,
          'sets': 2,
          'reps': 15,
          'restSeconds': 45,
          'executionMode': 'aiTracked',
        },
        {
          'entryId': 'e-5',
          'exerciseId': 'standing_lateral_raise_front_v1',
          'name': 'Standing Lateral Raise',
          'category': 'Strength',
          'dayNumber': 1,
          'sets': 2,
          'reps': 8,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
        },
        {
          'entryId': 'e-6',
          'exerciseId': 'standing_single_arm_dumbbell_curl_side_v1',
          'name': 'Standing single-arm dumbbell curl',
          'category': 'Strength',
          'dayNumber': 1,
          'sets': 2,
          'reps': 8,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
        },
        {
          'entryId': 'e-7',
          'exerciseId': 'standard_floor_push_up_side_v1',
          'name': 'Standard Floor Push-Up',
          'category': 'Bodyweight',
          'dayNumber': 1,
          'sets': 3,
          'reps': 8,
          'restSeconds': 60,
          'executionMode': 'aiTracked',
        },
      ],
    });

    final attempt = RoutineAttempt(
      id: 'attempt-1',
      scope: SessionScope(userId: 'test-user', organizationId: 'gainpath'),
      routine: routine,
      day: 1,
      finished: false,
      updatedAtMicros: 1000,
      entries: [
        RoutineExerciseResult(
          index: 0,
          status: RoutineExerciseStatus.skipped,
          sessionIds: [],
          fullRepetitions: 0,
          partialRepetitions: 0,
          trackedDurationMicros: 0,
          manualSets: 0,
        ),
        RoutineExerciseResult(
          index: 1,
          status: RoutineExerciseStatus.partial,
          sessionIds: [],
          fullRepetitions: 1,
          partialRepetitions: 0,
          trackedDurationMicros: 0,
          manualSets: 0,
        ),
      ],
    );

    final scheduled = ScheduledWorkoutPreview(
      routine: routine,
      day: 1,
      dayKey: 'day-1',
      enrollmentId: 'enrollment-1',
      date: DateTime.utc(2026, 11, 15),
      snapshot: 'Testing snapshot',
      inProgress: true,
      attempt: attempt,
    );

    final repaintKey = GlobalKey();

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9F7FC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5C19D9),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E1430),
          ),
          titleMedium: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E1430),
          ),
          bodyMedium: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
      home: RepaintBoundary(
        key: repaintKey,
        child: Scaffold(
          body: WorkoutPrepScreen(
            live: true,
            publishedRoutine: routine,
            scheduledWorkout: scheduled,
            organizationId: 'gainpath',
            onOpenPrograms: () {},
            onOpenEquipment: () {},
            onBrowseEquipment: () {},
            onOpenProgress: () {},
            onOpenRoutineHistory: () {},
            onOpenSettings: () {},
            routineCatalogControls: PublishedRoutineCatalogControls(
              state: PublishedRoutineCatalogState(
                status: CatalogStatus.ready,
                items: [routine],
                selected: routine,
              ),
              onRefresh: () async {},
              onSelect: (_) {},
              onLoadMore: () async {},
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: 1,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Workout'),
              NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
              NavigationDestination(icon: Icon(Icons.people_outline), label: 'Coaches'),
              NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    // Capture initial 3-card screenshot
    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final outDir = Directory(
          r'C:\Users\Ngzhe\.gemini\antigravity\brain\2e9bce9b-03ec-4533-aa97-83c6a91f9314');
      final file = File('${outDir.path}/workout_page_exercises_redesigned_full.png');
      await file.writeAsBytes(bytes);
      image.dispose();
    });

    // Expand all exercises
    await tester.scrollUntilVisible(find.text('View all 7 exercises'), 150);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all 7 exercises'));
    await tester.pumpAndSettle();

    expect(find.text('Show fewer exercises'), findsOneWidget);
    expect(find.text('Standard Floor Push-Up'), findsOneWidget);

    // Capture expanded screenshot
    await tester.runAsync(() async {
      final boundary =
          repaintKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      final outDir = Directory(
          r'C:\Users\Ngzhe\.gemini\antigravity\brain\2e9bce9b-03ec-4533-aa97-83c6a91f9314');
      final file = File('${outDir.path}/workout_page_exercises_expanded_full.png');
      await file.writeAsBytes(bytes);
      image.dispose();
    });
  });
}
