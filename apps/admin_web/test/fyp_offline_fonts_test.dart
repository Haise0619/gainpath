import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_admin_web/app/admin_app.dart';
import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets(
      'ordinary Admin login renders using offline test font registration',
      (tester) async {
    final restoreFonts = await installFypOfflineFonts();
    addTearDown(restoreFonts);
    await tester.pumpWidget(
        GainPathAdminWebApp.injected(authRepository: InMemoryAuthRepository()));
    await tester.pumpAndSettle();
    expect(find.text('Administrator sign-in'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
