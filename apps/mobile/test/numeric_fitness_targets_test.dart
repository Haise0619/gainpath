import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/numeric_fitness_targets.dart';
import 'package:google_fonts/google_fonts.dart';

class TargetRepositoryFake implements NumericFitnessGoalRepository {
  TargetRepositoryFake({SessionScope? sessionScope})
      : scope = sessionScope ??
            SessionScope(userId: 'member', organizationId: 'org');
  @override
  final SessionScope scope;
  final records = <String, NumericFitnessGoal>{};
  final submittedIds = <String>[];
  int next = 0;
  bool fail = false;
  Completer<void>? pending;
  @override
  String allocateId() => 'target-${++next}';
  @override
  Future<List<NumericFitnessGoal>> loadActive() async => records.values
      .where((goal) => goal.status == NumericGoalStatus.active)
      .toList();
  @override
  Future<void> create(
      {required String id,
      required NumericGoalCategory category,
      required double targetValue}) async {
    submittedIds.add(id);
    await pending?.future;
    if (fail) {
      throw const NumericGoalException('Connection unavailable. Retry.');
    }
    records[id] = NumericFitnessGoal(
        id: id,
        category: category,
        targetValue: targetValue,
        status: NumericGoalStatus.active,
        revision: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026));
  }

  @override
  Future<void> update(NumericFitnessGoal original,
      {required double targetValue}) async {
    records[original.id] = NumericFitnessGoal(
        id: original.id,
        category: original.category,
        targetValue: targetValue,
        status: original.status,
        revision: original.revision + 1,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt);
  }

  @override
  Future<void> archive(NumericFitnessGoal original) async {
    records[original.id] = NumericFitnessGoal(
        id: original.id,
        category: original.category,
        targetValue: original.targetValue,
        status: NumericGoalStatus.archived,
        revision: original.revision + 1,
        createdAt: original.createdAt,
        updatedAt: original.updatedAt);
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'bound auth session closes editor and remains invalid after logout and signing in again',
      (tester) async {
    final authRepository = InMemoryAuthRepository(organizationId: 'org');
    final session = await authRepository.signIn(
        email: 'member@example.com', password: 'password123');
    final auth = AuthBloc(repository: authRepository);
    addTearDown(auth.close);
    addTearDown(authRepository.dispose);
    final repository = TargetRepositoryFake(sessionScope: session.scope);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: NumericFitnessTargets(
                    session: session, repository: repository)))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add a goal'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '4');
    await authRepository.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Add a numeric target'), findsNothing);
    expect(find.text('Your session changed. Sign in again.'), findsOneWidget);
    await authRepository.signIn(
        email: 'member@example.com', password: 'password123');
    await tester.pumpAndSettle();
    expect(find.text('Add a goal'), findsNothing);
    expect(repository.records, isEmpty);
  });
  Future<void> mount(WidgetTester tester, TargetRepositoryFake repository,
      {bool Function()? current}) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: NumericFitnessTargets(
                    repository: repository, isSessionCurrent: current)))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.pump();
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'live empty state, validation, real create/edit/archive and truthful actuals',
      (tester) async {
    final repository = TargetRepositoryFake();
    await mount(tester, repository);
    expect(find.text('No active numeric targets. Add one when you are ready.'),
        findsOneWidget);
    await tap(tester, 'Add a goal');
    await tester.enterText(find.byType(TextFormField), '1.5');
    await tap(tester, 'Save target');
    expect(find.text('Enter a whole number of sessions.'), findsOneWidget);
    expect(repository.records, isEmpty);
    await tester.enterText(find.byType(TextFormField), '4');
    await tap(tester, 'Save target');
    expect(find.text('Weekly training frequency: 4 sessions'), findsOneWidget);
    expect(find.text('Actual: unavailable · Version 1'), findsOneWidget);
    await tester.tap(find.byTooltip('Edit Weekly training frequency'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save target'))
            .onPressed,
        isNull);
    await tester.enterText(find.byType(TextFormField), '5');
    await tap(tester, 'Save target');
    expect(find.text('Weekly training frequency: 5 sessions'), findsOneWidget);
    await tester.tap(find.byTooltip('Archive Weekly training frequency'));
    await tester.pumpAndSettle();
    await tap(tester, 'Archive');
    expect(repository.records.values.single.status, NumericGoalStatus.archived);
    expect(find.text('No active numeric targets. Add one when you are ready.'),
        findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });
  testWidgets(
      'failed create retries exact id and submitted value; no fake success',
      (tester) async {
    final repository = TargetRepositoryFake()..fail = true;
    await mount(tester, repository);
    await tap(tester, 'Add a goal');
    await tester.enterText(find.byType(TextFormField), '4');
    await tap(tester, 'Save target');
    expect(find.text('Connection unavailable. Retry.'), findsOneWidget);
    expect(find.text('Target saved.'), findsNothing);
    expect(tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        false);
    repository.fail = false;
    await tap(tester, 'Save target');
    expect(repository.submittedIds, ['target-1', 'target-1']);
    expect(repository.records, hasLength(1));
  });
  testWidgets(
      'in-flight save disables repeat submission and session change suppresses success',
      (tester) async {
    final repository = TargetRepositoryFake()..pending = Completer<void>();
    var current = true;
    await mount(tester, repository, current: () => current);
    await tap(tester, 'Add a goal');
    await tester.enterText(find.byType(TextFormField), '4');
    await tester.tap(find.text('Save target'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull);
    current = false;
    repository.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Target saved.'), findsNothing);
    expect(repository.submittedIds, hasLength(1));
  });
  testWidgets('back protects an unsaved target', (tester) async {
    final repository = TargetRepositoryFake();
    await mount(tester, repository);
    await tap(tester, 'Add a goal');
    await tester.enterText(find.byType(TextFormField), '4');
    await tap(tester, 'Cancel');
    expect(find.text('Close target editor?'), findsOneWidget);
    await tap(tester, 'Keep editing');
    expect(find.text('Add a numeric target'), findsOneWidget);
    expect(repository.records, isEmpty);
  });
}
