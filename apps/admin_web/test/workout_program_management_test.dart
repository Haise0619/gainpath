import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/domain/admin_workout_program_repository.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/workout_programs_screen.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_program_repository.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
  test('App Check readiness failure is retried before loading Programs',
      () async {
    var checks = 0, calls = 0;
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => true,
      verifiedSession: () => true,
      ensureReady: () async => ++checks > 1,
      call: (_) async {
        calls++;
        return {'programs': [], 'drafts': []};
      },
      loadRoutines: () async => [],
    );
    await expectLater(repository.load(), throwsStateError);
    expect(calls, 0);
    expect((await repository.load()).programs, isEmpty);
    expect(checks, 2);
    expect(calls, 1);
  });
  test('account change while waiting for App Check prevents sending', () async {
    var current = true, calls = 0;
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => current,
      verifiedSession: () => true,
      ensureReady: () async {
        current = false;
        return true;
      },
      call: (_) async {
        calls++;
        return {'programs': [], 'drafts': []};
      },
      loadRoutines: () async => [],
    );
    await expectLater(repository.load(), throwsStateError);
    expect(calls, 0);
  });
  test('scope change after remote response rejects stale catalog', () async {
    var current = true;
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => current,
      verifiedSession: () => true,
      ensureReady: () async => true,
      call: (input) async {
        current = false;
        return {'programs': [], 'drafts': []};
      },
      loadRoutines: () async => [],
    );
    await expectLater(repository.load(), throwsStateError);
  });
  test('draft retries retain request ID and optimistic revision', () async {
    final requests = <Map<String, dynamic>>[];
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => true,
      verifiedSession: () => true,
      ensureReady: () async => true,
      call: (input) async {
        requests.add(input);
        return {'revision': 4};
      },
      loadRoutines: () async => [],
    );
    final program = WorkoutProgram.templates().first;
    expect(
        await repository.saveDraft(program,
            expectedRevision: 3, requestId: 'retry-id'),
        4);
    expect(requests.single['expectedRevision'], 3);
    expect(requests.single['requestId'], 'retry-id');
    expect(requests.single['action'], 'saveDraft');
    expect(requests.single['organizationId'], 'gainpath');
    expect((requests.single['program'] as Map)['version'], 0);
  });
  test('publish rejects missing revision advance', () async {
    final data = WorkoutProgram.templates().first.toJson();
    data['version'] = 1;
    for (final day in data['days'] as List) {
      if (day['kind'] == 'workout') {
        day['routineId'] = 'routine_one';
        day['routineSnapshot'] = {
          'schemaVersion': 1,
          'kind': 'routine',
          'status': 'published',
          'exercises': [
            {'dayNumber': 1}
          ]
        };
      }
    }
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => true,
      verifiedSession: () => true,
      ensureReady: () async => true,
      call: (_) async => {'program': data, 'revision': 2},
      loadRoutines: () async => [],
    );
    await expectLater(
        repository.publish(data['id'] as String,
            expectedRevision: 2, requestId: 'publish-id'),
        throwsFormatException);
  });
  test('unverified session cannot send program mutations', () async {
    var calls = 0;
    final repository = FirebaseAdminWorkoutProgramRepository(
      scope: scope,
      isCurrent: () => true,
      verifiedSession: () => false,
      ensureReady: () async => true,
      call: (_) async {
        calls++;
        return {'revision': 1};
      },
      loadRoutines: () async => [],
    );
    await expectLater(
        repository.saveDraft(WorkoutProgram.templates().first,
            expectedRevision: 0, requestId: 'save-id'),
        throwsStateError);
    expect(calls, 0);
  });
  testWidgets('three starter levels open editable four-week schedule',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1000, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: WorkoutProgramsScreen(repository: _Repository()))));
    await tester.pumpAndSettle();
    expect(find.text('Beginner · 3 days/week'), findsOneWidget);
    expect(find.text('Intermediate · 4 days/week'), findsOneWidget);
    expect(find.text('Advanced · 5 days/week'), findsOneWidget);
    await tester.tap(find.text('Beginner · 3 days/week'));
    await tester.pumpAndSettle();
    expect(find.text('Week 1'), findsOneWidget);
    expect(find.text('Save draft'), findsOneWidget);
    expect(find.textContaining('Routine Builder'), findsWidgets);
  });
  testWidgets('unavailable catalog offers retry without sample published data',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: WorkoutProgramsScreen(repository: _Repository(fail: true)))));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Beginner · 3 days/week'), findsNothing);
  });
  testWidgets('draft save is confirmed and publish refuses missing assignments',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = _Repository();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WorkoutProgramsScreen(repository: repository))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beginner · 3 days/week'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save draft'));
    await tester.tap(find.text('Save draft'));
    await tester.pumpAndSettle();
    expect(repository.saveCalls, 1);
    expect(find.textContaining('Draft saved.'), findsOneWidget);
    await tester.ensureVisible(find.text('Publish version'));
    await tester.tap(find.text('Publish version'));
    await tester.pumpAndSettle();
    expect(repository.publishCalls, 0);
    expect(find.textContaining('Assign a published Routine'), findsOneWidget);
  });
}

class _Repository implements AdminWorkoutProgramRepository {
  _Repository({this.fail = false});
  final bool fail;
  int saveCalls = 0, publishCalls = 0;
  @override
  bool get current => true;
  @override
  Future<AdminProgramCatalog> load() async {
    if (fail) throw StateError('offline');
    return const AdminProgramCatalog(programs: [], drafts: [], routines: []);
  }

  @override
  Future<int> saveDraft(WorkoutProgram program,
      {required int expectedRevision, required String requestId}) async {
    saveCalls++;
    return expectedRevision + 1;
  }

  @override
  Future<AdminProgramDraft> publish(String programId,
      {required int expectedRevision, required String requestId}) async {
    publishCalls++;
    throw UnimplementedError();
  }
}
