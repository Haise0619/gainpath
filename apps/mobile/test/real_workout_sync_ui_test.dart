import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/real_workout_sync_panel.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_contract.dart';
import 'package:gainpath_mobile/features/workout/domain/real_workout_sync_presentation.dart';
import 'package:gainpath_mobile/features/workout/data/real_workout_outbox_repository.dart';
import 'real_workout_outbox_test.dart' as support;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'domain sync state updates retry controls without a data repository',
      (tester) async {
    final state = _SyncPresentation();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: RealWorkoutSyncPanel(
                repository: state, sessionId: 'session'))));
    expect(find.text('Local result only'), findsOneWidget);
    expect(find.textContaining('server revocation is pending'), findsOneWidget);
    await tester.tap(find.text('Retry sync'));
    await tester.pumpAndSettle();
    expect(find.textContaining('server revocation is pending'), findsNothing);
    expect(find.text('Retry sync'), findsNothing);
    expect(find.text('Server accepted'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
  });
  testWidgets('pending retry becomes accepted only after durable valid receipt',
      (tester) async {
    final gateway = support.Gateway();
    final repo = RealWorkoutOutboxRepository(
        scope: support.scope,
        activeScope: () => support.scope,
        store: MemoryRealWorkoutSyncStore(scope: support.scope),
        gateway: gateway,
        newRequestId: () => 'request');
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(support.measured(), ack);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                RealWorkoutSyncPanel(repository: repo, sessionId: 'session'))));
    expect(find.text('Upload pending'), findsOneWidget);
    expect(find.text('Server accepted'), findsNothing);
    gateway.failure = 'unavailable';
    await tester.tap(find.text('Retry sync'));
    await tester.pumpAndSettle();
    expect(find.text('Upload needs retry'), findsOneWidget);
    gateway.failure = null;
    await tester.tap(find.text('Retry sync'));
    await tester.pumpAndSettle();
    expect(find.text('Server accepted'), findsOneWidget);
    expect(find.text('Retry sync'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets('disabled model rejection stays local and cannot loop retry',
      (tester) async {
    final gateway = support.Gateway()..failure = 'failed-precondition';
    final repo = RealWorkoutOutboxRepository(
        scope: support.scope,
        activeScope: () => support.scope,
        store: MemoryRealWorkoutSyncStore(scope: support.scope),
        gateway: gateway,
        newRequestId: () => 'request');
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(support.measured(), ack);
    await repo.sync();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                RealWorkoutSyncPanel(repository: repo, sessionId: 'session'))));
    expect(find.text('Upload not accepted'), findsOneWidget);
    expect(find.textContaining('physical validation'), findsOneWidget);
    expect(find.text('Server accepted'), findsNothing);
    expect(find.text('Retry sync'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets(
      'revocation confirmation disables future uploads while retaining accepted result',
      (tester) async {
    final repo = RealWorkoutOutboxRepository(
        scope: support.scope,
        activeScope: () => support.scope,
        store: MemoryRealWorkoutSyncStore(scope: support.scope),
        gateway: support.Gateway(),
        newRequestId: () => 'request');
    await repo.load();
    final ack = (await repo.acknowledgeConsent())!;
    await repo.enqueue(support.measured(), ack);
    await repo.sync();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                RealWorkoutSyncPanel(repository: repo, sessionId: 'session'))));
    await tester.tap(find.text('Disable workout uploads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Disable uploads'));
    await tester.pumpAndSettle();
    expect(repo.consent, isNull);
    expect(find.text('Server accepted'), findsOneWidget);
    expect(find.text('Disable workout uploads'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
}

class _SyncPresentation extends ChangeNotifier
    implements RealWorkoutSyncPresentation {
  @override
  List<RealWorkoutSyncEntry> get entries => const [];
  @override
  WorkoutConsentAcknowledgement? get consent => null;
  @override
  bool revocationPending = true;
  @override
  bool get syncing => false;
  @override
  Future<void> sync() async {
    revocationPending = false;
    notifyListeners();
  }

  @override
  Future<void> revokeConsent() async =>
      throw StateError('No consent to revoke.');
}
