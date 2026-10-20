import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_screen.dart';
import 'package:gainpath_mobile/navigation/workout_navigation.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final routine = PublishedRoutine.fromDocument('published-id', {
    'schemaVersion': 1,
    'kind': 'routine',
    'status': 'published',
    'sourceBlueprintId': 'blueprint',
    'title': 'Published targets',
    'estimatedMinutes': 10,
    'exercises': [
      {'exerciseId': 'first-id', 'name': 'Same name', 'sets': 2, 'reps': 7},
      {'exerciseId': 'second-id', 'name': 'Same name', 'sets': 3, 'reps': 8},
    ],
  });
  testWidgets('Watch tutorial and routine rows use injected exact row identity',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    PublishedRoutineExercise? selected;
    await tester.pumpWidget(MaterialApp(
        home: WorkoutPrepScreen(
      live: true,
      publishedRoutine: routine,
      routes: WorkoutPrepRoutes(
        tutorialBuilder: (_, row) {
          selected = row;
          return Scaffold(
              appBar: AppBar(title: Text(row.exerciseId)),
              body: Text('${row.sets} sets / ${row.reps} reps'));
        },
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Watch tutorial'));
    await tester.pumpAndSettle();
    expect(identical(selected, routine.exercises.first), true);
    expect(find.text('first-id'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('View routine'));
    await tester.pumpAndSettle();
    expect(find.byType(RoutineScreen), findsOneWidget);
    await tester.tap(find.text('Same name').last);
    await tester.pumpAndSettle();
    expect(identical(selected, routine.exercises.last), true);
    expect(find.text('second-id'), findsOneWidget);
    expect(find.text('3 sets / 8 reps'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
