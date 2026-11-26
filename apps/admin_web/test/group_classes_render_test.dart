import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/group_classes/group_classes_admin.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets('Render and capture screenshot artifacts for Group Classes Complete UI/UX Redesign',
      (tester) async {
    final resetFonts = await installFypOfflineFonts();
    addTearDown(resetFonts);

    final buildDir = Directory('../../build/group-classes-redesign')
      ..createSync(recursive: true);
    final brainDir = Directory(
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314')
      ..createSync(recursive: true);

    Future<void> capture(GlobalKey key, String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        await File('${buildDir.path}/$name').writeAsBytes(bytes);
        await File('${brainDir.path}/$name').writeAsBytes(bytes);
        image.dispose();
      });
    }

    final start = DateTime.utc(2026, 11, 28, 2).millisecondsSinceEpoch;

    final sampleClasses = [
      <String, dynamic>{
        'id': 'class-strength-lab',
        'title': 'Strength Lab & Powerlifting',
        'description':
            'Master the squat, bench press, and deadlift with certified coaches. Ideal for developing fundamental compound strength and form precision.',
        'category': 'Strength',
        'branchId': 'branch-downtown',
        'branchName': 'Downtown Flagship',
        'coachId': 'coach-alicia',
        'instructor': 'Alicia Tan',
        'specialty': 'Strength & Conditioning',
        'venue': 'Studio A',
        'startAtMillis': start + 86400000, // Tomorrow 10:00 AM MYT
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
        'id': 'class-sunset-yoga',
        'title': 'Sunset Vinyasa Flow & Sound Bath',
        'description':
            'Dynamic evening sequence synchronizing breath with energetic flow, concluding with a 15-minute Tibetan singing bowl meditation.',
        'category': 'Yoga',
        'branchId': 'branch-westside',
        'branchName': 'Westside Hub',
        'coachId': 'coach-marcus',
        'instructor': 'Marcus Lim',
        'specialty': 'Mobility & Flexibility',
        'venue': 'Zen Studio',
        'startAtMillis': start + 172800000, // in 2 days
        'endAtMillis': start + 172800000 + 4500000,
        'activeCount': 16,
        'capacity': 16,
        'status': 'Full',
        'state': 'Published',
        'difficulty': 'Intermediate',
        'eligibility': 'Paid Members',
        'cancellationCount': 0,
      },
      <String, dynamic>{
        'id': 'class-hiit-burn',
        'title': 'HIIT Metabolic Inferno',
        'description':
            'High-octane interval conditioning circuit designed to maximize cardiovascular capacity and athletic endurance.',
        'category': 'Cardio',
        'branchId': 'branch-downtown',
        'branchName': 'Downtown Flagship',
        'venue': 'HIIT Arena',
        'instructor': 'Guest Instructor John',
        'startAtMillis': start - 86400000, // Yesterday
        'endAtMillis': start - 86400000 + 2700000,
        'activeCount': 18,
        'capacity': 20,
        'status': 'Completed',
        'state': 'Published',
        'difficulty': 'Advanced',
        'eligibility': 'Premium Only',
        'cancellationCount': 2,
        'attendedCount': 16,
        'absentCount': 2,
      },
      <String, dynamic>{
        'id': 'class-pilates-draft',
        'title': 'Reformer Core Foundations',
        'description':
            'Precision core alignment, pelvic stability, and spine articulation using classical reformer techniques.',
        'category': 'Pilates',
        'branchId': 'branch-downtown',
        'branchName': 'Downtown Flagship',
        'venue': 'Reformer Studio',
        'coachId': 'coach-alicia',
        'instructor': 'Alicia Tan',
        'startAtMillis': start + 259200000,
        'endAtMillis': start + 259200000 + 3600000,
        'activeCount': 0,
        'capacity': 10,
        'status': 'Draft',
        'state': 'Draft',
        'difficulty': 'All levels',
        'eligibility': 'Premium Only',
        'cancellationCount': 0,
      },
    ];

    Future<Map<String, dynamic>> mockAdminCall(
        String action, Map<String, dynamic> input) async {
      if (action == 'options') {
        return {
          'branches': [
            {'id': 'branch-downtown', 'name': 'Downtown Flagship'},
            {'id': 'branch-westside', 'name': 'Westside Hub'},
          ],
          'coaches': [
            {'id': 'coach-alicia', 'name': 'Alicia Tan'},
            {'id': 'coach-marcus', 'name': 'Marcus Lim'},
          ],
        };
      }
      if (action == 'detail') {
        return {
          'item': sampleClasses[2], // Completed HIIT class
          'participants': [
            {
              'name': 'Alicia Wong',
              'memberId': 'mem-1',
              'status': 'Registered',
              'attended': true,
              'joinedAtMillis': start - 172800000,
            },
            {
              'name': 'Elena Rostova',
              'memberId': 'mem-2',
              'status': 'Registered',
              'attended': true,
              'joinedAtMillis': start - 150000000,
            },
            {
              'name': 'David Miller',
              'memberId': 'mem-3',
              'status': 'Registered',
              'attended': false,
              'joinedAtMillis': start - 120000000,
            },
          ],
        };
      }
      return {'classes': sampleClasses};
    }

    // 1. Admin Group Classes Workspace (1280 x 850)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: GroupClassesAdminPage(call: mockAdminCall),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'admin_group_classes_workspace_1280.png');
    }

    // 2. Admin Group Classes Empty State (1280 x 850)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: GroupClassesAdminPage(
              call: (action, input) async => {'classes': []},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'admin_group_classes_empty_state_1280.png');
    }

    // 3. Admin Class Builder - Step 1: Details & Media (1280 x 850)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(1280, 850);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: GroupClassesAdminPage(call: mockAdminCall),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create class').first);
      await tester.pumpAndSettle();

      await tester.enterText(
          find.byType(TextFormField).first, 'Barbell Hypertrophy & Technique');
      await tester.enterText(find.byType(TextFormField).last,
          'Progressive overload focused hypertrophy class targeting posterior chain mechanics and barbell efficiency.');
      await tester.pumpAndSettle();

      await capture(key, 'admin_class_builder_step1_1280.png');

      // 4. Admin Class Builder - Step 2: Schedule & Instructor (1280 x 850)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      await capture(key, 'admin_class_builder_step2_1280.png');

      // 5. Admin Class Builder - Step 3: Capacity & Publish (1280 x 850)
      await tester.tap(find.text('Next Step'));
      await tester.pumpAndSettle();
      await capture(key, 'admin_class_builder_step3_1280.png');

      // Dismiss dialog
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
    }

    // 6. Admin Class Details Workspace - Overview (1280 x 950)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(1280, 950);
      tester.view.devicePixelRatio = 1;

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: GroupClassesAdminPage(call: mockAdminCall),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open completed class details
      await tester.tap(find.text('HIIT Metabolic Inferno'));
      await tester.pumpAndSettle();

      // Switch to Overview tab
      await tester.tap(find.widgetWithText(InkWell, 'Overview'));
      await tester.pumpAndSettle();
      await capture(key, 'admin_class_details_overview_1280.png');

      // 7. Admin Class Details Workspace - Attendance (1280 x 950)
      await tester.tap(find.widgetWithText(InkWell, 'Attendance'));
      await tester.pumpAndSettle();
      await capture(key, 'admin_class_details_attendance_1280.png');
    }

    // 8. Member Group Classes - Explore (Mobile 393 x 852)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      Future<Map<String, dynamic>> mockMemberCall(
          String action, Map<String, dynamic> input) async {
        return {'classes': sampleClasses};
      }

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Group Classes'),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              elevation: 0,
            ),
            body: MemberGroupClassesPage(
              call: mockMemberCall,
              onUpgrade: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'member_group_classes_explore_393.png');
    }

    // 9. Member Group Classes - My Classes (Mobile 393 x 852)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      Future<Map<String, dynamic>> mockMemberCall(
          String action, Map<String, dynamic> input) async {
        return {
          'classes': [
            {
              ...sampleClasses[0],
              'registration': 'Registered',
            },
            {
              ...sampleClasses[2],
              'registration': 'Registered',
            },
          ]
        };
      }

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            appBar: AppBar(
              title: const Text('Group Classes'),
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.ink,
              elevation: 0,
            ),
            body: MemberGroupClassesPage(
              call: mockMemberCall,
              onUpgrade: () {},
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();
      await capture(key, 'member_group_classes_my_classes_393.png');
    }

    // 10. Member Group Class Details - Persistent Booking Bar (Mobile 393 x 852)
    {
      final key = GlobalKey();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;

      Future<Map<String, dynamic>> mockDetailCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'detail') {
          return {
            'item': {
              ...sampleClasses[0],
              'eligible': true,
              'registration': null,
            },
            'serverNowMillis': start,
          };
        }
        return {'classes': sampleClasses};
      }

      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: MemberGroupClassDetails(
            call: mockDetailCall,
            id: 'class-strength-lab',
            onUpgrade: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capture(key, 'member_group_class_details_393.png');
    }
  });
}
