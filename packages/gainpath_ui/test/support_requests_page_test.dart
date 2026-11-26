import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  testWidgets('member submits a request and can read the thread',
      (tester) async {
    final actions = <String>[];
    Future<Map<String, dynamic>> call(
        String action, Map<String, dynamic> input) async {
      actions.add(action);
      switch (action) {
        case 'list':
          return {'tickets': [], 'nextId': null};
        case 'references':
          return {'references': []};
        case 'create':
          expect(input['title'], 'Booking issue');
          expect(input['body'], 'Please check my appointment.');
          expect(input['requestId'], isNotEmpty);
          return {'id': 'request-1'};
        case 'detail':
          expect(input['ticketId'], 'request-1');
          return {
            'ticket': _ticket,
            'messages': [
              {
                'role': 'Member',
                'body': 'Please check my appointment.',
                'createdAtMillis': 1795500000000
              },
            ],
          };
        default:
          throw StateError(action);
      }
    }

    await tester.pumpWidget(MaterialApp(home: SupportRequestsPage(call: call)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Submit a request'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Booking issue');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'Please check my appointment.');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Please check my appointment.'), findsOneWidget);
    expect(actions, ['list', 'references', 'create', 'detail']);
  });

  testWidgets('admin replies, resolves and reopens a request', (tester) async {
    var status = 'Open';
    final actions = <String>[];
    Future<Map<String, dynamic>> call(
        String action, Map<String, dynamic> input) async {
      if (action == 'list') {
        return {
          'tickets': [_ticket]
        };
      }
      if (action == 'detail') {
        return {
          'ticket': {..._ticket, 'status': status},
          'messages': []
        };
      }
      actions.add(action);
      expect(input['ticketId'], 'request-1');
      if (action == 'reply') {
        expect(input['body'], 'We are checking your appointment.');
        expect(input['waitForMember'], true);
        status = 'Waiting for member';
      }
      if (action == 'resolve') status = 'Resolved';
      if (action == 'reopen') status = 'Open';
      return {'id': 'request-1'};
    }

    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SupportRequestsPage(call: call, admin: true))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Booking issue'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextField), 'We are checking your appointment.');
    await tester.pump();
    await tester.ensureVisible(find.text('Send reply'));
    await tester.tap(find.text('Send reply'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Booking · Waiting for member'), findsOneWidget);
    await tester.ensureVisible(find.text('Mark as resolved'));
    await tester.tap(find.text('Mark as resolved'));
    await tester.pumpAndSettle();
    expect(find.text('Send reply'), findsNothing);
    await tester.ensureVisible(find.text('Reopen request'));
    await tester.tap(find.text('Reopen request'));
    await tester.pumpAndSettle();
    expect(find.text('Coach Booking · Open'), findsOneWidget);
    expect(actions, ['reply', 'resolve', 'reopen']);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Booking issue'), findsOneWidget);
    expect(find.text('Support request'), findsNothing);
  });
}

const _ticket = {
  'id': 'request-1',
  'title': 'Booking issue',
  'status': 'Open',
  'category': 'Coach Booking',
  'memberName': 'Member',
  'updatedAtMillis': 1795500000000,
};
