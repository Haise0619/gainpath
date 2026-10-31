import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/app/routing/calf_raise_workout_route.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/calf_raise_setup_screen.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';

void main() {
  testWidgets('calf route opens setup before camera or Firebase access',
      (tester) async {
    final e = PublishedRoutine.fromDocument('routine', {
      'schemaVersion': 1,
      'kind': 'routine',
      'status': 'published',
      'sourceBlueprintId': 'blueprint',
      'title': 'Calf test',
      'estimatedMinutes': 10,
      'exercises': [
        {
          'exerciseId': 'standing-calf-raise-side-v1',
          'dayNumber': 1,
          'name': 'Standing calf raise',
          'category': 'Accessory',
          'sets': 2,
          'reps': 7,
          'restSeconds': 45,
          'cue': 'Control',
          'imageUrl': '',
          'muscleGroup': 'Calves',
          'videoUrl': ''
        }
      ]
    }).exercises.single;
    await tester.pumpWidget(MaterialApp(
        home: CalfRaiseWorkoutRoute(
            launch: RealWorkoutLaunch(
                scope:
                    SessionScope(userId: 'member', organizationId: 'gainpath'),
                routineId: 'routine',
                exercise: e,
                consented: true,
                setupConfirmed: true,
                requestServerUpload: false))));
    expect(find.byType(CalfRaiseSetupScreen), findsOneWidget);
    expect(find.text('45s rest between sets'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'compact doubled text setup needs heels-down acknowledgement and starts once',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var starts = 0;
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: CalfRaiseSetupScreen(
            exerciseName: 'Standing calf raise',
            sets: 2,
            reps: 7,
            restSeconds: 45,
            onStart: () => starts++)));
    expect(find.text('2 sets · 7 reps per set'), findsOneWidget);
    final start = find.byKey(const ValueKey('calf-start-camera'));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    expect(starts, 1);
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    expect(tester.takeException(), isNull);
  });
}
