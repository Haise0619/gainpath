import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_auth_gateway.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:google_fonts/google_fonts.dart';

class _ResetAuth implements FirebaseAuth {
  final emails = <String>[];
  String? failure;
  @override
  Future<void> sendPasswordResetEmail(
      {required String email, ActionCodeSettings? actionCodeSettings}) async {
    emails.add(email);
    if (failure != null) {
      throw FirebaseAuthException(
          code: failure!, message: 'private SDK detail');
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _UnusedFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Admin reset invokes Firebase Auth and keeps unknown accounts neutral',
      () async {
    final auth = _ResetAuth();
    final gateway =
        FlutterFirebaseAuthGateway(auth: auth, firestore: _UnusedFirestore());
    await gateway.sendPasswordResetEmail(' admin@example.com ');
    expect(auth.emails, ['admin@example.com']);
    auth.failure = 'user-not-found';
    await gateway.sendPasswordResetEmail('missing@example.com');
    auth.failure = 'network-request-failed';
    await expectLater(
        gateway.sendPasswordResetEmail('admin@example.com'),
        throwsA(isA<AuthException>().having((error) => error.message,
            'safe message', 'Check your connection and retry.')));
    auth.failure = 'too-many-requests';
    await expectLater(
        gateway.sendPasswordResetEmail('admin@example.com'),
        throwsA(isA<AuthException>().having((error) => error.message,
            'safe message', 'Too many requests. Wait before trying again.')));
  });

  Future<void> open(
      WidgetTester tester, Future<void> Function(String) sender) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repository = InMemoryAuthRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(GainPathAdminWebApp.injected(
        authRepository: repository, passwordResetSender: sender));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, ' admin@example.com ');
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Firebase Admin reset waits for real sender before neutral success',
      (tester) async {
    final emails = <String>[];
    final pending = Completer<void>();
    await open(tester, (email) {
      emails.add(email);
      return pending.future;
    });
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(emails, ['admin@example.com']);
    expect(find.text('Check your email'), findsNothing);
    expect(
        tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
        isNull);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.textContaining('If an account exists'), findsOneWidget);
    expect(find.text('Demo only: no email was sent.'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'Firebase Admin reset failure stays retryable without false success',
      (tester) async {
    var fail = true;
    await open(tester, (_) async {
      if (fail) throw const AuthException('Check your connection and retry.');
    });
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your connection and retry.'), findsOneWidget);
    expect(find.text('Check your email'), findsNothing);
    fail = false;
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.textContaining('If an account exists'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
