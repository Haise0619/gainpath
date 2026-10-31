import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/routine_templates_screen.dart';

class Catalog implements TutorialRepository, TutorialArchivingRepository {
  final entries = [
    TutorialVideo(
        id: 'e',
        title: 'Squat',
        category: 'Core',
        status: TutorialStatus.active)
  ];
  @override
  List<TutorialVideo> get tutorials => entries;
  @override
  bool get requiresCatalogSelection => true;
  @override
  Future<List<TutorialVideo>> load() async => List.of(entries);
  @override
  Future<void> archive(TutorialVideo item) async {
    entries.remove(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class Routines
    implements RoutineTemplateRepository, RoutineArchivingRepository {
  bool fail = true;
  final entries = [
    RoutineBlueprint(
        id: 'r',
        name: 'Strength',
        level: 'Beginner',
        assignedMembers: 0,
        days: [])
  ];
  @override
  List<RoutineBlueprint> get routineTemplates => entries;
  @override
  Future<List<RoutineBlueprint>> load() async => List.of(entries);
  @override
  Future<void> archive(RoutineBlueprint item) async {
    if (fail) throw StateError('private');
    entries.remove(item);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('exercise removal confirms, cancels and refreshes',
      (tester) async {
    final catalog = Catalog();
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: catalog,
        child: const MaterialApp(home: ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(catalog.entries, hasLength(1));
    await tester.tap(find.byTooltip('Delete exercise'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(catalog.entries, isEmpty);
    expect(find.byTooltip('Delete exercise'), findsNothing);
  });
  testWidgets('template failure retains row and successful retry refreshes',
      (tester) async {
    final routines = Routines();
    await tester.pumpWidget(MultiRepositoryProvider(providers: [
      RepositoryProvider<TutorialRepository>.value(value: Catalog()),
      RepositoryProvider<RoutineTemplateRepository>.value(value: routines)
    ], child: const MaterialApp(home: RoutineTemplatesScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove template'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(routines.entries, hasLength(1));
    expect(find.text('Removal was not verified. Reload before retrying.'),
        findsOneWidget);
    expect(find.text('private'), findsNothing);
    routines.fail = false;
    await tester.tap(find.byTooltip('Remove template'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(routines.entries, isEmpty);
    expect(find.byTooltip('Remove template'), findsNothing);
  });
}
