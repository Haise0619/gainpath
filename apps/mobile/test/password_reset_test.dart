import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_mobile/main.dart';
import 'package:gainpath_mobile/navigation/auth_navigation.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_password_actions.dart';
import 'package:google_fonts/google_fonts.dart';

class ResetAuth implements FirebaseAuth {
  final emails = <String>[];
  String? failure;
  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    emails.add(email);
    if (failure != null) throw FirebaseAuthException(code: failure!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  test('reset action calls actual Firebase SDK operation with trimmed email',
      () async {
    final auth = ResetAuth();
    await FirebasePasswordResetActions(auth: auth).send(' member@example.com ');
    expect(auth.emails, ['member@example.com']);
  });
  test(
      'unknown account gets the same neutral outcome; transport/rate errors are surfaced',
      () async {
    final auth = ResetAuth()..failure = 'user-not-found';
    final action = FirebasePasswordResetActions(auth: auth);
    await action.send('missing@example.com');
    auth.failure = 'network-request-failed';
    await expectLater(
        action.send('member@example.com'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains('connection'))));
    auth.failure = 'too-many-requests';
    await expectLater(
        action.send('member@example.com'),
        throwsA(isA<AuthException>()
            .having((e) => e.message, 'message', contains('Too many'))));
  });
  Future<void> open(
      WidgetTester tester, Future<void> Function(String) sender) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GainPathMobileApp(
        authRepository: InMemoryAuthRepository(),
        backendConfig: const BackendConfig(BackendMode.firebase),
        passwordResetSender: sender));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField).first, ' member@example.com ');
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
  }

  testWidgets('named login recovery also uses the Firebase-mode sender',
      (tester) async {
    final emails = <String>[];
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(GainPathMobileApp(
        authRepository: InMemoryAuthRepository(),
        backendConfig: const BackendConfig(BackendMode.firebase),
        passwordResetSender: (email) async => emails.add(email)));
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .pushNamed(AppRoutes.login);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'member@example.com');
    await tester.ensureVisible(find.text('Forgot password?'));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(emails, ['member@example.com']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Firebase login recovery waits for real request and permits one request per click',
      (tester) async {
    final emails = <String>[];
    final complete = Completer<void>();
    await open(tester, (email) {
      emails.add(email);
      return complete.future;
    });
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(emails, ['member@example.com']);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    expect(find.text('Check your email'), findsNothing);
    complete.complete();
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(find.textContaining('15 minutes'), findsNothing);
    expect(find.text('Resend in 30s'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('failed reset stays on form with retry and never says email sent',
      (tester) async {
    var fail = true;
    var calls = 0;
    await open(tester, (_) async {
      calls++;
      if (fail) throw const AuthException('Check your connection and retry.');
    });
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your connection and retry.'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    expect(calls, 1);
    fail = false;
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Check your email'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'resend invokes the sender again and invalid addresses never send',
      (tester) async {
    final emails = <String>[];
    await open(tester, (email) async => emails.add(email));
    await tester.enterText(find.byType(TextField).last, 'bad-address');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(emails, isEmpty);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'member@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Didn't get it? Resend"));
    await tester.pumpAndSettle();
    expect(emails, ['member@example.com', 'member@example.com']);
    await tester.pumpWidget(const SizedBox());
  });
}
