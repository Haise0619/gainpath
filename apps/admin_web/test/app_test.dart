import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/main.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('admin web app host boots', (tester) async {
    await tester.pumpWidget(const GainPathAdminWebApp());
    await tester.pumpAndSettle();
    expect(find.text('GainPath Admin Web'), findsOneWidget);
    expect(find.text('Administrator sign-in'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
  });
}
