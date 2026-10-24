import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/system_settings_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
void main() {
 setUpAll(()=>GoogleFonts.config.allowRuntimeFetching=false);
 testWidgets('Google integration uses the existing System Settings and shared disabled preview', (tester) async {
  tester.view.physicalSize=const Size(1400,1000);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme:AppTheme.build(),home:const SystemSettingsScreen()));await tester.pumpAndSettle();
  await tester.tap(find.text('Google integration'));await tester.pumpAndSettle();
  expect(find.byType(GoogleIntegrationPanel),findsOneWidget);expect(find.textContaining('Preview mode'),findsOneWidget);
  expect(tester.widget<FilledButton>(find.byWidgetPredicate((w)=>w is FilledButton)).onPressed,isNull);
 });
}
