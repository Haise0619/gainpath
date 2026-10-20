import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_account_recovery_screen.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_deactivation_dialog.dart';

MemberAccountLifecycle status({bool pending = false, bool allowed = false}) =>
    MemberAccountLifecycle(
        state: pending ? 'pendingDeletion' : 'active',
        revision: pending ? 1 : 0,
        requestedAtMillis: pending ? 1000000 : null,
        retentionEndsAtMillis: pending ? 2593000000 : null,
        policy: pending ? 'grace30Days' : 'pendingApproval',
        sessionNotBeforeSeconds: pending ? 1001 : 0,
        sessionRevocationPending: false,
        reactivationAllowed: allowed,
        reactivationAvailableAtMillis: pending ? 4900000 : null,
        currentTimeMillis: allowed ? 5000000 : 1200000,
        lastRequestId: pending ? 'request_0001' : null,
        editBaseline: Object());

class _Repository implements MemberAccountLifecycleRepository {
  MemberAccountLifecycle current = status();
  String? password;
  int requests = 0, cancellations = 0;
  bool fail = false;
  @override
  Future<MemberAccountLifecycle> load() async => current;
  @override
  Future<void> verifyCurrentPassword(String value) async {
    if (value != 'correct') {
      throw const MemberAccountLifecycleException('Incorrect password.');
    }
    password = value;
  }

  @override
  Future<MemberAccountLifecycle> requestDeactivation(
      MemberAccountLifecycle original) async {
    requests++;
    if (fail) {
      throw const MemberAccountLifecycleException('Unconfirmed.',
          uncertain: true);
    }
    return current = status(pending: true);
  }

  @override
  Future<MemberAccountLifecycle> cancelDeactivation(
      MemberAccountLifecycle original) async {
    cancellations++;
    if (fail) {
      throw const MemberAccountLifecycleException('Unconfirmed.',
          uncertain: true);
    }
    return current = status();
  }
}

void main() {
  testWidgets(
      'deactivation requires password and returns success only after confirmed pending state',
      (tester) async {
    final repo = _Repository();
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              MemberDeactivationDialog(repository: repo));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('lifecycle-password')), 'wrong');
    await tester.tap(find.text('Confirm deactivation'));
    await tester.pumpAndSettle();
    expect(repo.requests, 0);
    expect(result, isNull);
    expect(find.text('Incorrect password.'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('lifecycle-password')), 'correct');
    await tester.tap(find.text('Confirm deactivation'));
    await tester.pumpAndSettle();
    expect(repo.requests, 1);
    expect(repo.password, 'correct');
    expect(result, isTrue);
  });
  testWidgets(
      'pending recovery respects trusted cooldown and confirms password before cancellation',
      (tester) async {
    final repo = _Repository()..current = status(pending: true);
    var restored = 0, signedOut = 0;
    await tester.pumpWidget(MaterialApp(
        home: MemberAccountRecoveryScreen(
            repository: repo,
            onRestored: () => restored++,
            onSignedOut: () => signedOut++)));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Keep my account'))
            .onPressed,
        isNull);
    expect(find.textContaining('65-minute'), findsOneWidget);
    repo.current = status(pending: true, allowed: true);
    await tester.tap(find.text('Refresh account status'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('lifecycle-password')), 'correct');
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(repo.cancellations, 1);
    expect(restored, 1);
    expect(signedOut, 0);
  });
  testWidgets(
      'unconfirmed restore retains recovery gate and never enters protected app',
      (tester) async {
    final repo = _Repository()
      ..current = status(pending: true, allowed: true)
      ..fail = true;
    var restored = 0;
    await tester.pumpWidget(MaterialApp(
        home: MemberAccountRecoveryScreen(
            repository: repo,
            onRestored: () => restored++,
            onSignedOut: () {})));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('lifecycle-password')), 'correct');
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(restored, 0);
    expect(find.text('Unconfirmed.'), findsOneWidget);
  });
  testWidgets(
      'uncertain deactivation offers status reload and safe sign-out without claiming success',
      (tester) async {
    final repo = _Repository()..fail = true;
    bool? result;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      result = await showDialog<bool>(
                          context: context,
                          builder: (_) =>
                              MemberDeactivationDialog(repository: repo));
                    },
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('lifecycle-password')), 'correct');
    await tester.tap(find.text('Confirm deactivation'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('Reload account status'), findsOneWidget);
    expect(find.text('Sign out and check status'), findsOneWidget);
    repo.current = status(pending: true);
    await tester.tap(find.text('Reload account status'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
