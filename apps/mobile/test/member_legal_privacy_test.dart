import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/identity/presentation/member/member_legal_privacy_page.dart';

void main() {
  testWidgets('cold start and resume do not prompt already-consented members',
      (tester) async {
    var overview = Completer<Map<String, dynamic>>();
    var reads = 0;
    final agreed = {
      'documents': [
        {
          'kind': 'privacy',
          'version': 'v1.1',
          'acceptedVersion': 'v1.0',
          'requiresConsent': false,
        }
      ],
    };
    final app = MaterialApp(
      home: MemberComplianceGate(
        call: (action, _) {
          expect(action, 'memberOverview');
          reads++;
          return overview.future;
        },
        child: const Scaffold(body: Text('Member workspace')),
        accountSettings: (_) => const Scaffold(),
        onSignOut: () {},
      ),
    );
    await tester.pumpWidget(app);
    expect(find.bySemanticsLabel('Checking policy status'), findsOneWidget);
    expect(find.text('Review policies'), findsNothing);
    expect(find.text('Member workspace'), findsNothing);
    overview.complete(agreed);
    await tester.pumpAndSettle();
    expect(find.text('Member workspace'), findsOneWidget);

    overview = Completer<Map<String, dynamic>>();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(reads, 2);
    expect(find.text('Member workspace'), findsOneWidget);
    expect(find.text('Review policies'), findsNothing);
    overview.complete(agreed);
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    overview = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(app);
    expect(reads, 3);
    expect(find.text('Review policies'), findsNothing);
    overview.complete(agreed);
    await tester.pumpAndSettle();
    expect(find.text('Member workspace'), findsOneWidget);
  });

  testWidgets('failed first check offers retry without requesting consent',
      (tester) async {
    var reads = 0;
    await tester.pumpWidget(MaterialApp(
      home: MemberComplianceGate(
        call: (action, _) async {
          expect(action, 'memberOverview');
          if (reads++ == 0) throw StateError('Network unavailable');
          return {'documents': []};
        },
        child: const Scaffold(body: Text('Member workspace')),
        accountSettings: (_) => const Scaffold(),
        onSignOut: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Policy check unavailable'), findsOneWidget);
    expect(find.text('Review policies'), findsNothing);
    expect(find.text('Member workspace'), findsNothing);
    expect(find.text('Account settings'), findsOneWidget);
    await tester.tap(find.text('Retry policy check'));
    await tester.pumpAndSettle();
    expect(find.text('Member workspace'), findsOneWidget);
  });

  testWidgets(
      'required update blocks workspace until explicit versioned acceptance',
      (tester) async {
    var accepted = false;
    await tester.pumpWidget(MaterialApp(
      home: MemberComplianceGate(
        call: (action, input) async {
          if (action == 'accept') {
            expect(input, {
              'agreed': true,
              'documents': [
                {'kind': 'privacy', 'revision': 3}
              ],
            });
            accepted = true;
            return {'saved': true};
          }
          return {
            'documents': [
              {
                'kind': 'privacy',
                'version': 'v2.0',
                'revision': 3,
                'text': 'Test policy text.',
                'acceptedVersion': accepted ? 'v2.0' : 'v1.0',
                'requiresConsent': !accepted,
              }
            ],
          };
        },
        child: const Scaffold(body: Text('Member workspace')),
        accountSettings: (_) =>
            Scaffold(appBar: AppBar(), body: const Text('Manage account')),
        onSignOut: () {},
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Member workspace'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    await tester.tap(find.text('Account settings'));
    await tester.pumpAndSettle();
    expect(find.text('Manage account'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Privacy Policy'));
    await tester.pumpAndSettle();
    expect(find.text('Test policy text.'), findsOneWidget);
    final confirm = find.widgetWithText(FilledButton, 'Confirm agreement');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(accepted, true);
    expect(find.text('Member workspace'), findsOneWidget);
  });
}
