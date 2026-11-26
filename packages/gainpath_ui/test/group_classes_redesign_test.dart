import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  final now = DateTime.utc(2026, 11, 28, 2).millisecondsSinceEpoch;

  final sampleClasses = [
    {
      'id': 'class-1',
      'title': 'Morning Vinyasa Flow',
      'category': 'Yoga',
      'difficulty': 'All levels',
      'eligibility': 'All Members',
      'branchId': 'branch-1',
      'branchName': 'Downtown Flagship',
      'venue': 'Studio A',
      'coachId': 'coach-1',
      'instructor': 'Sarah Jenkins',
      'specialty': 'Yoga & Mobility',
      'startAtMillis': now + 18000000, // in 5 hours (>2h cancellation window)
      'endAtMillis': now + 21600000,
      'openAtMillis': now - 86400000,
      'closeAtMillis': now + 1800000,
      'capacity': 15,
      'activeCount': 8,
      'status': 'Open',
      'state': 'Published',
      'description': 'A gentle awakening yoga flow focusing on breath and movement.',
      'cancellationCount': 0,
    },
    {
      'id': 'class-2',
      'title': 'HIIT Blast 45',
      'category': 'HIIT',
      'difficulty': 'Intermediate',
      'eligibility': 'Paid Members',
      'branchId': 'branch-2',
      'branchName': 'Westside Hub',
      'venue': 'HIIT Zone',
      'coachId': 'coach-2',
      'instructor': 'Marcus Vance',
      'specialty': 'Cardio & Conditioning',
      'startAtMillis': now + 86400000, // tomorrow
      'endAtMillis': now + 86400000 + 2700000,
      'openAtMillis': now - 86400000,
      'closeAtMillis': now + 86400000 - 7200000,
      'capacity': 20,
      'activeCount': 20,
      'status': 'Full',
      'state': 'Published',
      'description': 'High intensity interval circuit designed to build power and stamina.',
      'cancellationCount': 2,
    },
    {
      'id': 'class-3',
      'title': 'Power Lifting Basics',
      'category': 'Strength',
      'difficulty': 'Advanced',
      'eligibility': 'Premium Only',
      'branchId': 'branch-1',
      'branchName': 'Downtown Flagship',
      'venue': 'Iron Room',
      'instructor': 'Alex Stone',
      'startAtMillis': now + 172800000, // in 2 days
      'endAtMillis': now + 172800000 + 3600000,
      'openAtMillis': now - 86400000,
      'closeAtMillis': now + 172800000 - 7200000,
      'capacity': 12,
      'activeCount': 4,
      'status': 'Open',
      'state': 'Published',
      'description': 'Master the squat, bench press, and deadlift with safe mechanics.',
      'cancellationCount': 1,
    },
  ];

  group('Member Group Classes Experience', () {
    testWidgets('Explore tab filters by search, category, and branch',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        return {'classes': sampleClasses};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: MemberGroupClassesPage(
            call: mockCall,
            onUpgrade: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // All classes rendered
      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);
      expect(find.text('HIIT Blast 45'), findsOneWidget);
      expect(find.text('Power Lifting Basics'), findsOneWidget);

      // Search filter
      await tester.enterText(find.byType(TextField), 'HIIT');
      await tester.pumpAndSettle();
      expect(find.text('Morning Vinyasa Flow'), findsNothing);
      expect(find.text('HIIT Blast 45'), findsOneWidget);
      expect(find.text('Power Lifting Basics'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);

      // Category filter dropdown
      await tester.tap(find.byKey(const Key('filter_Category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yoga').last);
      await tester.pumpAndSettle();
      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);
      expect(find.text('HIIT Blast 45'), findsNothing);
    });

    testWidgets('My Classes displays registered sessions and handles cancellation',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var isCancelled = false;
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'leave') {
          isCancelled = true;
          return {'saved': true};
        }
        if (action == 'detail') {
          return {
            'item': {
              ...sampleClasses[0],
              'registration': isCancelled ? 'Cancelled' : 'Registered',
              'eligible': true,
            },
            'serverNowMillis': now,
          };
        }
        return {
          'classes': [
            {
              ...sampleClasses[0],
              'registration': isCancelled ? 'Cancelled' : 'Registered',
            },
            {
              ...sampleClasses[1],
              'registration': null,
            },
          ]
        };
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: MemberGroupClassesPage(
            call: mockCall,
            onUpgrade: () {},
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Switch to My Classes tab
      await tester.tap(find.text('My Classes'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);
      expect(find.text('HIIT Blast 45'), findsNothing);

      // Open details and cancel
      await tester.tap(find.text('Morning Vinyasa Flow'));
      await tester.pumpAndSettle();

      expect(find.text('Class details'), findsOneWidget);
      expect(find.text('Cancel registration'), findsOneWidget);

      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Cancel registration?'), findsOneWidget);
      expect(find.text('Keep spot'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Cancel registration'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Registration cancelled'), findsOneWidget);
    });

    testWidgets('Class Details enforces membership tier eligibility',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      var upgraded = false;
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        return {
          'item': {
            ...sampleClasses[2], // Premium Only
            'eligible': false,
            'registration': null,
          },
          'serverNowMillis': now,
        };
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: MemberGroupClassDetails(
            call: mockCall,
            id: 'class-3',
            onUpgrade: () => upgraded = true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Requires Premium Only on the class date.'), findsOneWidget);
      expect(find.text('Upgrade Membership'), findsOneWidget);

      await tester.tap(find.text('Upgrade Membership'));
      await tester.pump();
      expect(upgraded, isTrue);
    });

    testWidgets('Standalone MemberGroupClassesScreen shows AppBar and back navigation',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        return {'classes': sampleClasses};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MemberGroupClassesScreen(
                        call: mockCall,
                        onUpgrade: () {},
                      ),
                    ),
                  );
                },
                child: const Text('Go'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Go'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Group Classes'), findsOneWidget);
      expect(find.text('Explore & book fitness classes'), findsOneWidget);
      expect(find.text('Personal Coaching'), findsNothing);
      expect(find.text('Explore Classes'), findsOneWidget);
      expect(find.text('My Classes'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Go'), findsOneWidget);
    });

    testWidgets('Empty state shows honest message when gym has no upcoming classes',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        return {'classes': <Map<String, dynamic>>[]};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: MemberGroupClassesScreen(
          call: mockCall,
          onUpgrade: () {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No classes available yet'), findsOneWidget);
      expect(
        find.text(
            'New classes will appear here when the gym publishes upcoming sessions.'),
        findsOneWidget,
      );
      expect(find.text('Clear Filters'), findsNothing);
    });

    testWidgets('Filtered empty state shows Clear Filters CTA that restores classes',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);

      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        return {'classes': sampleClasses};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: MemberGroupClassesScreen(
          call: mockCall,
          onUpgrade: () {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonexistentClassXYZ');
      await tester.pumpAndSettle();

      expect(find.text('No matching classes'), findsOneWidget);
      expect(find.text('No classes available yet'), findsNothing);
      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);
      expect(find.text('No matching classes'), findsNothing);
    });
  });

  group('Responsive Viewports & Overflow Resilience', () {
    final mobileWidths = [320.0, 360.0, 393.0, 430.0];

    for (final width in mobileWidths) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            'Member Group Classes standalone renders without overflow at ${width.toInt()}dp scale=${scale.toInt()}x',
            (tester) async {
          tester.view.resetPhysicalSize();
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);

          Future<Map<String, dynamic>> mockCall(
              String action, Map<String, dynamic> input) async {
            return {'classes': sampleClasses};
          }

          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.build(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: MemberGroupClassesScreen(
              call: mockCall,
              onUpgrade: () {},
            ),
          ));
          await tester.pumpAndSettle();

          expect(find.text('Explore Classes'), findsOneWidget);
          expect(find.text('My Classes'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
