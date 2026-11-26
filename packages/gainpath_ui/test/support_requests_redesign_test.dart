import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  final sampleTickets = [
    {
      'id': 'req-101',
      'title': 'Coach missed appointment without notice',
      'status': 'Waiting for member',
      'category': 'Coach Booking',
      'memberName': 'Elena Rostova',
      'updatedAtMillis': 1795500000000,
      'createdAtMillis': 1795490000000,
      'unread': true,
      'reference': {'kind': 'Booking', 'id': 'bk-9901'},
    },
    {
      'id': 'req-102',
      'title': 'Duplicate charge on monthly membership renewal',
      'status': 'Open',
      'category': 'Payment & Refund',
      'memberName': 'Marcus Vance',
      'updatedAtMillis': 1795495000000,
      'createdAtMillis': 1795492000000,
      'unread': false,
      'reference': {'kind': 'Payment', 'id': 'pay-5544'},
    },
    {
      'id': 'req-103',
      'title': 'Locker access barcode not scanning at Downtown gym',
      'status': 'Resolved',
      'category': 'App Issue',
      'memberName': 'Sophia Chen',
      'updatedAtMillis': 1795480000000,
      'createdAtMillis': 1795470000000,
      'unread': false,
    },
  ];

  final sampleMessages = [
    {
      'role': 'Member',
      'body':
          'Hi, my coach did not show up for our scheduled 10:00 AM session today.',
      'createdAtMillis': 1795490000000,
    },
    {
      'role': 'Admin',
      'body':
          'We apologize for the inconvenience. We have contacted the coach and can offer a full credit or reschedule. Which do you prefer?',
      'createdAtMillis': 1795495000000,
    },
  ];

  group('Member Help & Support Experience', () {
    testWidgets('Renders clean support home with actual counts and member-friendly statuses',
        (tester) async {
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'list') {
          return {'tickets': sampleTickets, 'nextId': null};
        }
        return {};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall),
      ));
      await tester.pumpAndSettle();

      // Header Banner and CTA
      expect(find.text('Help & Support'), findsOneWidget);
      expect(find.text('Need Help?'), findsOneWidget);
      expect(find.text('Submit a request'), findsOneWidget);

      // Section title with record count
      expect(find.text('My requests'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Member-friendly status
      expect(find.text('Your reply needed'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      expect(find.text('Resolved'), findsOneWidget);

      // New reply pill for unread update
      expect(find.text('New reply'), findsOneWidget);

      // Categories
      expect(find.text('Coach Booking'), findsOneWidget);
      expect(find.text('Payment & Refund'), findsOneWidget);
      expect(find.text('App Issue'), findsOneWidget);
    });

    testWidgets('Empty state renders helpful guidance when no requests exist',
        (tester) async {
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'list') {
          return {'tickets': [], 'nextId': null};
        }
        return {};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No support requests yet'), findsOneWidget);
      expect(
          find.text(
              'Any questions or issues you submit will appear here with full ticket history.'),
          findsOneWidget);
    });

    testWidgets('New Support Request form validates inputs and enforces limits',
        (tester) async {
      final actions = <String>[];
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        actions.add(action);
        if (action == 'list') return {'tickets': [], 'nextId': null};
        if (action == 'references') {
          return {
            'references': [
              {'kind': 'Booking', 'id': 'bk-01', 'label': 'Personal Training with Elena'}
            ]
          };
        }
        if (action == 'create') {
          expect(input['title'], 'Need to reschedule session');
          expect(input['body'], 'Please move my session to tomorrow.');
          expect(input['category'], 'Coach Booking');
          return {'id': 'new-req-1'};
        }
        if (action == 'detail') {
          return {
            'ticket': {
              'id': 'new-req-1',
              'title': 'Need to reschedule session',
              'status': 'Open',
              'category': 'Coach Booking',
              'memberName': 'Elena',
              'updatedAtMillis': 1795500000000,
            },
            'messages': [
              {
                'role': 'Member',
                'body': 'Please move my session to tomorrow.',
                'createdAtMillis': 1795500000000,
              }
            ],
          };
        }
        return {};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall),
      ));
      await tester.pumpAndSettle();

      // Open full screen new request form
      await tester.tap(find.text('Submit a request'));
      await tester.pumpAndSettle();

      expect(find.text('New support request'), findsOneWidget);
      expect(find.text('How can we help?'), findsOneWidget);
      expect(find.text('CATEGORY'), findsOneWidget);
      expect(find.text('SUBJECT'), findsOneWidget);
      expect(find.text('DESCRIPTION'), findsOneWidget);

      // Attempt submit without filling fields -> triggers validation
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();
      expect(find.text('This field is required.'), findsNWidgets(2));

      // Fill in category
      await tester.tap(find.text('Other'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coach Booking').last);
      await tester.pumpAndSettle();

      // Fill in subject & description
      await tester.enterText(
          find.byType(TextFormField).at(0), 'Need to reschedule session');
      await tester.enterText(find.byType(TextFormField).at(1),
          'Please move my session to tomorrow.');
      await tester.pump();

      // Submit valid form
      await tester.tap(find.text('Submit'));
      await tester.pumpAndSettle();

      expect(actions, contains('create'));
      expect(find.text('Please move my session to tomorrow.'), findsOneWidget);
    });
  });

  group('Admin Support Requests Experience', () {
    testWidgets('Admin queue provides status filters, client-side search, and loaded counts',
        (tester) async {
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'list') {
          return {'tickets': sampleTickets, 'nextId': null};
        }
        return {};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall, admin: true),
      ));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('Support Requests'), findsOneWidget);
      expect(find.text('Showing 3 of 3 requests'), findsOneWidget);

      // Filter chips with live counts
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Waiting for member'), findsNWidgets(2)); // Chip and row status
      expect(find.text('Open'), findsNWidgets(2)); // Chip and row status
      expect(find.text('Resolved'), findsNWidgets(2)); // Chip and row status

      // Test Search filtering
      final searchFinder = find.byType(TextField);
      expect(searchFinder, findsOneWidget);

      await tester.enterText(searchFinder, 'Locker');
      await tester.pumpAndSettle();

      expect(find.text('Showing 1 of 3 requests'), findsOneWidget);
      expect(find.text('Locker access barcode not scanning at Downtown gym'),
          findsOneWidget);
      expect(find.text('Coach missed appointment without notice'), findsNothing);

      // Clear search
      await tester.enterText(searchFinder, '');
      await tester.pumpAndSettle();
      expect(find.text('Showing 3 of 3 requests'), findsOneWidget);

      // Filter by status chip: Resolved
      await tester.tap(find.text('Resolved').first);
      await tester.pumpAndSettle();
      expect(find.text('Showing 1 of 3 requests'), findsOneWidget);
      expect(find.text('Locker access barcode not scanning at Downtown gym'),
          findsOneWidget);
    });

    testWidgets('Admin conversation workspace displays 2-column layout on desktop',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      var currentStatus = 'Open';
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'list') return {'tickets': sampleTickets};
        if (action == 'detail') {
          return {
            'ticket': {
              'id': 'req-101',
              'title': 'Coach missed appointment without notice',
              'status': currentStatus,
              'category': 'Coach Booking',
              'memberName': 'Elena Rostova',
              'updatedAtMillis': 1795500000000,
              'createdAtMillis': 1795490000000,
              'reference': {'kind': 'Booking', 'id': 'bk-9901'},
            },
            'messages': sampleMessages,
          };
        }
        if (action == 'reply') {
          currentStatus =
              input['waitForMember'] == true ? 'Waiting for member' : 'Open';
          return {'id': 'req-101'};
        }
        if (action == 'resolve') {
          currentStatus = 'Resolved';
          return {'id': 'req-101'};
        }
        return {'id': 'req-101'};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall, admin: true),
      ));
      await tester.pumpAndSettle();

      // Open ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      // Breadcrumb bar & Header card
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Support Requests'), findsOneWidget);
      expect(find.text('Coach missed appointment without notice'), findsNWidgets(2));
      expect(find.text('Coach Booking · Open'), findsOneWidget);

      // Timeline messages
      expect(
          find.text(
              'Hi, my coach did not show up for our scheduled 10:00 AM session today.'),
          findsOneWidget);
      expect(
          find.text(
              'We apologize for the inconvenience. We have contacted the coach and can offer a full credit or reschedule. Which do you prefer?'),
          findsOneWidget);

      // Information Sidebar
      expect(find.text('Request Information'), findsOneWidget);
      expect(find.text('Administrative Actions'), findsOneWidget);
      expect(find.text('Technical Details'), findsOneWidget);

      // Composer controls
      expect(find.text('Reply to Member'), findsOneWidget);
      expect(find.text('Waiting for member response'), findsOneWidget);
      expect(find.text('Send reply'), findsOneWidget);

      // Administrative resolve action
      expect(find.text('Mark as resolved'), findsOneWidget);
      await tester.tap(find.text('Mark as resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Reopen request'), findsOneWidget);
      expect(find.text('Send reply'), findsNothing);

      // Navigate back to queue via breadcrumb
      await tester.tap(find.text('Support Requests'));
      await tester.pumpAndSettle();
      expect(find.text('Review, triage, and reply to member support inquiries.'),
          findsOneWidget);
    });

    testWidgets('Draft confirmation prevents accidental loss of unsent reply',
        (tester) async {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(() => tester.view.resetPhysicalSize());

      var resolved = false;
      Future<Map<String, dynamic>> mockCall(
          String action, Map<String, dynamic> input) async {
        if (action == 'list') return {'tickets': sampleTickets};
        if (action == 'detail') {
          return {
            'ticket': {
              'id': 'req-101',
              'title': 'Coach missed appointment without notice',
              'status': resolved ? 'Resolved' : 'Open',
              'category': 'Coach Booking',
              'memberName': 'Elena Rostova',
              'updatedAtMillis': 1795500000000,
            },
            'messages': [],
          };
        }
        if (action == 'resolve') {
          resolved = true;
          return {'id': 'req-101'};
        }
        return {'id': 'req-101'};
      }

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: SupportRequestsPage(call: mockCall, admin: true),
      ));
      await tester.pumpAndSettle();

      // Open ticket
      await tester.tap(find.text('Coach missed appointment without notice'));
      await tester.pumpAndSettle();

      // Type an unsent draft in reply field
      await tester.enterText(
          find.byType(TextField), 'Drafting a reply that should not be discarded');
      await tester.pump();

      // Tap Mark as resolved -> Dialog appears!
      await tester.tap(find.text('Mark as resolved'));
      await tester.pumpAndSettle();

      expect(find.text('Discard unsent draft?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Resolve anyway'), findsOneWidget);

      // Cancel resolution
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(resolved, false);
      expect(find.text('Drafting a reply that should not be discarded'),
          findsOneWidget);

      // Confirm resolution
      await tester.tap(find.text('Mark as resolved'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve anyway'));
      await tester.pumpAndSettle();

      expect(resolved, true);
    });
  });

  group('Responsive Viewports & Overflow Resilience', () {
    final mobileWidths = [320.0, 360.0, 393.0, 430.0];
    for (final width in mobileWidths) {
      testWidgets('Member Help & Support renders without overflow at ${width.toInt()}dp',
          (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());

        Future<Map<String, dynamic>> mockCall(
            String action, Map<String, dynamic> input) async {
          if (action == 'list') return {'tickets': sampleTickets};
          return {};
        }

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(),
          home: SupportRequestsPage(call: mockCall),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Help & Support'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    final desktopWidths = [1024.0, 1280.0, 1366.0, 1536.0];
    for (final width in desktopWidths) {
      testWidgets('Admin Workspace renders without overflow at ${width.toInt()}px',
          (tester) async {
        tester.view.resetPhysicalSize();
        tester.view.physicalSize = Size(width, 850);
        tester.view.devicePixelRatio = 1;
        addTearDown(() => tester.view.resetPhysicalSize());

        Future<Map<String, dynamic>> mockCall(
            String action, Map<String, dynamic> input) async {
          if (action == 'list') return {'tickets': sampleTickets};
          if (action == 'detail') {
            return {
              'ticket': sampleTickets[0],
              'messages': sampleMessages,
            };
          }
          return {};
        }

        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(),
          home: SupportRequestsPage(call: mockCall, admin: true),
        ));
        await tester.pumpAndSettle();

        // Open ticket
        await tester.tap(find.text('Coach missed appointment without notice'));
        await tester.pumpAndSettle();

        expect(find.text('Coach missed appointment without notice'),
            findsNWidgets(2));
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Support Requests'), findsOneWidget);
        expect(find.text('Request Information'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
