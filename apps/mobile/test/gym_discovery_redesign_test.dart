import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/app/home/member_home_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (methodCall) async {
        if (methodCall.method == 'getApplicationCacheDirectory') {
          return Directory.systemTemp.path;
        }
        return null;
      },
    );
  });

  const artifactDir = 'build/member-ui-renders';

  final sampleBranches = [
    {
      'branchId': 'main',
      'displayName': 'GainPath Main Gym & Performance',
      'address': 'No. 88, Jalan Ampang, 50450 Kuala Lumpur',
      'city': 'Kuala Lumpur',
      'state': 'WP Kuala Lumpur',
      'postalCode': '50450',
      'country': 'Malaysia',
      'description':
          'Flagship training facility featuring competition powerlifting racks, Olympic lifting platforms, and dedicated movement assessment bays.',
      'contactPhone': '+60321881234',
      'status': 'active',
      'facilities': [
        'Free Weights Zone',
        'Olympic Lifting',
        'Cardio Loft',
        'Steam & Sauna',
        'Showers & Lockers',
        'Recovery Bay',
      ],
      'openingHours': [
        {'open': '06:00', 'close': '23:00'},
        {'open': '06:00', 'close': '23:00'},
        {'open': '06:00', 'close': '23:00'},
        {'open': '06:00', 'close': '23:00'},
        {'open': '06:00', 'close': '23:00'},
        {'open': '08:00', 'close': '21:00'},
        {'open': '08:00', 'close': '21:00'},
      ],
      'latitude': 3.158,
      'longitude': 101.711,
    },
    {
      'branchId': 'bangsar',
      'displayName': 'GainPath Bangsar South',
      'address': 'Level 2, The Sphere, Jalan Kerinchi, 59200 Kuala Lumpur',
      'city': 'Kuala Lumpur',
      'status': 'active',
      'facilities': ['Cardio Cinema', 'Functional Turf', 'Smoothie Bar'],
      'openingHours': [
        {'open': '06:00', 'close': '22:00'},
        {'open': '06:00', 'close': '22:00'},
        {'open': '06:00', 'close': '22:00'},
        {'open': '06:00', 'close': '22:00'},
        {'open': '06:00', 'close': '22:00'},
        {'open': '08:00', 'close': '20:00'},
        {'open': '08:00', 'close': '20:00'},
      ],
      'latitude': 3.112,
      'longitude': 101.665,
    },
    {
      'branchId': 'pj',
      'displayName': 'GainPath Uptown Petaling Jaya',
      'address': '45 Jalan SS 21/37, Damansara Utama, 47400 Petaling Jaya',
      'status': 'active',
      'facilities': ['Squat Racks', 'Calisthenics Cage'],
      'openingHours': [
        {'open': '07:00', 'close': '23:00'},
        {'open': '07:00', 'close': '23:00'},
        {'open': '07:00', 'close': '23:00'},
        {'open': '07:00', 'close': '23:00'},
        {'open': '07:00', 'close': '23:00'},
        {'open': '08:00', 'close': '20:00'},
        {'open': '08:00', 'close': '20:00'},
      ],
      'latitude': 3.134,
      'longitude': 101.623,
    },
  ];

  Future<void> saveScreenshot(
      GlobalKey key, WidgetTester tester, String filename) async {
    await tester.runAsync(() async {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final file = File('$artifactDir/$filename');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'GymBranchSwitcherSheet renders active branches, checkmark, and explore CTA',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    String? selectedId;
    var explored = false;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: key,
          child: Container(
            color: Colors.black54,
            alignment: Alignment.bottomCenter,
            child: GymBranchSwitcherSheet(
              branches: sampleBranches,
              selectedBranchId: 'main',
              homeBranchId: 'main',
              onSelectBranch: (id) => selectedId = id,
              onExploreAll: () => explored = true,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Choose your gym'), findsOneWidget);
    expect(find.text('GainPath Main Gym & Performance'), findsOneWidget);
    expect(find.text('GainPath Bangsar South'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore All Gyms'), findsOneWidget);

    await saveScreenshot(key, tester, 'gym_discovery_switcher_sheet.png');

    await tester.tap(find.text('GainPath Bangsar South'));
    await tester.pumpAndSettle();
    expect(selectedId, 'bangsar');

    await tester.tap(find.text('Explore All Gyms'));
    await tester.pumpAndSettle();
    expect(explored, isTrue);
  });

  testWidgets(
      'BranchDirectoryPage renders modern Explore Gyms layout and card items',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: RepaintBoundary(
        key: key,
        child: BranchDirectoryPage(
          request: (input) async => {
            'records': sampleBranches,
            'selectedBranchId': 'main',
            'homeBranchId': 'main',
          },
          openDirections: (_) async => true,
          scanVisit: (_) async =>
              'gainpath-visit:main:01234567890123456789012345678901',
          locate: () async => (latitude: 3.158, longitude: 101.711),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Explore Gyms'), findsOneWidget);
    expect(find.text('Find your next place to train.'), findsOneWidget);
    expect(find.text('Near me'), findsOneWidget);
    expect(find.text('List'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);
    expect(find.text('All gyms'), findsOneWidget);
    expect(find.text('3 locations'), findsOneWidget);
    expect(find.text('GainPath Main Gym & Performance'), findsOneWidget);
    expect(find.text('Current gym'), findsOneWidget);
    expect(find.text('Home gym'), findsOneWidget);
    expect(find.text('Directions'), findsWidgets);
    expect(find.text('View gym'), findsWidgets);

    // Verify duplicated content buttons and old oversized badges are removed
    expect(find.widgetWithText(OutlinedButton, 'Gym check-in'), findsNothing);
    expect(find.widgetWithText(TextButton, 'My gym visits'), findsNothing);
    expect(find.text('Selected branch'), findsNothing);
    expect(find.text('Home branch'), findsNothing);
    expect(find.text('Open now · MYT'), findsNothing);

    await saveScreenshot(key, tester, 'gym_discovery_explore_list.png');

    // Test map segmented toggle
    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.byType(BranchMap), findsOneWidget);
    await saveScreenshot(key, tester, 'gym_discovery_explore_map.png');

    // Switch back to list
    await tester.tap(find.text('List'));
    await tester.pumpAndSettle();
    expect(find.byType(BranchMap), findsNothing);
  });

  testWidgets('Member Home header displays compact BranchSelectorPill',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var tapped = false;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: Scaffold(
        backgroundColor: AppColors.primaryDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: RepaintBoundary(
              key: key,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Text(
                      'GainPath',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    BranchSelectorPill(
                      branchName: 'Main Gym',
                      onTap: () => tapped = true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GainPath'), findsOneWidget);
    expect(find.text('Main Gym'), findsOneWidget);
    expect(find.byIcon(Icons.location_on_rounded), findsOneWidget);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsOneWidget);

    await saveScreenshot(key, tester, 'gym_discovery_home_header.png');

    await tester.tap(find.text('Main Gym'));
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets(
      'GymDetailsScreen renders hero cover, quick actions, hours, and sticky bar',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    var gymSelected = false;

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: RepaintBoundary(
        key: key,
        child: GymDetailsScreen(
          branch: sampleBranches.first,
          isHome: true,
          isSelected: false,
          openDirections: (_) async => true,
          onSelectGym: () async => gymSelected = true,
          onSetHome: () async {},
          onCheckIn: () async {},
          onOpenEquipment: () {},
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('GainPath Main Gym & Performance'), findsOneWidget);
    expect(find.text('Get directions'), findsOneWidget);
    expect(find.text('Copy address'), findsOneWidget);
    expect(find.text('Call gym'), findsOneWidget);
    expect(find.text('Location & Address'), findsOneWidget);
    expect(find.text('Opening Hours'), findsOneWidget);
    expect(find.text('Facilities & Amenities'), findsOneWidget);
    expect(find.text('Branch Equipment'), findsOneWidget);
    expect(find.text('Home Branch'), findsWidgets);
    expect(find.text('Select this gym'), findsOneWidget);

    await saveScreenshot(key, tester, 'gym_discovery_details_screen.png');

    await tester.tap(find.text('Select this gym'));
    await tester.pumpAndSettle();
    expect(gymSelected, isTrue);
  });

  testWidgets(
      'BranchActivityPage member visits view renders calendar date timeline',
      (tester) async {
    final key = GlobalKey();
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime(2026, 11, 19, 14, 30);
    final earlier = DateTime(2026, 11, 19, 9, 15);
    final yesterday = DateTime(2026, 11, 18, 18, 45);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: RepaintBoundary(
        key: key,
        child: BranchActivityPage(
          title: 'Gym visits',
          visits: true,
          admin: false,
          branchId: 'main',
          request: (input) async => {
            'records': [
              {
                'visitId': 'v1',
                'branchId': 'main',
                'timestampMillis': now.millisecondsSinceEpoch,
              },
              {
                'visitId': 'v2',
                'branchId': 'main',
                'timestampMillis': earlier.millisecondsSinceEpoch,
              },
              {
                'visitId': 'v3',
                'branchId': 'bangsar',
                'timestampMillis': yesterday.millisecondsSinceEpoch,
              },
            ],
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Gym visits'), findsOneWidget);
    expect(find.text('3 loaded'), findsOneWidget);
    expect(find.text('Thursday, 19 November 2026'), findsOneWidget);
    expect(find.text('Wednesday, 18 November 2026'), findsOneWidget);
    expect(find.text('Verified check-in'), findsWidgets);

    await saveScreenshot(key, tester, 'gym_discovery_visits_timeline.png');
  });

  testWidgets(
      'BranchDirectoryPage handles edge cases and multi-viewport responsiveness (320, 360, 393, 412px)',
      (tester) async {
    final edgeBranches = [
      {
        'branchId': 'edge-1',
        'displayName':
            'GainPath Super Long Elite Olympic Performance & High Altitude Conditioning Training Center',
        'address': '', // Missing address
        'status': 'active',
        // Missing opening hours
        // Missing cover image
      },
      {
        'branchId': 'edge-2',
        'displayName': 'GainPath Minimal',
        'address': 'Ground Floor, Plaza Sentral',
        'status': 'active',
        'openingHours': [
          {'allDay': true},
          {'allDay': true},
          {'allDay': true},
          {'allDay': true},
          {'allDay': true},
          {'allDay': true},
          {'allDay': true},
        ],
      },
    ];

    const viewports = [
      Size(320, 568), // iPhone SE
      Size(360, 800), // Compact Android
      Size(393, 852), // iPhone 15 Pro
      Size(412, 915), // Pixel 8
    ];

    for (final size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      FlutterErrorDetails? caughtDetails;
      final prevOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        caughtDetails = details;
      };

      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: Scaffold(
          body: BranchDirectoryPage(
            request: (input) async => {
              'records': edgeBranches,
              'selectedBranchId': 'edge-1',
              'homeBranchId': 'edge-1', // Simultaneously Current and Home
            },
            openDirections: (_) async => true,
            locate: () async => (latitude: 3.14, longitude: 101.68),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // On 320 to 412, edge-1 should show both Current gym and Home gym
      expect(find.text('Current gym'), findsOneWidget);
      expect(find.text('Home gym'), findsOneWidget);
      expect(find.text('Opening hours unavailable'), findsOneWidget);

      // Scroll to reveal edge-2
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(find.text('Open 24 hours'), findsOneWidget);

      // Verify no exceptions or overflow occurred
      FlutterError.onError = prevOnError;
      expect(caughtDetails, isNull);
      expect(tester.takeException(), isNull);
    }
  });
}
