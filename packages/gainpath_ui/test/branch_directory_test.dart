import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  testWidgets('Admin branch detail passes the actual branch ID to drill-downs',
      (tester) async {
    final routes = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: BranchDirectoryPage(
        admin: true,
        openDirections: (_) async => true,
        onOpenCoaches: (branchId) => routes.add('coaches/$branchId'),
        onOpenReports: (branchId) => routes.add('reports/$branchId'),
        request: (input) async => input['action'] == 'list'
            ? {'records': [{'branchId': 'north', 'displayName': 'North Gym'}]}
            : {'coaches': 1, 'equipment': 0, 'bookings': 0, 'visits': 0},
      ),
    ));
    await tester.pumpAndSettle();
    for (final label in ['Coaches', 'Reports']) {
      await tester.tap(find.text('North Gym'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(routes, ['coaches/north', 'reports/north']);
  });

  testWidgets('a selected cover previews before upload finishes',
      (tester) async {
    final upload = Completer<Map<String, dynamic>>();
    await tester.pumpWidget(MaterialApp(
      home: BranchDirectoryPage(
        admin: true,
        openDirections: (_) async => true,
        pickCover: () async =>
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a2ioAAAAASUVORK5CYII=',
        request: (input) async => input['action'] == 'uploadBranchCover'
            ? upload.future
            : {'records': []},
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add branch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload cover'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) =>
        widget is Image && widget.image is MemoryImage), findsOneWidget);
    expect(tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save branch')).onPressed, isNull);
    upload.completeError(StateError('fixture upload rejected'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cover upload failed').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Discard selected cover'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('branch save errors stay visible beside the save button',
      (tester) async {
    var saves = 0;
    await tester.pumpWidget(MaterialApp(
      home: BranchDirectoryPage(
        admin: true,
        openDirections: (_) async => true,
        request: (input) async {
          if (input['action'] == 'save') {
            saves++;
            if (saves == 1) throw StateError('fixture rejection');
          }
          return {'records': []};
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add branch'));
    await tester.pumpAndSettle();
    final editorList =
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(ListView));
    await tester.drag(editorList, const Offset(0, -2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save branch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a branch ID').hitTestable(), findsOneWidget);
    expect(saves, 0);
    await tester.drag(editorList, const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Branch ID'), 'north');
    await tester.enterText(find.widgetWithText(TextFormField, 'Branch name'), 'North Gym');
    await tester.tap(find.text('Save branch'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Branch could not be saved').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Save branch'));
    await tester.pumpAndSettle();
    expect(saves, 2);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Branch added.'), findsOneWidget);
  });

  testWidgets('Admin can display the branch visit QR', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BranchDirectoryPage(
      admin: true,
      openDirections: (_) async => true,
      request: (input) async => switch (input['action']) {
        'list' => {
            'records': [
              {'branchId': 'main', 'displayName': 'Main gym'}
            ]
          },
        'branchVisits' => {'records': []},
        'issueVisitCode' => {
            'qr': 'fixture-token',
            'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 300000
          },
        _ => <String, dynamic>{},
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Main gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym visits'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate QR'));
    await tester.pumpAndSettle();
    expect(find.text('Gym check-in QR'), findsOneWidget);
    await tester.tap(find.text('Fullscreen'));
    await tester.pumpAndSettle();
    expect(find.text('Exit fullscreen'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'nearby sorts branches without sending location to the repository',
      (tester) async {
    final calls = <Map<String, Object?>>[];
    await tester.pumpWidget(MaterialApp(
        home: BranchDirectoryPage(
      request: (input) async {
        calls.add(input);
        return {
          'records': [
            {'branchId': 'missing', 'displayName': 'Missing coordinates'},
            {
              'branchId': 'far',
              'displayName': 'Far gym',
              'latitude': 5,
              'longitude': 102
            },
            {
              'branchId': 'near',
              'displayName': 'Near gym',
              'latitude': 3.14,
              'longitude': 101.68
            },
          ]
        };
      },
      locate: () async => (latitude: 3.14, longitude: 101.68),
      openDirections: (_) async => true,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.text('Near gym')).dy,
        lessThan(tester.getTopLeft(find.text('Far gym')).dy));
    expect(find.text('0.0 km away'), findsOneWidget);
    expect(calls, [
      {'action': 'list'}
    ]);
  });

  testWidgets('location denial preserves the branch and address directions',
      (tester) async {
    Uri? opened;
    await tester.pumpWidget(MaterialApp(
        home: BranchDirectoryPage(
      request: (_) async => {
        'records': [
          {
            'branchId': 'old',
            'displayName': 'Old gym',
            'address': '12 Main Road'
          },
        ]
      },
      locate: () async => throw StateError('Location access is off.'),
      openDirections: (uri) async {
        opened = uri;
        return true;
      },
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use my location'));
    await tester.pumpAndSettle();
    expect(find.text('Location access is off.'), findsOneWidget);
    await tester.tap(find.text('Old gym'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get directions'));
    await tester.pumpAndSettle();
    expect(opened?.queryParameters['destination'], '12 Main Road');
    expect(opened?.queryParameters.containsKey('origin'), isFalse);
  });
}
