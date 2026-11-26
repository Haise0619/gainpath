import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_schedule_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_details_screen.dart';
import '../../../test_support/fyp_render_support.dart';
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(() async {
    await loadDemoRenderFonts();
    for (final family in ['Barlow', 'BarlowCondensed']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        final path = File('assets/fonts/$family-$weight.ttf').existsSync()
            ? 'assets/fonts/$family-$weight.ttf'
            : 'apps/mobile/assets/fonts/$family-$weight.ttf';
        loader.addFont(Future.value(ByteData.sublistView(
            await File(path).readAsBytes())));
      }
      await loader.load();
    }
  });

  final upcomingBookings = [
    Booking(
      id: 'bk-upcoming-1',
      coachId: 'c1',
      coachName: 'Sarah Jenkins',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 11, 26, 10, 0),
      branch: 'Mid Valley Megamall',
      status: BookingStatus.confirmed,
      durationMin: 60,
      fee: 120.0,
    ),
    Booking(
      id: 'bk-upcoming-2',
      coachId: 'c2',
      coachName: 'Marcus Vance',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 11, 28, 14, 30),
      branch: 'Bangsar South',
      status: BookingStatus.pending,
      durationMin: 45,
      fee: 100.0,
    ),
  ];

  final historyBookings = [
    Booking(
      id: 'bk-completed-1',
      coachId: 'c3',
      coachName: 'Elena Rostova',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 11, 15, 9, 30),
      branch: 'KLCC City Centre',
      status: BookingStatus.completed,
      durationMin: 60,
      fee: 140.0,
      rated: true,
      reviewStars: 5,
    ),
    Booking(
      id: 'bk-completed-2',
      coachId: 'c1',
      coachName: 'Sarah Jenkins',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 11, 8, 16, 0),
      branch: 'Mid Valley Megamall',
      status: BookingStatus.completed,
      durationMin: 45,
      fee: 110.0,
    ),
    Booking(
      id: 'bk-cancelled-1',
      coachId: 'c4',
      coachName: 'David Tan',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 10, 30, 11, 0),
      branch: 'Damansara Heights',
      status: BookingStatus.cancelled,
      durationMin: 30,
      fee: 90.0,
      cancellationReason: 'Work travel reschedule required.',
    ),
    Booking(
      id: 'bk-expired-1',
      coachId: 'c2',
      coachName: 'Marcus Vance',
      memberName: 'Alex Rivera',
      start: DateTime(2026, 10, 22, 15, 0),
      branch: 'Bangsar South',
      status: BookingStatus.pending,
      durationMin: 45,
      fee: 100.0,
    ),
  ];

  Future<void> saveScreenshot(GlobalKey key, String filename) async {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final bytes = byteData.buffer.asUint8List();

    // Save to build renders directory
    final outDir = Directory('../../build/member-bookings-redesign-20261124');
    await outDir.create(recursive: true);
    await File('${outDir.path}/$filename').writeAsBytes(bytes);

    // Also copy to conversation artifact directory
    final artifactDir = Directory('C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314');
    if (await artifactDir.exists()) {
      await File('${artifactDir.path}/$filename').writeAsBytes(bytes);
    }
  }

  Widget buildApp({
    required GlobalKey key,
    required Widget child,
    double width = 360,
    double scale = 1.0,
    bool dark = false,
  }) {
    final base = dark
        ? ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xff6d28d9),
                brightness: Brightness.dark),
            fontFamily: 'Barlow')
        : buildMemberTypographyTheme();
    return RepaintBoundary(
      key: key,
      child: MaterialApp(
        theme: base,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: Size(width, 800),
            textScaler: memberTextScaler(TextScaler.linear(scale)),
          ),
          child: child!,
        ),
        home: Scaffold(body: child),
      ),
    );
  }

  for (final width in [360.0, 393.0, 430.0]) {
    testWidgets('captures member bookings upcoming at width ${width.toInt()}',
        (tester) async {
      final restore = await installFypOfflineFonts();
      addTearDown(restore);
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(buildApp(
        key: key,
        width: width,
        child: BookingScheduleScreen(
          persistedBookings: [...upcomingBookings, ...historyBookings],
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await saveScreenshot(
            key, 'member_bookings_upcoming_${width.toInt()}_light.png');
      });
    });
  }

  testWidgets('captures member bookings upcoming at 320 with 2x text scale',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 320,
      scale: 2.0,
      child: BookingScheduleScreen(
        persistedBookings: [...upcomingBookings, ...historyBookings],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_upcoming_320_2x.png');
    });
  });

  testWidgets('captures member bookings upcoming dark mode at 360',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 360,
      dark: true,
      child: BookingScheduleScreen(
        persistedBookings: [...upcomingBookings, ...historyBookings],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_upcoming_360_dark.png');
    });
  });

  testWidgets('captures member bookings history and filter sheet',
      (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 360,
      child: BookingScheduleScreen(
        persistedBookings: [...upcomingBookings, ...historyBookings],
      ),
    ));
    await tester.pumpAndSettle();

    // Switch to History tab
    await tester.tap(find.byKey(const ValueKey('tab_history')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_history_360_light.png');
    });

    // Tap filter button to open filter sheet
    final filterButton = find.byKey(const ValueKey('booking-filter-button'));
    await tester.tap(filterButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(
          key, 'member_bookings_history_filter_sheet_360.png');
    });

    // Select Completed filter option
    final completedFilter = find.byKey(const ValueKey('filter_completed'));
    await tester.tap(completedFilter);
    await tester.pumpAndSettle();
    final applyButton = find.text('Apply Filters');
    await tester.tap(applyButton);
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_history_filtered_360.png');
    });
  });

  testWidgets('captures empty states for upcoming bookings', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 360,
      child: const BookingScheduleScreen(
        persistedBookings: [],
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_upcoming_empty_360.png');
    });
  });

  testWidgets('captures booking details screen', (tester) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final key = GlobalKey();
    await tester.pumpWidget(buildApp(
      key: key,
      width: 360,
      child: BookingDetailsScreen(
        booking: upcomingBookings.first,
        coachSpecialty: 'Strength & Conditioning',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await saveScreenshot(key, 'member_bookings_card_details_360.png');
    });
  });
}
