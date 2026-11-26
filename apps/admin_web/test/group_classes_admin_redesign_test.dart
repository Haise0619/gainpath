import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/group_classes/group_classes_admin.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';
import '../../../test_support/member_demo_render_fonts.dart';

void main() {
  setUpAll(loadDemoRenderFonts);

  final start = DateTime.utc(2026, 11, 28, 2).millisecondsSinceEpoch;

  final sampleClasses = [
    <String, dynamic>{
      'id': 'class-strength',
      'title': 'Strength Lab',
      'description': 'A full-body strength class built around simple lifting patterns.',
      'category': 'Strength',
      'branchId': 'main',
      'branchName': 'Downtown Flagship',
      'coachId': 'coach-1',
      'instructor': 'Alicia Tan',
      'specialty': 'Strength & Conditioning',
      'venue': 'Studio A',
      'startAtMillis': start + 86400000, // Upcoming
      'endAtMillis': start + 86400000 + 3600000,
      'activeCount': 12,
      'capacity': 16,
      'status': 'Open',
      'state': 'Published',
      'difficulty': 'All levels',
      'eligibility': 'All Members',
      'cancellationCount': 1,
    },
    <String, dynamic>{
      'id': 'class-yoga',
      'title': 'Sunset Yoga Flow',
      'description': 'Gentle restorative yoga with deep stretches and breathwork.',
      'category': 'Yoga',
      'branchId': 'west',
      'branchName': 'Westside Hub',
      'coachId': 'coach-2',
      'instructor': 'Marcus Lim',
      'specialty': 'Mobility & Flexibility',
      'venue': 'Zen Studio',
      'startAtMillis': start - 86400000, // Past
      'endAtMillis': start - 86400000 + 3600000,
      'activeCount': 16,
      'capacity': 16,
      'status': 'Completed',
      'state': 'Published',
      'difficulty': 'Intermediate',
      'eligibility': 'Paid Members',
      'cancellationCount': 0,
      'attendedCount': 14,
      'absentCount': 2,
    },
    <String, dynamic>{
      'id': 'class-draft',
      'title': 'Cardio Blast Draft',
      'description': 'High-octane interval conditioning session.',
      'category': 'Cardio',
      'branchId': 'main',
      'branchName': 'Downtown Flagship',
      'venue': 'Gym Floor',
      'instructor': 'Guest Instructor John',
      'startAtMillis': start + 172800000,
      'endAtMillis': start + 172800000 + 3600000,
      'activeCount': 0,
      'capacity': 20,
      'status': 'Draft',
      'state': 'Draft',
      'difficulty': 'Advanced',
      'eligibility': 'Premium Only',
      'cancellationCount': 0,
    },
  ];

  group('Admin Group Classes Workspace', () {
    testWidgets('Workspace renders operational metrics and filters by tab, search, and branch',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            call: (action, input) async {
              return {'classes': sampleClasses};
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Header & Primary CTA
      expect(find.text('Group Classes'), findsOneWidget);
      expect(find.text('Create class'), findsOneWidget);
      expect(find.text('Total classes'), findsOneWidget);

      // Navigation tabs verified
      expect(find.widgetWithText(ChoiceChip, 'All Classes'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Upcoming'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Past'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Drafts'), findsOneWidget);

      // Classes visible
      expect(find.text('Strength Lab'), findsOneWidget);
      expect(find.text('Sunset Yoga Flow'), findsOneWidget);
      expect(find.text('Cardio Blast Draft'), findsOneWidget);

      // Filter by tab: Upcoming
      await tester.tap(find.widgetWithText(ChoiceChip, 'Upcoming'));
      await tester.pumpAndSettle();
      expect(find.text('Strength Lab'), findsOneWidget);
      expect(find.text('Sunset Yoga Flow'), findsNothing);
      expect(find.text('Cardio Blast Draft'), findsNothing);

      // Filter by tab: Drafts
      await tester.tap(find.widgetWithText(ChoiceChip, 'Drafts'));
      await tester.pumpAndSettle();
      expect(find.text('Cardio Blast Draft'), findsOneWidget);
      expect(find.text('Strength Lab'), findsNothing);

      // Reset to All
      await tester.tap(find.widgetWithText(ChoiceChip, 'All Classes'));
      await tester.pumpAndSettle();

      // Search filter
      await tester.enterText(find.byType(TextField).first, 'Yoga');
      await tester.pumpAndSettle();
      expect(find.text('Sunset Yoga Flow'), findsOneWidget);
      expect(find.text('Strength Lab'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Strength Lab'), findsOneWidget);
      expect(find.text('Sunset Yoga Flow'), findsOneWidget);
    });

    testWidgets('Empty workspace renders friendly zero-state and CTA',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            key: const Key('empty-page'),
            call: (action, input) async => {'classes': []},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No group classes yet'), findsOneWidget);
      expect(find.text('Create class'), findsNWidgets(2));
    });

    testWidgets('Filtered search with zero matching classes displays reset filter CTA',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            key: const Key('filtered-page'),
            call: (action, input) async => {'classes': sampleClasses},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'NonExistentXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No classes match the current filters.'), findsOneWidget);
      expect(find.text('Reset filters'), findsOneWidget);

      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('Strength Lab'), findsOneWidget);
    });

    testWidgets('3-step Class Builder wizard navigation and live preview',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var savedDraft = false;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            call: (action, input) async {
              if (action == 'options') {
                return {
                  'branches': [
                    {'id': 'main', 'name': 'Downtown Flagship'}
                  ],
                  'coaches': [
                    {'id': 'coach-1', 'name': 'Alicia Tan'}
                  ],
                };
              }
              if (action == 'save' || action == 'create') {
                savedDraft = true;
                return {'saved': true};
              }
              return {'classes': sampleClasses};
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Class Builder
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();

      // Step 1: Details & Media with breadcrumb bar: Home > Group Classes > Class Builder
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Group Classes'), findsWidgets);
      expect(find.text('Class Builder'), findsOneWidget);
      expect(find.byTooltip('Cancel'), findsOneWidget);
      expect(find.text('1. Class Details'), findsOneWidget);
      expect(find.text('Live Class Preview'), findsOneWidget);

      // Fill Step 1 required title & description
      await tester.enterText(find.byType(TextFormField).first, 'Zumba Fiesta');
      await tester.enterText(find.byType(TextFormField).last, 'High-energy dance workout.');
      await tester.pumpAndSettle();

      // Next to Step 2
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 2: Schedule & Instructor
      expect(find.text('2. Schedule & Coach'), findsOneWidget);
      expect(find.text('Internal Coach'), findsOneWidget);
      expect(find.text('Guest Instructor'), findsOneWidget);

      // Next to Step 3
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      // Step 3: Capacity & Rules
      expect(find.text('3. Capacity & Publish'), findsOneWidget);
      expect(find.text('Save Draft'), findsWidgets);
      expect(find.text('Publish Class'), findsOneWidget);

      // Back to Step 2
      await tester.tap(find.text('Previous Step'));
      await tester.pumpAndSettle();
      expect(find.text('2. Schedule & Coach'), findsOneWidget);

      // Forward to Step 3 and save draft
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(OutlinedButton, 'Save Draft'));
      await tester.pumpAndSettle();
      expect(savedDraft, isTrue);
      expect(find.text('Total classes'), findsOneWidget);
    });

    testWidgets('Class Builder breadcrumb navigation returns back to catalog',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            call: (action, input) async {
              if (action == 'options') {
                return {'branches': [], 'coaches': []};
              }
              return {'classes': sampleClasses};
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Class Builder
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Class Builder'), findsOneWidget);
      expect(find.text('Total classes'), findsNothing);

      // Tap "Group Classes" crumb
      await tester.tap(find.widgetWithText(InkWell, 'Group Classes'));
      await tester.pumpAndSettle();

      // Returned to catalog
      expect(find.text('Total classes'), findsOneWidget);
      expect(find.text('Class Builder'), findsNothing);

      // Open again and tap back button (arrow)
      await tester.tap(find.text('Create class'));
      await tester.pumpAndSettle();
      expect(find.text('Class Builder'), findsOneWidget);

      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Total classes'), findsOneWidget);
    });

    testWidgets(
        'Edit class from detail drawer transitions in-page with Edit Class breadcrumb',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            call: (action, input) async {
              if (action == 'detail') {
                return {'item': sampleClasses[0], 'participants': []};
              }
              if (action == 'options') {
                return {'branches': [], 'coaches': []};
              }
              return {'classes': sampleClasses};
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open details for first class
      await tester.tap(find.text('Strength Lab'));
      await tester.pumpAndSettle();

      expect(find.text('Edit class'), findsOneWidget);
      await tester.tap(find.text('Edit class'));
      await tester.pumpAndSettle();

      // In-page editor with Edit Class crumb
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Group Classes'), findsWidgets);
      expect(find.text('Edit Class'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);

      // Cancel returns to catalog
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Total classes'), findsOneWidget);
    });

    testWidgets('Admin Class Details drawer tabs and attendance marking',
        (tester) async {
      addTearDown(await installFypOfflineFonts());
      tester.view.physicalSize = const Size(1280, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var markedAttended = false;
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Scaffold(
          body: GroupClassesAdminPage(
            call: (action, input) async {
              if (action == 'detail') {
                return {
                  'item': sampleClasses[1], // Completed class
                  'participants': [
                    {
                      'name': 'Alicia Wong',
                      'memberId': 'mem-1',
                      'status': 'Registered',
                      'attended': null,
                    },
                  ],
                };
              }
              if (action == 'attendance') {
                markedAttended = true;
                return {'saved': true};
              }
              return {'classes': sampleClasses};
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open completed class details
      await tester.tap(find.text('Sunset Yoga Flow'));
      await tester.pumpAndSettle();

      expect(find.text('Class details'), findsOneWidget);
      expect(find.text('All Sections'), findsOneWidget);
      expect(find.text('Overview'), findsWidgets);
      expect(find.textContaining('Participants'), findsWidgets);
      expect(find.text('Attendance'), findsWidgets);

      // Switch to Attendance tab
      await tester.tap(find.widgetWithText(InkWell, 'Attendance'));
      await tester.pumpAndSettle();

      expect(find.text('Alicia Wong'), findsOneWidget);
      expect(find.text('Attended'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);

      await tester.tap(find.text('Attended'));
      await tester.pumpAndSettle();
      expect(markedAttended, isTrue);
    });
  });

  group('Responsive Viewports for Admin Workspace', () {
    final desktopWidths = [1024.0, 1280.0, 1366.0, 1536.0, 1920.0];

    for (final width in desktopWidths) {
      testWidgets('Admin Workspace renders without overflow at ${width.toInt()}dp',
          (tester) async {
        addTearDown(await installFypOfflineFonts());
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: GroupClassesAdminPage(
              call: (action, input) async => {'classes': sampleClasses},
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Group Classes'), findsOneWidget);
        expect(find.text('Create class'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
