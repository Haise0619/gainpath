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

class _RecommendationProbe extends StatefulWidget {
  const _RecommendationProbe(this.onMount);
  final VoidCallback onMount;

  @override
  State<_RecommendationProbe> createState() => _RecommendationProbeState();
}

class _RecommendationProbeState extends State<_RecommendationProbe> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: 120, child: Text('Recommendation probe'));
}

void main() {
  setUpAll(loadDemoRenderFonts);

  testWidgets('registered classes destination starts in My Classes Upcoming',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: MemberGroupClassesScreen(
        startInMyClasses: true,
        call: (_, __) async => {'classes': []},
        onUpgrade: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('My Classes'), findsOneWidget);
    final upcoming = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Upcoming'),
    );
    expect(upcoming.selected, isTrue);
  });

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
    Widget? recommendations,
    Widget? upcomingClasses,
    Set<FitnessGoal> goals = const {FitnessGoal.buildMuscle},
    double scale = 1,
  }) {
    return RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
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
              goals: goals,
            ),
            upcomingClasses: upcomingClasses,
            publishedRoutine: testRoutine(),
            appCheckIn: const AppCheckInState(
              status: AppCheckInStatus.ready,
              message: 'Checked in today',
            ),
            recommendations: recommendations ??
                Builder(
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

  for (final width in [320.0, 360.0, 393.0, 430.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('compact Home sections fit ${width.toInt()}dp at ${scale}x',
          (tester) async {
        final restore = await installFypOfflineFonts();
        addTearDown(restore);
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 852);
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        final start = DateTime.utc(2026, 11, 30, 2).millisecondsSinceEpoch;
        final nearest = <String, dynamic>{
          'id': 'next',
          'title': 'Yoga and mobility for healthy movement',
          'venue': 'Training Studio',
          'branchName': 'GainPath International Performance Centre',
          'startAtMillis': start,
          'endAtMillis': start + 3600000,
          'status': 'Open',
          'registration': {'status': 'Registered'},
        };
        String? opened;
        var openedAll = false;
        await tester.pumpWidget(createTestWidget(
          theme: AppTheme.build(),
          captureKey: key,
          scale: scale,
          goals: {
            FitnessGoal.generalFitness,
            FitnessGoal.increaseFlexibility,
            FitnessGoal.reduceStress,
          },
          upcomingClasses: UpcomingGroupClasses(
            call: (_, __) async => {
              'serverNowMillis': start - 5000,
              'classes': [
                {...nearest, 'title': 'Cancelled class', 'status': 'Cancelled'},
                {
                  ...nearest,
                  'title': 'Later class',
                  'startAtMillis': start + 3600000
                },
                nearest,
              ],
            },
            onOpen: (id) async => opened = id,
            onExplore: () async {},
            onViewAll: () async => openedAll = true,
          ),
        ));
        await tester.pumpAndSettle();
        final scroll = find.byType(Scrollable).first;
        await tester.scrollUntilVisible(find.text('+1 more'), 250,
            scrollable: scroll);
        await tester.pumpAndSettle();
        final cls = find.text('Yoga and mobility for healthy movement');
        expect(find.text('Announcements'), findsNothing);
        expect(find.text('Cancelled class'), findsNothing);
        expect(find.text('Later class'), findsNothing);
        expect(find.text('10:00–11:00 MYT'), findsOneWidget);
        expect(find.text('General fitness'), findsOneWidget);
        expect(find.text('Increase flexibility'), findsOneWidget);
        expect(find.text('Reduce stress'), findsNothing);
        expect(tester.takeException(), isNull);
        if (width == 393 && scale == 1) {
          final boundary =
              tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1.5);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final file = File(
                '../../build/home-goals-classes/home-upcoming-classes-and-goals.png');
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.ensureVisible(cls);
          await tester.tap(cls);
          await tester.pumpAndSettle();
          expect(opened, 'next');
          final viewAll = find.widgetWithText(TextButton, 'View all').last;
          await tester.ensureVisible(viewAll);
          await tester.tap(viewAll);
          await tester.pumpAndSettle();
          expect(openedAll, isTrue);
        }
      });
    }
  }

  testWidgets('scrolling away retains the loaded recommendation section',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 450);
    addTearDown(tester.view.reset);
    var mounts = 0;
    await tester.pumpWidget(createTestWidget(
      theme: AppTheme.build(),
      captureKey: const ValueKey('home'),
      recommendations: _RecommendationProbe(() => mounts++),
    ));
    final scroll = find.byType(Scrollable).first;
    final probe = find.text('Recommendation probe');
    await tester.scrollUntilVisible(probe, 150, scrollable: scroll);
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(scroll).position;
    final recommendationOffset = position.pixels;
    position.jumpTo(0);
    await tester.pumpAndSettle();
    expect(probe.hitTestable(), findsNothing);
    position.jumpTo(recommendationOffset);
    await tester.pumpAndSettle();
    expect(probe.hitTestable(), findsOneWidget);
    expect(mounts, 1);
  });

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
