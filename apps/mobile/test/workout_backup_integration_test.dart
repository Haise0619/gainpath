import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/di/workout_backup_factory.dart';
import 'package:gainpath_mobile/app/routing/member_progress_route.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_workout_backup_gateway.dart';
import 'member_progress_route_test.dart' as progress;
import 'workout_backup_test.dart' as backup;
import 'routine_journey_controller_test.dart' as fixture;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'open backup page reacts when initialization fails then retry succeeds',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final scope = auth.state.session!.scope,
        repo = progress.TestRepository(auth.state.session!.scope);
    var attempts = 0;
    final c = WorkoutBackupCoordinator(
        scope: scope,
        activeScope: () => auth.state.session?.scope,
        local: backup.Local(),
        gateway: backup.Remote(),
        store: backup.Metadata(scope));
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: MemberProgressHost(
                scope: scope,
                repositoryFactory: (_, __) async => repo,
                backupFactory: (_, __) async {
                  attempts++;
                  if (attempts == 1) throw StateError('unavailable');
                  return WorkoutBackupLease(c, () {});
                },
                builder: (context, state, refresh, open, openWorkout) =>
                    Scaffold(
                        body: TextButton(
                            onPressed: () => open(MemberProgressView.backup),
                            child: const Text('Open backup')))))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open backup'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Saved locally'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
    await tester.runAsync(auth.close);
  });
  test(
      'gateway checks identity, digest and backup receipt without accepting workout',
      () async {
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
    final record = WorkoutBackupRecord.session(fixture.measured(scope, 's'));
    var active = true;
    final gateway = FirebaseWorkoutBackupGateway(
        scope: scope,
        activeAccount: () => active,
        invoke: (input) async {
          final action = input['action'];
          return action == 'save'
              ? {
                  'schemaVersion': 1,
                  'status': 'backed_up',
                  'kind': record.kind,
                  'id': record.id,
                  'digest': record.digest
                }
              : {
                  'schemaVersion': 1,
                  'records': [
                    {
                      'kind': record.kind,
                      'id': record.id,
                      'digest': record.digest,
                      'payload': record.payload
                    }
                  ],
                  'nextCursor': null
                };
        });
    expect(await gateway.save(record, null), record.digest);
    expect((await gateway.list(null)).records.single.digest, record.digest);
    active = false;
    await expectLater(gateway.list(null), throwsA(isA<BackupFailure>()));
  });
}
