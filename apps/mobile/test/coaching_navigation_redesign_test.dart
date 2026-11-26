import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import 'package:gainpath_domain/gainpath_domain.dart' as domain
    show PersistedBookingRecord, BookingStatus;
import 'package:gainpath_mobile/app/notifications/member_notifications_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_schedule_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/booking_card.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../test_support/fyp_render_support.dart';
import 'member_coach_ux_test.dart' show MemberDirectoryFake, coachProfile;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await loadDemoRenderFonts();
  });

  final now = DateTime.utc(2026, 11, 26, 2).millisecondsSinceEpoch;
  final sampleClasses = [
    <String, dynamic>{
      'id': 'class-1',
      'title': 'Morning Vinyasa Flow',
      'description': 'Energizing flow focused on mobility and breath.',
      'category': 'Yoga',
      'branchId': 'branch-1',
      'branchName': 'Downtown Flagship',
      'venue': 'Zen Studio',
      'instructor': 'Marcus Lim',
      'specialty': 'Mobility & Flexibility',
      'startAtMillis': now + 86400000,
      'endAtMillis': now + 86400000 + 3600000,
      'activeCount': 8,
      'capacity': 16,
      'status': 'Open',
      'difficulty': 'All levels',
      'eligibility': 'All Members',
      'registration': null,
    },
    <String, dynamic>{
      'id': 'class-2',
      'title': 'HIIT Metabolic Burn',
      'description': 'High-intensity conditioning circuit.',
      'category': 'HIIT',
      'branchId': 'branch-2',
      'branchName': 'Westside Hub',
      'venue': 'Arena A',
      'instructor': 'Alicia Tan',
      'specialty': 'Strength & Conditioning',
      'startAtMillis': now + 172800000,
      'endAtMillis': now + 172800000 + 2700000,
      'activeCount': 12,
      'capacity': 16,
      'status': 'Open',
      'difficulty': 'Intermediate',
      'eligibility': 'All Members',
      'registration': null,
    },
  ];

  group('GainPath Member Coaching Navigation Redesign', () {
    testWidgets(
        'AppBar shows Messages and equal quick access tiles precede search',
        (tester) async {
      final restoreFonts = await installFypOfflineFonts();
      addTearDown(restoreFonts);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 36, bottom: 24);
      addTearDown(tester.view.reset);

      final repo = MemberDirectoryFake()
        ..items = [
          coachProfile(id: 'c1', name: 'Jackson Alexander', fee: 10000),
          coachProfile(id: 'c2', name: 'Alicia Tan', fee: 12000),
        ];

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BrowseCoachesScreen(
          live: true,
          liveRepository: repo,
          isCurrent: () => true,
          onMessages: () {},
          onOpenGroupClasses: () {},
          bookingsBuilder: (_) => const BookingScheduleScreen(
            persistedBookings: [],
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Top-level Personal Coaching / Group Classes ChoiceChip switcher is removed
      expect(find.text('Personal Coaching'), findsNothing);

      // Coaches AppBar and outlined Bookings action sit cleanly below status bar
      final appBarRect = tester.getRect(find.byType(AppBar));
      final bookingsFinder =
          find.byKey(const Key('coaches-my-bookings-button'));
      final chatFinder = find.byTooltip('Messages');
      expect(bookingsFinder, findsOneWidget);
      expect(chatFinder, findsOneWidget);

      final bookingsRect = tester.getRect(bookingsFinder);
      final chatRect = tester.getRect(chatFinder);
      final coachesTitleRect = tester.getRect(find.text('Coaches'));

      expect(appBarRect.top, equals(0));
      expect(coachesTitleRect.top, greaterThanOrEqualTo(36));
      expect(bookingsRect.top, greaterThan(appBarRect.bottom));
      expect(chatRect.size.shortestSide, greaterThanOrEqualTo(48));
      final classesRect =
          tester.getRect(find.byKey(const Key('coaches-group-classes-entry')));
      expect(bookingsRect.size, classesRect.size);
      expect(classesRect.bottom,
          lessThan(tester.getTopLeft(find.byType(TextField)).dy));

      // AppBar no longer shows the competing Classes pill; Group Classes is in More ways to train
      expect(find.text('Classes'), findsNothing);
      expect(find.text('My Bookings'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today_outlined), findsOneWidget);
      expect(
          find.byKey(const Key('coaches-group-classes-entry')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'End-to-end flow preserves Bottom Navigation, Find Coach state, registration, cancellation, and Back navigation',
        (tester) async {
      final restoreFonts = await installFypOfflineFonts();
      addTearDown(restoreFonts);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      var registered = false;
      Future<Map<String, dynamic>> mockClassCall(
          String action, Map<String, dynamic> input) async {
        final class0 = {
          ...sampleClasses[0],
          'registration': registered ? 'Registered' : null,
          'eligible': true,
        };
        if (action == 'join') {
          registered = true;
          return {'saved': true};
        }
        if (action == 'leave') {
          registered = false;
          return {'saved': true};
        }
        if (action == 'detail') {
          return {
            'item': class0,
            'serverNowMillis': now,
          };
        }
        return {
          'classes': [class0, sampleClasses[1]]
        };
      }

      final repo = MemberDirectoryFake()
        ..items = [
          coachProfile(id: 'c1', name: 'Jackson Alexander', fee: 10000),
          coachProfile(id: 'c2', name: 'Alicia Tan', fee: 12000),
        ];

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: Builder(
          builder: (context) => Scaffold(
            body: BrowseCoachesScreen(
              live: true,
              liveRepository: repo,
              isCurrent: () => true,
              onOpenGroupClasses: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MemberGroupClassesScreen(
                      call: mockClassCall,
                      onUpgrade: () {},
                    ),
                  ),
                );
              },
              bookingsBuilder: (_) => const BookingScheduleScreen(
                persistedBookings: [],
                embedded: true,
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 3,
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined),
                    label: 'Workout'),
                NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline_rounded), label: 'Coaches'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Exactly 5 bottom nav destinations; no extra Group Classes tab added
      expect(find.byType(NavigationDestination), findsNWidgets(5));

      // Search in Find Coach and verify filtered coach result
      await tester.enterText(find.byType(TextField), 'Jackson');
      await tester.pumpAndSettle();
      expect(find.text('Jackson Alexander'), findsOneWidget);
      expect(find.text('Alicia Tan'), findsNothing);

      // Navigate: Coaches -> Group Classes
      await tester.tap(find.byKey(const Key('coaches-group-classes-entry')));
      await tester.pumpAndSettle();

      // Standalone Group Classes Screen with own AppBar, no Personal Coaching repeated
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Group Classes'), findsOneWidget);
      expect(find.text('Personal Coaching'), findsNothing);
      expect(find.text('Explore Classes'), findsOneWidget);
      expect(find.text('My Classes'), findsOneWidget);
      expect(find.text('Morning Vinyasa Flow'), findsOneWidget);

      // Navigate to Class Details, join, then cancel
      await tester.tap(find.text('Morning Vinyasa Flow'));
      await tester.pumpAndSettle();
      expect(find.text('Class details'), findsOneWidget);
      await tester.tap(find.text('Join Class'));
      await tester.pumpAndSettle();
      expect(registered, isTrue);

      await tester.tap(find.text('Cancel registration'));
      await tester.pumpAndSettle();
      await tester
          .tap(find.widgetWithText(FilledButton, 'Cancel registration'));
      await tester.pumpAndSettle();
      expect(registered, isFalse);

      // Back to standalone Group Classes screen
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Explore Classes'), findsOneWidget);

      // Back to Coaches screen -> state and bottom nav preserved!
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Find your coach'), findsNothing);
      expect(find.text('Jackson'), findsOneWidget);
      expect(find.text('Jackson Alexander'), findsOneWidget);
      expect(find.text('Alicia Tan'), findsNothing);
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets(
        'Class registration notification deep link navigates directly to MemberGroupClassDetails',
        (tester) async {
      String? openedGroupClassId;
      const session = AuthSession(
        userId: 'm1',
        organizationId: 'gym1',
        email: 'm1@gainpath.test',
        role: AppRole.member,
        branchIds: ['main'],
      );
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: MemberNotificationsScreen(
          session: session,
          isCurrent: () => true,
          onOpenGroupClass: (id) => openedGroupClassId = id,
          initialItems: [
            UnifiedNotificationItem(
              id: 'n-gc-1',
              category: NotificationCategoryFilter.bookings,
              title: 'Spot confirmed: Morning Vinyasa Flow',
              message: 'You are registered for tomorrow 10:00 AM.',
              timestamp: DateTime.fromMillisecondsSinceEpoch(now),
              isRead: false,
              groupClassId: 'class-yoga-1',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Spot confirmed: Morning Vinyasa Flow'));
      await tester.pumpAndSettle();

      expect(openedGroupClassId, equals('class-yoga-1'));
    });

    for (final width in [320.0, 360.0, 393.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
            'Coaches with Group Classes card renders cleanly at ${width.toInt()}dp scale=${scale}x with status bar inset',
            (tester) async {
          final restoreFonts = await installFypOfflineFonts();
          addTearDown(restoreFonts);
          tester.view.physicalSize = Size(width, 852);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 32, bottom: 24);
          addTearDown(tester.view.reset);

          final repo = MemberDirectoryFake()
            ..items = [
              coachProfile(
                  id: 'c1',
                  name: 'Jackson Alexander Montgomery with a long name',
                  fee: 10000),
            ];

          await tester.pumpWidget(MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: BrowseCoachesScreen(
              live: true,
              liveRepository: repo,
              isCurrent: () => true,
              loadBranches: () async => {
                'branch_internal_42':
                    'GainPath International Training and Performance Centre',
              },
              onMessages: () {},
              onOpenGroupClasses: () {},
              bookingsBuilder: (_) => const BookingScheduleScreen(
                persistedBookings: [],
                embedded: true,
              ),
            ),
          ));
          await tester.pumpAndSettle();

          expect(
            find.byKey(const Key('coaches-group-classes-entry')),
            findsOneWidget,
          );
          expect(find.text('Group Classes'), findsOneWidget);
          expect(find.text('Classes'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }

    for (final count in [0, 1, 10, 50]) {
      testWidgets('quick access precedes all $count directory results',
          (tester) async {
        final restoreFonts = await installFypOfflineFonts();
        addTearDown(restoreFonts);
        tester.view.physicalSize = const Size(393, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = MemberDirectoryFake()
          ..items = [
            for (var index = 0; index < count; index++)
              coachProfile(
                id: 'fixture-$index',
                name: 'Coach ${index.toString().padLeft(2, '0')}',
                fee: 10000,
              ),
          ];
        var openedMessages = false;
        var openedClasses = false;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(),
          home: BrowseCoachesScreen(
            live: true,
            liveRepository: repo,
            isCurrent: () => true,
            onMessages: () => openedMessages = true,
            onOpenGroupClasses: () => openedClasses = true,
          ),
        ));
        await tester.pumpAndSettle();

        final classes = find.byKey(const Key('coaches-group-classes-entry'));
        expect(tester.getBottomLeft(classes).dy,
            lessThan(tester.getTopLeft(find.byType(TextField)).dy));
        expect(
            find.text('$count ${count == 1 ? 'coach' : 'coaches'} available'),
            findsOneWidget);
        if (count == 0) {
          expect(find.text('No coaches available'), findsOneWidget);
        } else {
          expect(find.text('Coach 00'), findsOneWidget);
        }
        await tester.tap(classes);
        await tester.tap(find.byTooltip('Messages'));
        expect(openedClasses, isTrue);
        expect(openedMessages, isTrue);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Capture screenshots for Coaching Navigation Redesign',
        (tester) async {
      final restoreFonts = await installFypOfflineFonts();
      addTearDown(restoreFonts);

      final buildDir = Directory('../../build/coaching-navigation-redesign')
        ..createSync(recursive: true);

      Future<void> capture(GlobalKey key, String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1.0);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final raw = bytes!.buffer.asUint8List();
          await File('${buildDir.path}/$name').writeAsBytes(raw);
          image.dispose();
        });
      }

      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // 1. Coaches main screen with Find Coach / My Bookings + compact Group Classes entry + Bottom Navigation
      {
        final key = GlobalKey();
        final repo = MemberDirectoryFake()
          ..items = [
            coachProfile(id: 'c1', name: 'Jackson Alexander', fee: 10000),
            coachProfile(id: 'c2', name: 'Alicia Tan', fee: 12000),
          ];

        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: Scaffold(
              body: BrowseCoachesScreen(
                live: true,
                liveRepository: repo,
                isCurrent: () => true,
                onMessages: () {},
                onOpenGroupClasses: () {},
                bookingsBuilder: (_) => const BookingScheduleScreen(
                  persistedBookings: [],
                  embedded: true,
                ),
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: 3,
                destinations: const [
                  NavigationDestination(
                      icon: Icon(Icons.home_outlined), label: 'Home'),
                  NavigationDestination(
                      icon: Icon(Icons.fitness_center_outlined),
                      label: 'Workout'),
                  NavigationDestination(
                      icon: Icon(Icons.emoji_events_outlined),
                      label: 'Rewards'),
                  NavigationDestination(
                      icon: Icon(Icons.people_rounded), label: 'Coaches'),
                  NavigationDestination(
                      icon: Icon(Icons.person_outline_rounded),
                      label: 'Profile'),
                ],
              ),
            ),
          ),
        ));
        await capture(key, 'coaches_with_group_classes_entry_393.png');
      }

      // 2. Standalone Group Classes screen (pushed with Back arrow & AppBar)
      {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemberGroupClassesScreen(
                          call: (_, __) async => {'classes': sampleClasses},
                          onUpgrade: () {},
                        ),
                      ),
                    ),
                    child: const Text('Open Group Classes'),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.tap(find.text('Open Group Classes'));
        await capture(key, 'group_classes_standalone_explore_393.png');
      }

      // 3. Group Classes Empty State ("No classes available yet")
      {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: MemberGroupClassesScreen(
              call: (_, __) async => {'classes': <Map<String, dynamic>>[]},
              onUpgrade: () {},
            ),
          ),
        ));
        await capture(key, 'group_classes_empty_state_393.png');
      }

      // 4. Group Classes Filtered Empty State ("Clear Filters")
      {
        final key = GlobalKey();
        await tester.pumpWidget(RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: MemberGroupClassesScreen(
              call: (_, __) async => {'classes': sampleClasses},
              onUpgrade: () {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Pilates Reformer');
        await capture(key, 'group_classes_filtered_empty_393.png');
      }
    });
  });

  group('GainPath Coaches & My Bookings Navigation Refinement', () {
    domain.PersistedBookingRecord makeRecord({
      required String id,
      required String coachId,
      required DateTime start,
      required int durationMin,
      required domain.BookingStatus status,
      required int feeMinor,
      String paymentStatus = 'cleared',
      String? refundStatus,
      bool refundUnavailable = false,
    }) {
      final startMs = start.millisecondsSinceEpoch;
      final endMs =
          start.add(Duration(minutes: durationMin)).millisecondsSinceEpoch;
      return domain.PersistedBookingRecord(
        bookingId: id,
        organizationId: 'org-1',
        memberId: 'mem-1',
        coachId: coachId,
        branchId: 'branch-1',
        requestId: 'req-$id',
        startAtMillis: startMs,
        endAtMillis: endMs,
        durationMinutes: durationMin,
        status: status,
        holdExpiresAtMillis: startMs,
        localDate: '2026-11-12',
        timeZone: 'Asia/Kuala_Lumpur',
        policyVersion: 'v1',
        createdAtMillis: startMs - 3600000,
        startLabel: '10:00',
        endLabel: '11:00',
        expiryLabel: '10:15',
        feeMinor: feeMinor,
        paymentStatus: paymentStatus,
        refundStatus: refundStatus,
        refundUnavailable: refundUnavailable,
      );
    }

    testWidgets(
        'Coaches opens Find Coach directly, navigates to standalone My Bookings with underline tabs, preserves tab/filter/search state, and renders compact BookingCards',
        (tester) async {
      final restoreFonts = await installFypOfflineFonts();
      addTearDown(restoreFonts);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final repo = MemberDirectoryFake()
        ..items = [
          coachProfile(id: 'c1', name: 'Jackson Alexander', fee: 12000),
          coachProfile(id: 'c2', name: 'Alicia Tan', fee: 14500),
        ];

      final upcomingBooking = Booking(
        id: 'b-upcoming',
        coachId: 'c1',
        coachName: 'Jackson Alexander',
        memberName: 'Alex',
        start: DateTime(2026, 12, 10, 10, 0),
        durationMin: 60,
        branch: 'GainPath Main Studio',
        status: BookingStatus.confirmed,
        fee: 120.0,
      );
      final completedBooking = Booking(
        id: 'b-completed',
        coachId: 'c1',
        coachName: 'Jackson Alexander',
        memberName: 'Alex',
        start: DateTime(2026, 11, 12, 15, 0),
        durationMin: 60,
        branch: 'GainPath Main Studio',
        status: BookingStatus.completed,
        fee: 120.0,
      );
      final cancelledRefundBooking = Booking(
        id: 'b-refund',
        coachId: 'c2',
        coachName: 'Alicia Tan',
        memberName: 'Alex',
        start: DateTime(2026, 11, 10, 9, 0),
        durationMin: 45,
        branch: 'Westside Hub',
        status: BookingStatus.cancelled,
        fee: 145.0,
      );

      final records = {
        'b-completed': makeRecord(
          id: 'b-completed',
          coachId: 'c1',
          start: completedBooking.start,
          durationMin: 60,
          status: domain.BookingStatus.completed,
          feeMinor: 12000,
          refundUnavailable: false,
        ),
        'b-refund': makeRecord(
          id: 'b-refund',
          coachId: 'c2',
          start: cancelledRefundBooking.start,
          durationMin: 60,
          status: domain.BookingStatus.cancelled,
          feeMinor: 14500,
          refundStatus: 'processing',
        ),
      };

      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: BrowseCoachesScreen(
          live: true,
          liveRepository: repo,
          isCurrent: () => true,
          onMessages: () {},
          onOpenGroupClasses: () {},
          bookingsBuilder: (_) => BookingScheduleScreen(
            persistedBookings: [
              upcomingBooking,
              completedBooking,
              cancelledRefundBooking,
            ],
            recordFor: (id) => records[id],
            serverNowMillis:
                DateTime(2026, 11, 25, 10, 0).millisecondsSinceEpoch,
            onPayment: (_) {},
            onReview: (_) {},
            embedded: true,
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // 1. Coaches homepage opens Find your coach directly with outlined Bookings in AppBar and More ways to train card
      expect(find.text('Find your coach'), findsNothing);
      expect(find.text('Find the right trainer for your goals.'), findsNothing);
      expect(
          find.byKey(const Key('coaches-my-bookings-button')), findsOneWidget);
      expect(find.text('My Bookings'), findsOneWidget);
      expect(find.text('More ways to train'), findsNothing);
      expect(find.text('Group Classes'), findsOneWidget);
      expect(find.text('Explore classes'), findsNothing);
      expect(
          find.byKey(const Key('coaches-group-classes-entry')), findsOneWidget);
      expect(find.byTooltip('Messages'), findsOneWidget);
      expect(find.byType(Badge), findsNothing);

      // Type a search query to verify state preservation across My Bookings navigation
      await tester.enterText(find.byType(TextField), 'Jackson');
      await tester.pumpAndSettle();
      expect(find.text('Jackson Alexander'), findsOneWidget);
      expect(find.text('Alicia Tan'), findsNothing);

      // 2. Navigate to standalone My Bookings screen
      await tester.tap(find.byKey(const Key('coaches-my-bookings-button')));
      await tester.pumpAndSettle();

      expect(find.text('My Bookings'), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_upcoming')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_history')), findsOneWidget);

      // Verify separated date/price rows without oversized surfaceAlt box inside BookingCard
      final cardFinder = find.byType(BookingCard).first;
      expect(
        find.descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate((w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).color == AppColors.surfaceAlt),
        ),
        findsNothing,
      );
      expect(find.text('RM 120.00'), findsOneWidget);

      // 3. Switch to History tab & verify status + compact OutlinedButton actions
      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await tester.pumpAndSettle();

      // refundUnavailable must NOT overwrite booking status
      expect(find.text('Refund unavailable'), findsNothing);
      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Refund processing'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Leave a review'),
          findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Refund Details'),
          findsOneWidget);

      // 4. Filter History and open Booking Details -> Back preserves History tab + filter
      await tester.tap(find.byKey(const ValueKey('booking-filter-button')));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const ValueKey('filter_cancelled')));
      await tester.tap(find.byKey(const ValueKey('filter_cancelled')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Apply Filters'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(find.text('Alicia Tan'), findsOneWidget);
      expect(find.text('Jackson Alexander'), findsNothing);

      await tester.tap(find.text('View details').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Still on History tab with Refunded filter active
      expect(find.text('Alicia Tan'), findsOneWidget);
      expect(find.text('Jackson Alexander'), findsNothing);

      // 5. Back to Coaches preserves Find your coach search query
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Find your coach'), findsNothing);
      expect(find.text('Jackson Alexander'), findsOneWidget);
      expect(find.text('Alicia Tan'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Capture screenshots for Coaches & My Bookings Refinement',
        (tester) async {
      final restoreFonts = await installFypOfflineFonts();
      addTearDown(restoreFonts);
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      Future<void> capture(GlobalKey key, String filename) async {
        await tester.pumpAndSettle();
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final img = await boundary.toImage(pixelRatio: 2.0);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          final file =
              File('../../build/coaching-navigation-redesign/$filename');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          img.dispose();
        });
      }

      final repo = MemberDirectoryFake()
        ..items = [
          coachProfile(id: 'c1', name: 'Jackson Alexander', fee: 12000),
          coachProfile(id: 'c2', name: 'Alicia Tan', fee: 14500),
        ];
      final upcoming = Booking(
        id: 'b-upcoming',
        coachId: 'c1',
        coachName: 'Jackson Alexander',
        memberName: 'Alex',
        start: DateTime(2026, 12, 10, 10, 0),
        durationMin: 60,
        branch: 'GainPath Main Studio',
        status: BookingStatus.confirmed,
        fee: 120.0,
      );
      final completed = Booking(
        id: 'b-completed',
        coachId: 'c1',
        coachName: 'Jackson Alexander',
        memberName: 'Alex',
        start: DateTime(2026, 11, 12, 15, 0),
        durationMin: 60,
        branch: 'GainPath Main Studio',
        status: BookingStatus.completed,
        fee: 120.0,
      );
      final refunded = Booking(
        id: 'b-refund',
        coachId: 'c2',
        coachName: 'Alicia Tan',
        memberName: 'Alex',
        start: DateTime(2026, 11, 10, 9, 0),
        durationMin: 45,
        branch: 'Westside Hub',
        status: BookingStatus.cancelled,
        fee: 145.0,
      );
      final records = {
        'b-completed': makeRecord(
          id: 'b-completed',
          coachId: 'c1',
          start: completed.start,
          durationMin: 60,
          status: domain.BookingStatus.completed,
          feeMinor: 12000,
          refundUnavailable: false,
        ),
        'b-refund': makeRecord(
          id: 'b-refund',
          coachId: 'c2',
          start: refunded.start,
          durationMin: 60,
          status: domain.BookingStatus.cancelled,
          feeMinor: 14500,
          refundStatus: 'processing',
        ),
      };

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: BrowseCoachesScreen(
            live: true,
            liveRepository: repo,
            isCurrent: () => true,
            loadBranches: () async => {'branch_internal_42': 'GainPath 2'},
            loadSelectedBranch: () async => 'branch_internal_42',
            onMessages: () {},
            onOpenGroupClasses: () {},
            bookingsBuilder: (_) => BookingScheduleScreen(
              persistedBookings: [upcoming, completed, refunded],
              recordFor: (id) => records[id],
              serverNowMillis:
                  DateTime(2026, 11, 25, 10, 0).millisecondsSinceEpoch,
              onPayment: (_) {},
              onReview: (_) {},
              embedded: true,
            ),
          ),
        ),
      ));
      await capture(key, 'coaches_home_reconstructed_393.png');
      await tester.enterText(find.byType(TextField), 'Jackson');
      FocusManager.instance.primaryFocus?.unfocus();
      await capture(key, 'coaches_home_one_393.png');
      await tester.tap(find.byTooltip('Clear search query'));
      await tester.pumpAndSettle();

      // Apply specialty filter to capture compact active-filter summary
      await tester.tap(find.byTooltip('Filter and sort coaches'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Strength'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Strength'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Filters'));
      await capture(key, 'coaches_home_filtered_393.png');

      await tester.tap(find.byKey(const Key('coaches-my-bookings-button')));
      await capture(key, 'my_bookings_upcoming_underline_393.png');

      await tester.tap(find.byKey(const ValueKey('tab_history')));
      await capture(key, 'my_bookings_history_cards_393.png');
    });
  });
}
