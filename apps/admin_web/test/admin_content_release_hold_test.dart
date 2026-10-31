import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/routine_templates_screen.dart';
import 'content_removal_ui_test.dart' show Catalog, Routines;

void main() {
  testWidgets(
      'release hold hides exercise Remove while keeping editing available',
      (tester) async {
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: Catalog(),
        child: const MaterialApp(
            home: ExerciseTutorialsScreen(allowRemoval: false))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Delete exercise'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
    expect(find.text('Squat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('release hold hides template Remove while keeping its row',
      (tester) async {
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(value: Catalog()),
          RepositoryProvider<RoutineTemplateRepository>.value(
              value: Routines()),
        ],
        child: const MaterialApp(
            home: RoutineTemplatesScreen(allowRemoval: false))));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove template'), findsNothing);
    expect(find.text('Strength'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
