import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_mobile/features/workout/application/workout_program_controller.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_program_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/widgets/program_enrollment_cards.dart';
import 'routine_journey_controller_test.dart' show MemoryJourneyStore;
import 'workout_program_controller_test.dart'
    show MemoryProgramStore, programFixture;

WorkoutProgram fourDayProgramFixture() {
  final json = WorkoutProgram.templates()[1].toJson(); // 4-day split
  json['version'] = 1;
  json['days'] = (json['days'] as List).map((raw) {
    final day = Map<String, dynamic>.from(raw as Map);
    if (day['kind'] == 'workout') {
      final isUpper = day['category'] == 'Upper Body';
      day['routineId'] = isUpper ? 'routine_upper' : 'routine_lower';
      day['routineSnapshot'] = {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': isUpper ? 'upper' : 'lower',
        'title': '${day['category']} Blast',
        'estimatedMinutes': 30,
        'exercises': [
          {
            'exerciseId': isUpper ? 'push_up' : 'squat',
            'name': isUpper ? 'Standard Push-Up' : 'Bodyweight Squat',
            'sets': 3,
            'reps': 12,
            'dayNumber': day['routineDay'],
            'restSeconds': 60,
            'category': day['category'],
            'muscleGroup': isUpper ? 'upperPush' : 'lower'
          }
        ]
      };
    }
    return day;
  }).toList();
  return WorkoutProgram.fromJson(json);
}

