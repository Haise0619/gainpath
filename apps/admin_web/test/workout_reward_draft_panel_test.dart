import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_admin_web/features/gamification/presentation/admin/workout_reward_draft_panel.dart';

class _Repo implements WorkoutRewardConfigurationRepository {
  @override
  bool current = true;
  int reads = 0;
  bool fail = false;
  final ids = <String>[];
  int? base;
  WorkoutRewardDraft? saved;
  @override
  Future<WorkoutRewardDraft> loadWorkoutRewardDraft() async {
    reads++;
    return const WorkoutRewardDraft(revision: 3, version: 'saved-3');
  }

  @override
  Future<void> saveWorkoutRewardDraft(
      {required String requestId,
      required int baseRevision,
      required WorkoutRewardDraft draft}) async {
    ids.add(requestId);
    base = baseRevision;
    if (fail) throw StateError('uncertain');
    saved = draft;
  }
}

void main() {
  testWidgets('invalid daily limit and duplicate routine IDs cannot save',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: WorkoutRewardDraftPanel(repository: repo)))));
    await tester.tap(find.text('Workout reward draft'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Claims per Malaysia day'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Claims per Malaysia day'), '11');
    await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Eligible routine IDs'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Eligible routine IDs'),
        'same\nsame');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    expect(repo.ids, isEmpty);
    expect(find.text('Enter a whole number from 1 to 10'), findsOneWidget);
    expect(find.text('Use up to 100 unique routine IDs, one per line'),
        findsOneWidget);
  });
  testWidgets('lazy disabled draft saves configured values with stable retry',
      (tester) async {
    final repo = _Repo();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: WorkoutRewardDraftPanel(repository: repo)))));
    expect(repo.reads, 0);
    await tester.tap(find.text('Workout reward draft'));
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('Disabled'), findsWidgets);
    expect(
        tester
            .widget<TextFormField>(find.widgetWithText(
                TextFormField, 'Points per qualifying workout'))
            .controller!
            .text,
        '100');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Points per qualifying workout'),
        '120');
    await tester.ensureVisible(
        find.widgetWithText(TextFormField, 'Eligible routine IDs'));
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Eligible routine IDs'),
        'routine-one\nroutine-two');
    await tester.pumpAndSettle();
    repo.fail = true;
    await tester.ensureVisible(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    repo.fail = false;
    await tester.ensureVisible(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save workout draft'));
    await tester.pumpAndSettle();
    expect(repo.ids.length, 2);
    expect(repo.ids.first, repo.ids.last);
    expect(repo.base, 3);
    expect(repo.saved!.points, 120);
    expect(repo.saved!.eligibleRoutineIds, ['routine-one', 'routine-two']);
  });
  testWidgets(
      'draft stays readable at 375px and large text, hides on session change',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    Widget app() => MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: WorkoutRewardDraftPanel(repository: repo))));
    await tester.pumpWidget(app());
    await tester.tap(find.text('Workout reward draft'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save workout draft'));
    expect(tester.takeException(), null);
    repo.current = false;
    await tester.pumpWidget(app());
    expect(find.text('Save workout draft'), findsNothing);
  });
}
