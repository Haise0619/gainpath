import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'live_booking_composition_test.dart' show Lists;
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/coach_card.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import 'member_coach_ux_test.dart'
    show MemberDirectoryFake, coachProfile, shell;

class CountingBookings extends Lists {
  int reads = 0;
  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) {
    reads++;
    return super.load(
        coachId: coachId,
        firstLocalDate: firstLocalDate,
        dayCount: dayCount,
        cursor: cursor);
  }
}

void main() {
  for (final width in [320.0, 360.0]) {
    testWidgets('live inline bookings fit $width at 200 percent text',
        (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(shell(
          BrowseCoachesScreen(
              live: true,
              liveRepository: MemberDirectoryFake(),
              isCurrent: () => true,
              bookingsBuilder: (_) => LiveBookingListView(
                  repository: Lists(), isCurrent: () => true, embedded: true)),
          scale: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Bookings'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
      'former-account booking content is hidden when the session changes',
      (tester) async {
    var current = true;
    final repo = MemberDirectoryFake();
    Widget page() => shell(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => current,
        bookingsBuilder: (_) => const Text('Private previous bookings')));
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Private previous bookings'), findsOneWidget);
    current = false;
    await tester.pumpWidget(page());
    await tester.pumpAndSettle();
    expect(find.text('Private previous bookings'), findsNothing);
    expect(find.text('Bookings unavailable for this session.'), findsOneWidget);
  });
  testWidgets(
      'hidden embedded bookings pause refresh and refresh when shown again',
      (tester) async {
    final repo = CountingBookings();
    var active = true;
    late StateSetter update;
    await tester.pumpWidget(shell(StatefulBuilder(builder: (context, setState) {
      update = setState;
      return TickerMode(
          enabled: active,
          child: LiveBookingListView(
              repository: repo, isCurrent: () => true, embedded: true));
    })));
    await tester.pumpAndSettle();
    expect(repo.reads, 1);
    expect(find.byType(AppBar), findsNothing);
    update(() => active = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 31));
    expect(repo.reads, 1);
    update(() => active = true);
    await tester.pumpAndSettle();
    expect(repo.reads, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'tabs embed bookings lazily and retain search without pushing a route',
      (tester) async {
    final repo = MemberDirectoryFake();
    var built = 0;
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true,
        liveRepository: repo,
        isCurrent: () => true,
        bookingsBuilder: (_) {
          built++;
          return const TextField(key: ValueKey('booking-search'));
        })));
    await tester.pumpAndSettle();
    expect(find.text('Find your coach'), findsNothing);
    expect(find.byTooltip('My bookings'), findsNothing);
    expect(find.text('Find Coach'), findsOneWidget);
    expect(built, 0);
    await tester.enterText(find.byType(TextField), 'Jack');
    await tester.tap(find.text('My Bookings'));
    await tester.pumpAndSettle();
    expect(built, 1);
    expect(find.byType(BackButton), findsNothing);
    await tester.enterText(
        find.byKey(const ValueKey('booking-search')), 'retained');
    await tester.tap(find.text('Find Coach'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Jack');
    await tester.tap(find.text('My Bookings'));
    await tester.pumpAndSettle();
    expect(built, 1);
    expect(find.text('retained'), findsOneWidget);
  });
  testWidgets(
      'filter sheet cancels changes and applies sort in the search area',
      (tester) async {
    await tester.pumpWidget(shell(BrowseCoachesScreen(
        live: true,
        liveRepository: MemberDirectoryFake(),
        isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter and sort coaches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Price: low to high'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Filter and sort coaches'));
    await tester.pumpAndSettle();
    expect(find.text('Filter and sort'), findsOneWidget);
    await tester.tap(find.text('Price: low to high'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text('Filter and sort'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
  testWidgets('compact card moves location and tags into details',
      (tester) async {
    final p = coachProfile();
    await tester.pumpWidget(shell(Scaffold(
        body: CoachCard(
            coach: publishedCoachPresentation(p),
            published: p,
            photo: const SizedBox(),
            onTap: () {}))));
    expect(find.text('Jackson'), findsOneWidget);
    expect(find.text('4.0 · 1 review'), findsOneWidget);
    expect(find.text('RM 100.00'), findsOneWidget);
    expect(find.text('Location confirmed when booking'), findsNothing);
    expect(find.text('Sports performance'), findsNothing);
    expect(find.text('Verified'), findsNothing);
  });
}