WorkoutProgram longTitleProgramFixture() {
  final base = programFixture().toJson();
  base['title'] =
      'Comprehensive Advanced Hypertrophy & Strength Conditioning Blueprint 2026';
  return WorkoutProgram.fromJson(base);
}

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gym');

  group('Workout Program Redesign — Onboarding & Structure', () {
    testWidgets('renders all 4 separate cards and sticky bottom action',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-1');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Card 1
      expect(find.text('Choose your program'), findsOneWidget);
      expect(find.text('Beginner 4-week Program'), findsOneWidget);
      expect(find.text('Beginner level · 4 weeks'), findsOneWidget);

      // Card 2
      expect(find.text('Program overview'), findsOneWidget);
      expect(find.text('3 workouts/week'), findsOneWidget);
      expect(find.text('4 weeks'), findsOneWidget);
      expect(find.text('Beginner level'), findsOneWidget);
      expect(find.text('Workout routines'), findsOneWidget);
      expect(find.text('Recovery days separate training sessions.'), findsWidgets);

      // Card 3
      expect(find.text('Schedule setup'), findsOneWidget);
      expect(find.text('Start date — 2 Nov 2026'), findsOneWidget);
      expect(find.text('Choose 3 training days each week'), findsOneWidget);
      for (final name in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        expect(find.text(name), findsWidgets);
      }

      // Card 4
      expect(find.text('Your schedule preview'), findsOneWidget);
      expect(find.textContaining('First workout: Mon, 2 Nov'), findsOneWidget);
      expect(find.textContaining('Full body · Estimated 20 min'), findsOneWidget);
      expect(find.text('First week schedule'), findsOneWidget);

      // Sticky Bottom Action
      expect(find.text('3 training days selected'), findsOneWidget);
      expect(find.text('Start program'), findsOneWidget);
      expect(find.text('Previous enrollments and workout history are kept.'),
          findsOneWidget);

      // Preview does not create an enrollment
      expect(c.enrollment, isNull);
      expect(store.journal.enrollments, isEmpty);

      c.dispose();
    });

    testWidgets('supports long program names without layout overflow',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-long');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [longTitleProgramFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(
          find.text(
              'Comprehensive Advanced Hypertrophy & Strength Conditioning Blueprint 2026'),
          findsOneWidget);
      expect(tester.takeException(), isNull);

      c.dispose();
    });

    testWidgets('program picker bottom sheet allows switching programs',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-picker');
      await c.open();

      final p1 = programFixture();
      final p2 = fourDayProgramFixture();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [p1, p2],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('3 workouts/week'), findsOneWidget);

      // Tap program selector
      await tester.tap(find.byKey(const ValueKey('program-selector')));
      await tester.pumpAndSettle();

      // Modal bottom sheet appears
      expect(find.text(p2.title), findsOneWidget);
      await tester.tap(find.text(p2.title));
      await tester.pumpAndSettle();

      // Switches to 4-day program
      expect(find.text(p2.title), findsOneWidget);
      expect(find.text('4 workouts/week'), findsOneWidget);
      expect(find.text('Choose 4 training days each week'), findsOneWidget);

      c.dispose();
    });
  });

  group('Workout Program Redesign — Weekday Selection & Validation', () {
    testWidgets('toggling weekdays updates day count, validation, and preview',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-weekdays');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Initial state: Mon(1), Wed(3), Fri(5) selected
      expect(find.text('3 training days selected'), findsOneWidget);
      expect(find.text('First workout: Mon, 2 Nov'), findsOneWidget);

      Finder weekdayButton(String label) => find.descendant(
            of: find.byType(ScheduleSetupCard),
            matching: find.text(label),
          );

      Future<void> tapWeekday(String label) async {
        final btn = weekdayButton(label);
        await tester.ensureVisible(btn);
        await tester.pumpAndSettle();
        await tester.tap(btn);
        await tester.pumpAndSettle();
      }

      // Deselect Wed (tap 'Wed')
      await tapWeekday('Wed');

      // Now 2 selected: inline error and disabled Start program button
      expect(find.text('2 of 3 training days selected'), findsOneWidget);
      expect(find.textContaining('Select 1 more training day'), findsWidgets);
      final startBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start program'));
      expect(startBtn.onPressed, isNull);

      // Schedule preview shows friendly guidance, not fabricated schedule
      expect(find.textContaining('Select 1 more training day'), findsWidgets);

      // Add Thu -> Mon(1), Thu(4), Fri(5) -> 3 selected
      await tapWeekday('Thu');
      expect(find.text('3 training days selected'), findsOneWidget);

      // Select Wed back -> Mon(1), Wed(3), Thu(4)
      await tapWeekday('Wed');

      c.dispose();
    });

    testWidgets('recovery conflict validation displays actionable message',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-recovery');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      Finder weekdayButton(String label) => find.descendant(
            of: find.byType(ScheduleSetupCard),
            matching: find.text(label),
          );

      Future<void> tapWeekday(String label) async {
        final btn = weekdayButton(label);
        await tester.ensureVisible(btn);
        await tester.pumpAndSettle();
        await tester.tap(btn);
        await tester.pumpAndSettle();
      }

      // Currently Mon(1), Wed(3), Fri(5). Unselect Fri(5), select Tue(2) -> Mon(1), Tue(2), Wed(3)
      await tapWeekday('Fri');
      await tapWeekday('Tue');

      // Consecutive Full Body days violate recovery spacing
      expect(
          find.text(
              'Leave a recovery day between workouts using the same muscle groups.'),
          findsWidgets);
      final startBtn = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Start program'));
      expect(startBtn.onPressed, isNull);

      c.dispose();
    });
  });

  group('Workout Program Redesign — Responsive & Text Scaling', () {
    testWidgets('onboarding cards support 320px width without RenderFlex overflow',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-320');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Choose your program'), findsOneWidget);
      expect(find.text('Start program'), findsOneWidget);

      c.dispose();
    });

    testWidgets('onboarding cards support 360px and 2x text scaler without overflow',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-scale');
      await c.open();

      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Choose your program'), findsOneWidget);

      c.dispose();
    });
  });

  group('Workout Program Redesign — Active Plan & Flow Continuity', () {
    testWidgets('switch program shows onboarding with return to active plan option',
        (tester) async {
      final store = MemoryProgramStore(scope);
      final c = WorkoutProgramController(
          scope: scope,
          activeScope: () => scope,
          store: store,
          routineStore: MemoryJourneyStore(scope),
          newId: () => 'id-switch');
      await c.open();
      await c.enroll(programFixture(), DateTime.utc(2026, 11, 2), {1, 3, 5});

      await tester.pumpWidget(MaterialApp(
        home: WorkoutProgramScreen(
          controller: c,
          loadPrograms: () async => [programFixture(), fourDayProgramFixture()],
          today: DateTime.utc(2026, 11, 2),
          onOpenRoutine: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CURRENT PLAN'), findsOneWidget);

      // Tap 'Choose another program'
      await tester.scrollUntilVisible(find.text('Choose another program'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose another program'));
      await tester.pumpAndSettle();

      // Onboarding cards appear with 'Return to active plan'
      expect(find.text('Return to active plan'), findsOneWidget);
      expect(find.text('Choose your program'), findsOneWidget);

      // Tap 'Return to active plan'
      await tester.tap(find.text('Return to active plan'));
      await tester.pumpAndSettle();

      // Active plan view restored
      expect(find.text('CURRENT PLAN'), findsOneWidget);

      c.dispose();
    });
  });
}
