import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:latlong2/latlong.dart';

Finder _field(String name) => find.widgetWithText(TextFormField, name);

Future<void> _openEditor(WidgetTester tester, BranchRequest request,
    {String action = 'Add Branch',
    Size viewport = const Size(1280, 960),
    TextScaler textScale = TextScaler.noScaling}) async {
  tester.view.physicalSize = viewport;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScale),
      child: child!,
    ),
    home: BranchDirectoryPage(
      admin: true,
      openDirections: (_) async => true,
      request: request,
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('adding a branch uses a full-page editor and guards dirty fields',
      (tester) async {
    await _openEditor(tester, (_) async => {'records': []});

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Back to branches'), findsOneWidget);
    await tester.enterText(_field('Branch name'), 'Fixture Gym');
    await tester.tap(find.text('Back to branches'));
    await tester.pumpAndSettle();

    expect(find.text('Discard branch changes?'), findsOneWidget);
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(find.text('Branch Management'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplicate ID leaves the editor open with entered branch data',
      (tester) async {
    final saves = <Map<String, Object?>>[];
    await _openEditor(tester, (input) async {
      if (input['action'] == 'save') {
        saves.add(input);
        throw const BranchSaveException(code: 'already-exists');
      }
      return {'records': []};
    });

    await tester.enterText(_field('Branch ID'), 'north');
    await tester.enterText(_field('Branch name'), 'North Gym');
    await tester.tap(find.text('Save Branch'));
    await tester.pumpAndSettle();

    expect(saves.single['branchId'], 'north');
    expect(saves.single['create'], isTrue);
    expect(saves.single['branch'], containsPair('status', 'active'));
    expect(find.text('This branch ID already exists.'), findsWidgets);
    expect(find.text('North Gym'), findsOneWidget);
  });

  testWidgets('canceling map selection preserves manually entered coordinates',
      (tester) async {
    await _openEditor(tester, (_) async => {'records': []});
    await tester.ensureVisible(_field('Latitude'));
    await tester.enterText(_field('Latitude'), '3.125');
    await tester.enterText(_field('Longitude'), '101.75');

    final pick = find.text('Pick Location on Map');
    await tester.ensureVisible(pick);
    await tester.tap(pick);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    final confirm = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm Location'),
    );
    expect(confirm.onPressed, isNotNull);

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    map.options.onTap!(const TapPosition(Offset.zero, Offset.zero),
        const LatLng(4.25, 102.75));
    await tester.pump();
    expect(find.textContaining('Latitude 4.250000'), findsOneWidget);

    final cancel = find.text('Cancel location selection');
    await tester.ensureVisible(cancel);
    await tester.pumpAndSettle();
    await tester.tap(cancel);
    await tester.pumpAndSettle();

    expect(find.text('Confirm Location'), findsNothing);
    expect(find.text('3.125'), findsOneWidget);
    expect(find.text('101.75'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renaming preserves the branch ID and persisted schedule',
      (tester) async {
    const originalHours = [
      {'open': '21:00', 'close': '06:00'},
      {'allDay': true},
      {'closed': true},
      {'closed': true},
      {'closed': true},
      {'closed': true},
      {'closed': true},
    ];
    final saves = <Map<String, Object?>>[];
    final saveResponse = Completer<Map<String, dynamic>>();
    await _openEditor(
      tester,
      (input) async => switch (input['action']) {
        'save' => () {
            saves.add(input);
            return saveResponse.future;
          }(),
        'branchStats' => {
            'coaches': 0,
            'equipment': 0,
            'bookings': 0,
            'visits': 0
          },
        _ => {
            'records': [
              {
                'branchId': 'stable-north',
                'displayName': 'Original Gym',
                'address': '123 Fixture Street',
                'status': 'inactive',
                'facilities': ['Rack', 'Studio'],
                'openingHours': originalHours,
                'timeZone': 'Asia/Kuala_Lumpur',
              }
            ],
          },
      },
      action: 'Manage Branch',
    );
    await tester.tap(find.text('Edit Branch'));
    await tester.pumpAndSettle();
    final lockedId = find.descendant(
        of: _field('Branch ID'), matching: find.byType(TextField));
    expect(tester.widget<TextField>(lockedId).readOnly, isTrue);
    expect(find.text('21:00'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);

    await tester.enterText(_field('Branch name'), 'Renamed Gym');
    await tester.tap(find.text('Save Changes'));
    await tester.pump();
    expect(saves.single['branchId'], 'stable-north');
    expect(saves.single['create'], isFalse);
    final branch = saves.single['branch'] as Map;
    expect(branch, containsPair('displayName', 'Renamed Gym'));
    expect(branch, containsPair('address', '123 Fixture Street'));
    expect(branch, containsPair('status', 'inactive'));
    expect(branch, containsPair('openingHours', originalHours));
    expect(branch, containsPair('facilities', ['Rack', 'Studio']));
    expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Saving…'),
            )
            .onPressed,
        isNull);

    saveResponse.complete(<String, dynamic>{});
    await tester.pumpAndSettle();
    expect(saves, hasLength(1));
    expect(find.text('Save Changes'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editor stacks at a narrow viewport with large text',
      (tester) async {
    await _openEditor(
      tester,
      (_) async => {'records': []},
      viewport: const Size(390, 780),
      textScale: const TextScaler.linear(1.6),
    );

    expect(find.text('Save Branch').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('Map location'));
    await tester.pumpAndSettle();
    expect(find.text('Map location').hitTestable(), findsOneWidget);
    expect(find.text('Save Branch').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
