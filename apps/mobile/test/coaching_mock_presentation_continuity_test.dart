import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/coach_card.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_profile_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/published_coach_presentation.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_schedule_screen.dart';
import 'coach_directory_flow_test.dart' show DirectoryFake, published;
import 'live_booking_composition_test.dart' show Lists;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'published directory uses original search, filters and coach card',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: BrowseCoachesScreen(
            live: true,
            liveRepository: DirectoryFake(
                SessionScope(userId: 'member', organizationId: 'org')),
            isCurrent: () => true,
            onOpenPublished: (_) {},
            onOpenBookings: () {})));
    await tester.pumpAndSettle();
    expect(find.byType(CoachCard), findsOneWidget);
    expect(find.text('Search coaches or specialties'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Strength'), findsOneWidget);
    expect(find.text('Real contract Coach'), findsOneWidget);
    expect(find.text('RM 0/session'), findsNothing);
    await tester.enterText(find.byType(TextField), 'no matching coach');
    await tester.pump();
    expect(find.byType(CoachCard), findsNothing);
  });

  testWidgets('published profile keeps original sections and unknown metrics',
      (tester) async {
    final value = published('A real published bio');
    await tester.pumpWidget(MaterialApp(
        home: CoachProfileScreen(
            coach: publishedCoachPresentation(value),
            published: value,
            photo: const Icon(Icons.person),
            onOpenBooking: () {},
            onOpenSchedule: () {})));
    expect(find.text('Experience'), findsOneWidget);
    expect(find.text('Sessions run'), findsOneWidget);
    expect(find.text('Response time'), findsNothing);
    expect(find.text('0y'), findsNothing);
    expect(find.text('0'), findsNothing);
    await tester.scrollUntilVisible(find.text('WHAT MEMBERS SAY'), 300);
    expect(find.text('WHAT MEMBERS SAY'), findsOneWidget);
    expect(find.text('RM 0'), findsNothing);
  });

  testWidgets(
      'persisted bookings use original schedule buckets without legacy providers',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: LiveBookingListView(repository: Lists(), isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.byType(BookingScheduleScreen), findsOneWidget);
    expect(find.text('UPCOMING'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('COMPLETED'), 300);
    expect(find.text('COMPLETED'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('CANCELLED'), 300);
    expect(find.text('CANCELLED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
