import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/routine_history_screen.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'routine_history_ui_test.dart' as fixture;
import 'routine_journey_controller_test.dart' as sessions;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('routine details expose the exact linked assessment only', (tester) async {
    final a = fixture.attempt();
    await tester.pumpWidget(MaterialApp(home: RoutineAttemptDetailScreen(
        attempt: a, summaries: [sessions.measured(a.scope, 'camera')])));
    await tester.scrollUntilVisible(find.text('Squat'), 150);
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('90% estimated form'), 150);
    expect(find.text('90% estimated form'), findsOneWidget);
    expect(find.textContaining('overall score'), findsNothing);
  });
  for (final version in ['dumbbell-shoulder-press-front-v1', 'standing-lateral-raise-front-v1']) {
    testWidgets('$version does not replace missing assessment with legacy zero', (tester) async {
      final a = fixture.attempt();
      final json = Map<String, dynamic>.from(sessions.measured(a.scope, 'camera').toJson());
      json['exerciseId'] = version;
      json['accuracy'] = 0;
      final metrics = Map<String, dynamic>.from(json['poseMetrics'] as Map)
        ..['schemaVersion'] = version.startsWith('standing') ? 6 : 4
        ..['scoringVersion'] = version
        ..['cameraView'] = 'front'
        ..['partialRepetitions'] = 0
        ..['formScorePercent'] = null;
      json['poseMetrics'] = metrics;
      final summary = WorkoutSessionSummary.fromJson(json);
      await tester.pumpWidget(MaterialApp(home: WorkoutResultScreen.measured(summary: summary)));
      expect(find.text('Form assessment not available for this exercise.'), findsOneWidget);
      expect(find.text('0% estimated form'), findsNothing);
    });
  }
  testWidgets('routine summary leads with completion and separates evidence',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: RoutineAttemptDetailScreen(attempt: fixture.attempt())));
    expect(find.text('Workout summary'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('AI Tracked'), findsWidgets);
    expect(find.text('Manual'), findsWidgets);
    expect(find.textContaining('self-reported sets'), findsWidgets);
    expect(find.textContaining('checkpoint'), findsNothing);
  });
  testWidgets(
      'AI result shows assessment and moves internal evidence behind details',
      (tester) async {
    final a = fixture.attempt();
    final summary = sessions.measured(a.scope, 'camera');
    await tester.pumpWidget(
        MaterialApp(home: WorkoutResultScreen.measured(summary: summary)));
    expect(find.text('AI FORM ASSESSMENT'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Technical details'), 200);
    expect(find.text('Technical details'), findsOneWidget);
    expect(find.textContaining('not server-accepted'), findsNothing);
  });
}
