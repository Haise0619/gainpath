import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/workout/data/published_routine.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(loadDemoRenderFonts);

  const testSession = AuthSession(
    userId: 'member1',
    organizationId: 'gym1',
    email: 'test@gainpath.test',
    displayName: 'Alex',
    role: AppRole.member,
  );

  PublishedRoutine testRoutine() => PublishedRoutine.fromDocument('routine1', {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': 'blueprint1',
        'title': 'Full Body Foundations',
        'estimatedMinutes': 30,
        'exercises': [
          {
            'exerciseId': 'ex1',
            'name': 'Dumbbell Squat',
            'sets': 3,
            'reps': 10,
            'category': 'Legs',
          }
        ],
      });

  Widget createTestWidget({
    required ThemeData theme,
    required Key captureKey,
  }) {
    return RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        home: Scaffold(
          body: MemberHomeScreen(
            liveSession: testSession,
            liveProfile: FitnessProfile(
              gender: ProfileGender.unspecified,
              age: 26,
              heightCm: 175,
              weightKg: 70,
              experience: TrainingExperience.beginner,
              activity: ActivityLevel.moderatelyActive,
              goals: {FitnessGoal.buildMuscle},
            ),
            publishedRoutine: testRoutine(),
            appCheckIn: const AppCheckInState(
              status: AppCheckInStatus.ready,
              message: 'Checked in today',
            ),
            recommendations: Builder(
              builder: (context) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Recommended for You',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('View all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Panel(
                    padding: const EdgeInsets.all(16),
                    child: const Text('Full Body Strength & Conditioning'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'every home page section title matches recommendation section titleLarge style',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final captureKey = GlobalKey();
    final theme = AppTheme.build();
    await tester
        .pumpWidget(createTestWidget(theme: theme, captureKey: captureKey));
    await tester.pumpAndSettle();

    final expectedTitleLarge = theme.textTheme.titleLarge!;

    // Find all section titles
    final sectionTitles = [
      'Daily check-in',
      "Today's workout",
      'Weekly progress',
      'Recent activity',
      'Recommended for You',
      'Quick access',
      'Your goals',
    ];

    for (final title in sectionTitles) {
      final finder = find.text(title);
      expect(finder, findsAtLeastNWidgets(1),
          reason: 'Section title "$title" must be present');
      final textWidget = tester.widget<Text>(finder.first);
      expect(textWidget.style?.fontSize, equals(expectedTitleLarge.fontSize),
          reason:
              'Section "$title" fontSize must match recommendation section titleLarge');
      expect(
          textWidget.style?.fontWeight, equals(expectedTitleLarge.fontWeight),
          reason:
              'Section "$title" fontWeight must match recommendation section titleLarge');
      expect(textWidget.style?.color, equals(expectedTitleLarge.color),
          reason:
              'Section "$title" color must match recommendation section titleLarge');
    }

    // Capture screenshot of the full home view
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
          'build/member-ui-renders/home_page_consistent_section_titles.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets(
      'every section title under buildMemberTypographyTheme matches recommendation style',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);

    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final captureKey = GlobalKey();
    final memberTheme = buildMemberTypographyTheme();
    await tester.pumpWidget(
        createTestWidget(theme: memberTheme, captureKey: captureKey));
    await tester.pumpAndSettle();

    final expectedTitleLarge = memberTheme.textTheme.titleLarge!;

    final sectionTitles = [
      'Daily check-in',
      "Today's workout",
      'Weekly progress',
      'Recent activity',
      'Recommended for You',
      'Quick access',
      'Your goals',
    ];

    for (final title in sectionTitles) {
      final finder = find.text(title);
      expect(finder, findsAtLeastNWidgets(1),
          reason: 'Section title "$title" must be present');
      final textWidget = tester.widget<Text>(finder.first);
      expect(textWidget.style?.fontSize, equals(expectedTitleLarge.fontSize),
          reason:
              'Section "$title" fontSize must match recommendation section titleLarge');
      expect(
          textWidget.style?.fontWeight, equals(expectedTitleLarge.fontWeight),
          reason:
              'Section "$title" fontWeight must match recommendation section titleLarge');
      expect(
          textWidget.style?.fontFamily, equals(expectedTitleLarge.fontFamily),
          reason:
              'Section "$title" fontFamily must match recommendation section titleLarge');
    }

    // Capture screenshot of the member typography theme view
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.5);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File(
          'build/member-ui-renders/home_page_member_typography_titles.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}
