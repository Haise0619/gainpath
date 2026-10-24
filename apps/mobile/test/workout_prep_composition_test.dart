import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mock_app_scope.dart';
import 'package:gainpath_mobile/app/shells/member_shell.dart';
import 'package:gainpath_mobile/app/routing/pose_preview_route.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('mock Home workout entry also retains native preview composition',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        const MockAppScope(child: MaterialApp(home: MemberShell())));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.scrollUntilVisible(find.text('Start workout'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Start workout'));
    await tester.pumpAndSettle();
    final screen =
        tester.widget<WorkoutPrepScreen>(find.byType(WorkoutPrepScreen));
    expect(screen.live, isFalse);
    expect(screen.routes.posePreviewBuilder, isNotNull);
    expect(
        screen.routes.posePreviewBuilder!(
            tester.element(find.byType(WorkoutPrepScreen))),
        isA<PosePreviewRoute>());
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('mock shell retains an app-composed native preview destination',
      (tester) async {
    await tester.pumpWidget(
        const MockAppScope(child: MaterialApp(home: MemberShell())));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Workout').last);
    await tester.pumpAndSettle();
    final screen =
        tester.widget<WorkoutPrepScreen>(find.byType(WorkoutPrepScreen));
    expect(screen.live, isFalse);
    expect(screen.routes.posePreviewBuilder, isNotNull);
    final context = tester.element(find.byType(WorkoutPrepScreen));
    expect(screen.routes.posePreviewBuilder!(context), isA<PosePreviewRoute>());
    await tester.pumpWidget(const SizedBox());
  });
}
