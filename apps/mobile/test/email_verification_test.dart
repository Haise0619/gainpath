import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/identity/presentation/shared/email_verification_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'verification awaits reload, rejects duplicate taps and shows failure',
      (tester) async {
    final pending = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: EmailVerificationScreen(
      email: 'member@example.com',
      onVerified: () {
        calls++;
        return pending.future;
      },
    )));
    await tester.tap(find.text("I've verified my email"));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(calls, 1);
    pending.completeError(const AuthException('Email is not verified yet.'));
    await tester.pump();
    expect(find.text('Email is not verified yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('failed resend does not claim the link was sent and can retry',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: EmailVerificationScreen(
      email: 'member@example.com',
      onResend: () async {
        throw const AuthException('Check your connection and retry.');
      },
    )));
    await tester.pump(const Duration(seconds: 30));
    await tester.tap(find.text('Resend verification link'));
    await tester.pump();
    expect(find.text('Check your connection and retry.'), findsOneWidget);
    expect(find.text('Link re-sent. Check your inbox again.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
