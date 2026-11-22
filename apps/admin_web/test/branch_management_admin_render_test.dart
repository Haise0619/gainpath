import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// The runtime tile provider is already brought in by gainpath_ui.
// ignore: depend_on_referenced_packages
import 'package:flutter_map/flutter_map.dart'
    show BuiltInMapCachingProvider, FlutterMap;
import 'package:gainpath_admin_web/app/di/admin_presentation_dependencies.dart';
import 'package:gainpath_admin_web/app/di/app_repositories.dart';
import 'package:gainpath_admin_web/app/routing/admin_console_navigation.dart';
import 'package:gainpath_admin_web/app/shells/admin_shell.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'support/branch_offline_fonts_stub.dart'
    if (dart.library.io) '../../../test_support/fyp_render_support.dart';
import 'support/empty_coach_directory.dart';

const _session = AuthSession(
  userId: 'branch-render-admin',
  organizationId: 'branch-render-org',
  branchIds: ['central'],
  displayName: 'Fixture Admin',
  email: 'branch-admin@example.test',
  role: AppRole.admin,
);

const _hours = [
  {'open': '06:00', 'close': '22:00'},
  {'open': '06:00', 'close': '22:00'},
  {'open': '20:00', 'close': '02:00'},
  {'open': '06:00', 'close': '22:00'},
  {'allDay': true},
  {'allDay': true},
  {'closed': true},
];

class _BranchesFixture {
  final calls = <Map<String, Object?>>[];
  final rows = <Map<String, Object?>>[
    {
      'branchId': 'central',
      'displayName': 'Central Training Centre',
      'description': 'Strength and group training near the city centre.',
      'address': '18 Jalan Sentral, Kuala Lumpur',
      'city': 'Kuala Lumpur',
      'state': 'Kuala Lumpur',
      'postalCode': '50470',
      'country': 'Malaysia',
      'latitude': 3.13,
      'longitude': 101.69,
      'status': 'active',
      'timeZone': 'Asia/Kuala_Lumpur',
      'openingHours': _hours,
      'facilities': ['Free weights', 'Group studios', 'Changing rooms'],
    },
    {
      'branchId': 'north',
      'displayName': 'North Park Gym',
      'address': '71 Jalan Taman, Petaling Jaya',
      'status': 'active',
      'facilities': ['Cardio equipment', 'Free weights'],
    },
    {
      'branchId': 'east',
      'displayName': 'East Studio',
      'address':
          '220 Jalan Timur, Taman Bukit Indah, Ampang, Selangor, Malaysia',
      'latitude': 3.151,
      'longitude': 101.757,
      'status': 'inactive',
    },
  ];

  Future<Map<String, dynamic>> request(Map<String, Object?> input) async {
    calls.add(Map.of(input));
    final id = input['branchId'];
    switch (input['action']) {
      case 'list':
        return {
          'records': rows,
          'homeBranchId': 'central',
          'selectedBranchId': 'north',
        };
      case 'branchStats':
        return {'coaches': 4, 'equipment': 16, 'bookings': 8, 'visits': 24};
      case 'inventory':
        return {
          'records': [
            {
              'name': 'Fixture rower',
              'quantity': 2,
              'maintenance': 1,
              'usable': 1
            },
          ],
        };
      case 'branchVisits':
        return {'records': []};
      case 'issueVisitCode':
        return {
          'qr': 'fixture-only-visit-code',
          'expiresAtMillis': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
        };
      case 'save':
        final index = rows.indexWhere((row) => row['branchId'] == id);
        if (input['create'] == true && index >= 0) {
          throw StateError('This branch ID already exists.');
        }
        final branch = <String, Object?>{
          if (index >= 0) ...rows[index],
          ...(input['branch'] as Map<String, Object?>),
          'branchId': id,
        };
        if (index >= 0) {
          rows[index] = branch;
        } else {
          rows.add(branch);
        }
        return {'branch': branch};
      default:
        throw StateError('Unexpected fixture action.');
    }
  }
}

