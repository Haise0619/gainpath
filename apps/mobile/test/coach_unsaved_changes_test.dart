import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_mobile/features/identity/application/coach_profile_cubit.dart';
import 'package:gainpath_mobile/features/identity/presentation/coach/live_coach_profile_views.dart';
import 'coach_profile_state_test.dart' show ProfileFake;

void main() {
  testWidgets(
      'Coach editor requires explicit discard before leaving a dirty draft',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final controller =
        CoachProfileCubit(repository: ProfileFake(), isCurrent: () => true);
    await controller.reload();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => LiveCoachProfileEditor(
                                controller: controller))),
                    child: const Text('Open editor'))))));
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byWidgetPredicate((widget) =>
            widget is TextField && widget.decoration?.labelText == 'Bio'),
        'Unsaved professional bio');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    expect(find.byType(LiveCoachProfileEditor), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(LiveCoachProfileEditor), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await controller.close();
  });
}
