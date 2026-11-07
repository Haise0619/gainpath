import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final routine = PublishedRoutine.fromDocument('r', {
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'b',
    'title': 'Actual workout',
    'estimatedMinutes': 10,
    'exercises': [
      {
        'exerciseId': 'e',
        'name': 'Movement',
        'sets': 1,
        'reps': 8,
        'restSeconds': 60
      }
    ]
  });
  for (final large in [false, true]) {
    testWidgets(
        'tools adapt and single-set rest is presentation-only; large=$large',
        (tester) async {
      tester.view.physicalSize = Size(large ? 320 : 390, large ? 640 : 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var plans = 0;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
              child: child!),
          home: WorkoutPrepScreen(
              live: true,
              publishedRoutine: routine,
              onOpenPrograms: () => plans++)));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('workout-progress-ring')), findsOneWidget);
      expect(find.text('0 / 1'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Sets'), findsOneWidget);
      expect(find.text('~10'), findsOneWidget);
      expect(find.text('View your schedule and saved progress'), findsNothing);
      expect(find.textContaining('rest between sets'), findsNothing);
      expect(routine.exercises.single.restSeconds, 60);
      await tester.scrollUntilVisible(find.text('My training plan'), 200);
      await tester.pumpAndSettle();
      final plan = tester.getTopLeft(find.text('My training plan'));
      final camera = tester.getTopLeft(find.text('Review camera setup'));
      expect(large ? (camera.dx - plan.dx).abs() < 1 : camera.dx > plan.dx,
          isTrue);
      await tester.ensureVisible(find.text('My training plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My training plan'));
      expect(plans, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
