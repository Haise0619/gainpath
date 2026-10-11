import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_mobile/main.dart';
import 'package:google_fonts/google_fonts.dart';

class _FailingGateway implements FirebaseAuthGateway, FirebaseAuthSessionGateway {
  final _users = StreamController<FirebaseAuthUser?>.broadcast();

  @override
  Stream<FirebaseAuthUser?> get userChanges => _users.stream;

  @override
  Future<FirebaseAuthUser?> restoreUser() async => null;

  @override
  Future<FirebaseAuthUser> signIn({required String email, required String password}) async {
    throw const AuthException('Email or password is incorrect.');
  }

  @override
  Future<FirebaseAuthUser> register({required String email, required String password,
      required String name}) async {
    throw const AuthException('This email is already registered.');
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<void> signOut() async {
    _users.add(null);
  }

  Future<void> dispose() => _users.close();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('Firebase sign-in failure stays visible after provider sign-out', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = _FailingGateway();
    final repository = FirebaseAuthRepository(gateway);
    await tester.pumpWidget(GainPathMobileApp(
      authRepository: repository,
      backendConfig: const BackendConfig(BackendMode.firebase),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty);
    await tester.enterText(find.byType(TextField).at(0), 'member@example.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Email or password is incorrect.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('registration terms error stays on the form', (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final gateway = _FailingGateway();
    final repository = FirebaseAuthRepository(gateway);
    await tester.pumpWidget(GainPathMobileApp(
      authRepository: repository,
      backendConfig: const BackendConfig(BackendMode.firebase),
    ));
    await tester.pumpAndSettle();
    final register = find.text('New here? Create an account');
    await tester.ensureVisible(register);
    await tester.tap(register);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Test Member');
    await tester.enterText(find.byType(TextField).at(1), 'member@example.com');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.enterText(find.byType(TextField).at(3), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Agree to the Terms and Privacy Policy to continue.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('Agree to the Terms and Privacy Policy to continue.'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('This email is already registered.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    expect(find.text('This email is already registered.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