Future<AdminConsoleNavigation> _openShell(
  WidgetTester tester,
  GlobalKey boundaryKey,
  _BranchesFixture fixture, {
  BranchRequest? request,
}) async {
  if (!kIsWeb) addTearDown(await installFypOfflineFonts());
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: AppRepositories.injected(
        session: _session,
        coachRepositoryFactory: (scope, _) =>
            EmptyCoachDirectoryRepository(scope),
        accountContactFactory: (scope, _) =>
            NeutralAdminAccountContactRepository(scope: scope),
        child: AdminConsoleApp(
          theme: kIsWeb
              ? ThemeData(colorSchemeSeed: AppColors.primary)
              : AppTheme.build(),
          title: 'GainPath Admin',
          home: AdminShell(
              liveSession: _session, branchRequest: request ?? fixture.request),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final navigation = AdminConsoleNavigation.maybeOf(
    tester.element(find.byType(AdminShell)),
  )!;
  await _go(tester, navigation, '/console/branches');
  return navigation;
}

Future<void> _go(
  WidgetTester tester,
  AdminConsoleNavigation navigation,
  String path,
) async {
  await navigation.setNewRoutePath(Uri.parse(path));
  await tester.pumpAndSettle();
}

Future<void> _press(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String fileName,
) async {
  if (kIsWeb) return;
  final directory = Platform.environment['GAINPATH_BRANCH_RENDER_DIR'];
  if (directory == null) return;
  // The native tile cache uses real disk I/O while the widget test drives a
  // virtual clock. Let the injected tile failure reach the rendered panel.
  for (var frame = 0;
      frame < 10 && find.textContaining('Loading map').evaluate().isNotEmpty;
      frame++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    });
    await tester.pumpAndSettle();
  }
  await tester.runAsync(() async {
    final boundary = boundaryKey.currentContext!.findRenderObject()!
        as RenderRepaintBoundary;
    final image = await boundary.toImage();
    try {
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('$directory/$fileName.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(png!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  const tileUrl = String.fromEnvironment('GAINPATH_BRANCH_TILE_URL');
  final mapSkip = kIsWeb &&
      !(tileUrl.startsWith('http://127.0.0.1:') ||
          tileUrl.startsWith('http://localhost:'));
  BuiltInMapCachingProvider? cache;
  setUpAll(() async {
    if (kIsWeb) return;
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
    final directory =
        await Directory.systemTemp.createTemp('gainpath-map-test-');
    cache = BuiltInMapCachingProvider.getOrCreateInstance(
      cacheDirectory: directory.path,
      maxCacheSize: null,
      readOnly: true,
    );
    await cache!.getTile('https://example.invalid/fixture');
  });
  tearDownAll(() async => await cache?.destroy());
  testWidgets('Branch hub stays usable at every target viewport',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    final boundary = GlobalKey();
    final fixture = _BranchesFixture();
    await _openShell(tester, boundary, fixture);

    const viewports = [
      Size(1920, 1080),
      Size(1536, 864),
      Size(1440, 900),
      Size(1366, 768),
      Size(1280, 720),
      Size(1024, 768),
      Size(390, 844),
    ];
    for (final viewport in viewports) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      final directoryScroll = find
          .descendant(
              of: find.byType(BranchDirectoryPage),
              matching: find.byType(Scrollable))
          .first;
      tester.state<ScrollableState>(directoryScroll).position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(find.text('Branch Management'), findsOneWidget,
          reason: '$viewport');
      expect(find.text('Branches available to this account'), findsOneWidget,
          reason: '$viewport');
      expect(tester.takeException(), isNull, reason: 'Grid $viewport');
      final suffix = '${viewport.width.round()}x${viewport.height.round()}';
      if (viewport.width == 1440 || viewport.width == 390) {
        await _capture(tester, boundary, 'grid-$suffix');
      }

      await _press(tester, find.text('Map'));
      expect(find.byKey(const ValueKey('branch-map-marker:central')),
          findsOneWidget,
          reason: '$viewport');
      expect(
          find.byKey(const ValueKey('branch-map-marker:north')), findsNothing,
          reason: '$viewport');
      expect(find.text('North Park Gym'), findsWidgets, reason: '$viewport');
      expect(find.text('© OpenStreetMap contributors'), findsOneWidget,
          reason: '$viewport');
      expect(tester.takeException(), isNull, reason: 'Map $viewport');
      if (viewport.width == 1440 || viewport.width == 390) {
        final marker = find.byKey(const ValueKey('branch-map-marker:central'));
        await tester.ensureVisible(marker);
        await tester.pumpAndSettle();
        if (viewport.width == 1440) {
          await _press(tester, marker);
        }
        await _capture(tester, boundary, 'map-$suffix');
      }
      await _press(tester, find.text('Grid'));
    }
  }, skip: mapSkip);

  testWidgets('Branch details, pick location and edit retain the shell and ID',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    final boundary = GlobalKey();
    final fixture = _BranchesFixture();
    final navigation = await _openShell(tester, boundary, fixture);

    await _press(tester, find.text('Add Branch').last);
    expect(navigation.uri.path, '/console/branches/add');
    expect(find.text('Save Branch'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await _capture(tester, boundary, 'add-branch-1440x900');
    await _press(tester, find.text('Pick Location on Map'));
    expect(find.text('Confirm Location'), findsOneWidget);
    final pickerMap = find.byType(FlutterMap);
    await _press(tester, pickerMap);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.textContaining('Latitude '), findsOneWidget);
    await _capture(tester, boundary, 'location-picker-1440x900');
    await _press(tester, find.text('Cancel location selection'));

    await _go(tester, navigation, '/console/branches/central/overview');
    expect(find.text('Central Training Centre'), findsWidgets);
    expect(find.text('Free weights'), findsWidgets);
    expect(find.byType(AdminShell), findsOneWidget);
    await _capture(tester, boundary, 'branch-detail-1440x900');

    await _press(tester, find.text('Edit Branch').last);
    expect(navigation.uri.path, '/console/branches/central/edit');
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
    await _capture(tester, boundary, 'edit-branch-1440x900');
    final hours = find.text('Opening hours');
    await tester.ensureVisible(hours);
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'edit-hours-1440x900');
    await tester.ensureVisible(find.text('Facilities').first);
    await tester.pumpAndSettle();
    await _capture(tester, boundary, 'edit-facilities-1440x900');

    final name = find.byWidgetPredicate((widget) =>
        widget is TextFormField &&
        widget.controller?.text == 'Central Training Centre');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Central Athletics Centre');
    await _press(tester, find.text('Save Changes'));
    final command =
        fixture.calls.singleWhere((call) => call['action'] == 'save');
    expect(command['branchId'], 'central');
    expect(command['create'], false);
    final payload = command['branch'] as Map<String, Object?>;
    expect(payload['displayName'], 'Central Athletics Centre');
    expect(payload['address'], '18 Jalan Sentral, Kuala Lumpur');
    expect(payload['latitude'], 3.13);
    expect(payload['openingHours'], _hours);
    expect(tester.takeException(), isNull);
  }, skip: mapSkip);

  testWidgets('Browser route changes protect unsaved branch changes',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 720);
    final fixture = _BranchesFixture();
    final navigation = await _openShell(tester, GlobalKey(), fixture);
    await _go(tester, navigation, '/console/branches/central/edit');
    final name = find.byWidgetPredicate((widget) =>
        widget is TextFormField &&
        widget.controller?.text == 'Central Training Centre');
    await tester.ensureVisible(name);
    await tester.enterText(name, 'Unsaved name');
    await _go(tester, navigation, '/console/branches/central/overview');
    expect(find.text('Discard branch changes?'), findsOneWidget);
    await _press(
        tester,
        find.descendant(
            of: find.byType(Dialog),
            matching: find.widgetWithText(OutlinedButton, 'Cancel')));
    expect(navigation.uri.path, '/console/branches/central/edit');
    expect(find.text('Unsaved name'), findsOneWidget);

    await _go(tester, navigation, '/console/branches/central/overview');
    await _press(tester, find.text('Discard changes'));
    expect(navigation.uri.path, '/console/branches/central/overview');
    expect(find.text('Central Training Centre'), findsWidgets);
    expect(fixture.calls.any((call) => call['action'] == 'save'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Branch directory and editor support 200% text on a narrow screen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final fixture = _BranchesFixture();
    if (kIsWeb) {
      // The browser test fallback font makes the retained Dashboard overflow
      // at this width and scale. Verify the branch module on its own.
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(colorSchemeSeed: AppColors.primary),
        home: BranchDirectoryPage(
          admin: true,
          request: fixture.request,
          openDirections: (_) async => true,
        ),
      ));
      await tester.pumpAndSettle();
    } else {
      await _openShell(tester, GlobalKey(), fixture);
    }
    expect(find.text('Branch Management'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'Grid at narrow 200% text');
    await _press(tester, find.text('Add Branch'));
    expect(find.text('Save Branch'), findsOneWidget);
    expect(tester.takeException(), isNull,
        reason: 'Editor at narrow 200% text');
  });

  testWidgets('Search and status filters persist when leaving a branch',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    final fixture = _BranchesFixture();
    final navigation = await _openShell(tester, GlobalKey(), fixture);
    final search = find.byKey(const ValueKey('admin-branch-search'));
    await _press(tester, find.widgetWithText(ChoiceChip, 'Active'));
    await tester.enterText(search, 'North Park');
    await tester.pumpAndSettle();
    expect(find.text('Central Training Centre'), findsNothing);
    expect(find.text('East Studio'), findsNothing);
    await _press(tester, find.text('Manage Branch'));
    expect(navigation.uri.path, '/console/branches/north/overview');

    await _go(tester, navigation, '/console/branches');
    expect(tester.widget<TextField>(search).controller!.text, 'North Park');
    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Active'))
            .selected,
        isTrue);
    await _press(tester, find.widgetWithText(ChoiceChip, 'Inactive'));
    expect(find.text('No matching branches.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Changing a deep link during pagination resolves the latest branch',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    final fixture = _BranchesFixture();
    final page = Completer<Map<String, dynamic>>();
    final cursors = <String?>[];
    final navigation =
        await _openShell(tester, GlobalKey(), fixture, request: (input) async {
      if (input['action'] != 'list') return fixture.request(input);
      final cursor = input['afterId'] as String?;
      cursors.add(cursor);
      return switch (cursor) {
        null => {'records': fixture.rows, 'nextAfterId': 'east'},
        'east' => page.future,
        'later' => {
            'records': [
              {
                'branchId': 'target-b',
                'displayName': 'Latest Deep Link Branch',
                'status': 'active',
              },
            ],
          },
        _ => throw StateError('Unexpected pagination cursor.'),
      };
    });

    await navigation
        .setNewRoutePath(Uri.parse('/console/branches/missing-a/overview'));
    await tester.pump();
    expect(cursors, [null, 'east']);
    await navigation
        .setNewRoutePath(Uri.parse('/console/branches/target-b/overview'));
    await tester.pump();
    page.complete({
      'records': [
        {'branchId': 'later', 'displayName': 'Another Gym', 'status': 'active'},
      ],
      'nextAfterId': 'later',
    });
    await tester.pump();
    await tester.pump();
    expect(navigation.uri.path, '/console/branches/target-b/overview');
    expect(cursors, [null, 'east', 'later']);
    await tester.pumpAndSettle();
    expect(find.text('Latest Deep Link Branch'), findsWidgets);
    expect(find.text('This branch is unavailable.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Equipment and physical visits keep their branch scope',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    final boundary = GlobalKey();
    final fixture = _BranchesFixture();
    final navigation = await _openShell(tester, boundary, fixture);

    await _go(tester, navigation, '/console/branches/central/equipment');
    expect(find.text('Fixture rower'), findsOneWidget);
    expect(find.byType(AdminShell), findsOneWidget);
    await _go(tester, navigation, '/console/branches/central/visits');
    expect(find.text('No gym visits recorded.'), findsOneWidget);
    await _press(tester, find.text('Generate QR'));
    expect(find.text('Gym check-in QR'), findsOneWidget);
    expect(
      fixture.calls
          .where((call) => const {'inventory', 'branchVisits', 'issueVisitCode'}
              .contains(call['action']))
          .map((call) => call['branchId']),
      ['central', 'central', 'central'],
    );
    expect(tester.takeException(), isNull);
  });
}
