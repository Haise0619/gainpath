import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'package:gainpath_mobile/features/identity/presentation/shared/password_recovery_screen.dart';

void main() {
  testWidgets('Verifies pasted OTP and validates password confirmation',
      (tester) async {
    final operations = <String>[];
    const capture = bool.fromEnvironment('CAPTURE_RECOVERY_SCREENS');
    final screen = GlobalKey();
    if (capture) {
      await tester.binding.setSurfaceSize(const Size(390, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(() async {
        await (FontLoader('Barlow')
              ..addFont(rootBundle.load('assets/fonts/Barlow-Regular.ttf')))
            .load();
        final flutterRoot = Platform.environment['FLUTTER_ROOT'];
        if (flutterRoot != null) {
          final iconBytes = await File(
            '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ).readAsBytes();
          await (FontLoader('MaterialIcons')
                ..addFont(Future.value(ByteData.sublistView(iconBytes))))
              .load();
        }
      });
    }
    Future<void> screenshot(String name) async {
      if (!capture) return;
      await tester.runAsync(() async {
        final boundary =
            screen.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2);
        try {
          final bytes =
              (await image.toByteData(format: ui.ImageByteFormat.png))!;
          final file = File('build/password-recovery-screens/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        } finally {
          image.dispose();
        }
      });
    }

    await tester.pumpWidget(RepaintBoundary(
        key: screen,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: capture ? 'Barlow' : null,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary)
                .copyWith(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface),
            scaffoldBackgroundColor: AppColors.bg,
          ),
          home: PasswordRecoveryScreen(
            initialEmail: 'member@example.test',
            onEmailLink: () {},
            command: (input) async {
              operations.add(input['operation'] as String);
              switch (operations.last) {
                case 'requestPasswordResetOtp':
                  return {'challengeId': 'challenge', 'resendAfterSeconds': 30};
                case 'verifyPasswordResetOtp':
                  expect(input['code'], '842103');
                  return {'resetToken': 'token'};
                case 'completePasswordReset':
                  expect(input['password'], 'NewPassword12');
                  expect(input['resetToken'], 'token');
                  return {'success': true};
                default:
                  throw StateError('Unexpected operation');
              }
            },
          ),
        )));
    await screenshot('01-forgot-password');
    await tester.tap(find.text('Send verification code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('m•••@example.test'), findsOneWidget);
    expect(find.textContaining('Resend code in'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('recovery-code')), '842103');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await screenshot('02-verify-code');
    await tester.tap(find.text('Verify code'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'NewPassword12');
    await tester.enterText(find.byType(TextFormField).last, 'Mismatch12');
    await tester.tap(find.text('Reset password'));
    await tester.pump();
    expect(find.text('Passwords do not match.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).last, 'NewPassword12');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await screenshot('03-new-password');
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();
    expect(find.text('Password reset successful'), findsOneWidget);
    expect(operations.length, 3);
    await screenshot('04-success');
  });
}
