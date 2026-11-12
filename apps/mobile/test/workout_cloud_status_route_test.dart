import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_mobile/app/di/workout_backup_factory.dart';
import 'package:gainpath_mobile/app/routing/workout_cloud_save_status.dart';
import 'package:gainpath_mobile/features/workout/application/workout_backup_coordinator.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_backup.dart';
import 'package:gainpath_mobile/features/workout/domain/workout_contracts.dart';
import 'support/workout_analytics_fixture.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_result_screen.dart';
import 'routine_journey_controller_test.dart' as fixtures;
import 'workout_backup_test.dart' as support;

void main() {
  testWidgets(
      'read-only fixture status never parses an uploadable backup or claims a save',
      (tester) async {
    final original = WorkoutAnalyticsFixture().summaries.first;
    final summary = WorkoutSessionSummary(
        sessionId: original.sessionId,
        userId: original.userId,
        organizationId: original.organizationId,
        exerciseId: original.exerciseId,
        repetitions: original.repetitions,
        accuracy: original.accuracy,
        startedAt: original.startedAt,
        endedAt: original.endedAt,
        poseMetrics: original.poseMetrics,
        provenance: WorkoutProvenance.recordedFixture);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: WorkoutCloudSaveStatus.session(summary))));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsNothing);
    expect(find.text('Synced'), findsNothing);
    expect(find.text('Enable automatic sync'), findsNothing);
    expect(tester.takeException(), isNull);
    expect(locallySavedWorkoutRecord(summary), isNull);
    await tester.pumpWidget(
        MaterialApp(home: WorkoutResultScreen.measured(summary: summary)));
    await tester.pumpAndSettle();
    expect(find.text('Saved on this device'), findsNothing);
    expect(find.textContaining('no physical camera capture'), findsOneWidget);
  });
  for (final existingChoice in [false, true]) {
    testWidgets(
        'sync setup respects existing disabled preference $existingChoice',
        (tester) async {
      late AuthBloc auth;
      await tester.runAsync(() async {
        auth = AuthBloc(repository: InMemoryAuthRepository());
        if (auth.state.status != AuthStatus.signedOut) {
          await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
        }
        auth.add(const LoginSubmitted(
            email: 'member@example.com', password: 'password123'));
        await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
      });
      final scope = auth.state.session!.scope;
      final summary = fixtures.measured(scope, 'one');
      final row = WorkoutBackupRecord.session(summary);
      final remote = support.Remote();
      final metadata = support.Metadata(scope)
        ..state = BackupState(consentChoiceMade: existingChoice);
      var releases = 0;
      await tester.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: WorkoutCloudSaveStatus.session(summary,
                      factory: (scope, active) async {
            final c = WorkoutBackupCoordinator(
                scope: scope,
                activeScope: active,
                local: support.Local()..rows[row.key] = row,
                gateway: remote,
                store: metadata);
            return WorkoutBackupLease(c, () {
              releases++;
              c.dispose();
            });
          })))));
      await tester.pumpAndSettle();
      expect(find.text('Saved on this device'), findsOneWidget);
      expect(find.text('Enable automatic sync'),
          existingChoice ? findsNothing : findsOneWidget);
      expect(metadata.state.enabled, false);
      expect(remote.saves, 0);
      await tester.runAsync(() async {
        auth.add(const LoggedOut());
        await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
      });
      await tester.pumpAndSettle();
      expect(find.text('Synced'), findsNothing);
      expect(find.text('Enable automatic sync'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      expect(releases, 1);
      await tester.runAsync(auth.close);
    });
  }
}
