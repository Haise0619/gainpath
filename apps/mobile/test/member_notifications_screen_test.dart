import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession, AppRole;
import 'package:gainpath_mobile/app/notifications/member_notifications_screen.dart';
import 'package:gainpath_mobile/app/notifications/member_notification_badge.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeAnnouncementReader implements AnnouncementReader {
  _FakeAnnouncementReader(this.items, {this.initialCursor});
  final List<Announcement> items;
  final String? initialCursor;
  int loadCalls = 0;

  @override
  Future<AnnouncementPage> loadAnnouncements({String? afterId}) async {
    loadCalls++;
    if (afterId == null && initialCursor != null) {
      return AnnouncementPage([], nextCursor: initialCursor);
    }
    return AnnouncementPage(items);
  }
}

class _FakeModule9Repo implements Module9Repository {
  _FakeModule9Repo(this.notices);
  final List<MemberNotice> notices;
  final List<String> readCalls = [];
  int loadCalls = 0;

  @override
  Stream<void> watchInbox() => const Stream.empty();

  @override
  Future<NoticePage> loadInbox({String? afterId}) async {
    loadCalls++;
    return NoticePage(notices, null);
  }

  @override
  Future<void> markRead(String id) async {
    readCalls.add(id);
  }

  @override
  Future<CoachSharing> loadSharing() async => const CoachSharing(false, 0);

  @override
  Future<CoachSharing> saveSharing(bool enabled, int expectedRevision) async =>
      CoachSharing(enabled, expectedRevision + 1);

  @override
  Future<CoachReport> loadPerformance() => throw UnimplementedError();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const testSession = AuthSession(
    userId: 'm1',
    organizationId: 'gym1',
    email: 'm1@gainpath.test',
    role: AppRole.member,
    branchIds: ['main'],
  );

  testWidgets('opening a later-page announcement clears the shared unread dot',
      (tester) async {
    final now = DateTime.now();
    final reader = _FakeAnnouncementReader([
      Announcement(
        id: 'later-announcement',
        title: 'New gym hours',
        body: 'The gym opens at 7am.',
        validFrom: now.subtract(const Duration(hours: 1)),
        validTo: now.add(const Duration(days: 1)),
      ),
    ], initialCursor: 'next');
    final badge = MemberNotificationBadge(
      announcements: reader,
      isCurrent: () => true,
      loadSeen: () async => {},
      saveSeen: (_) async {},
    );
    addTearDown(badge.dispose);
    await badge.refreshAnnouncements();
    expect(badge.value, isTrue);

    await tester.pumpWidget(MaterialApp(
      home: MemberNotificationsScreen(
        session: testSession,
        announcementReader: reader,
        notificationBadge: badge,
        isCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Unread'), findsOneWidget);
    expect(badge.value, isTrue);

    await tester.tap(find.text('New gym hours'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(badge.value, isFalse);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Unread'), findsNothing);
  });

  testWidgets(
      'MemberNotificationsScreen unifies announcements, coach notices, and booking updates',
      (tester) async {
    final now = DateTime.now();
    final announcements = [
      Announcement(
        id: 'a1',
        title: 'Gym Maintenance Notice',
        body: 'Weight area closed 2pm-4pm.',
        validFrom: now.subtract(const Duration(hours: 1)),
        validTo: now.add(const Duration(days: 2)),
      ),
    ];
    final notices = [
      MemberNotice(
        id: 'n1',
        title: 'Form check feedback',
        message: 'Great calf raise form today!',
        read: true,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      MemberNotice(
        id: 'n2',
        title: 'Session Rescheduled',
        message: 'Coach moved booking to 4pm.',
        read: false,
        createdAt: now.subtract(const Duration(minutes: 30)),
        bookingId: 'b123',
      ),
    ];

    final reader = _FakeAnnouncementReader(announcements);
    final repo = _FakeModule9Repo(notices);
    var openedBookings = false;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: MemberNotificationsScreen(
        session: testSession,
        announcementReader: reader,
        module9Repository: repo,
        isCurrent: () => true,
        onOpenBookings: () => openedBookings = true,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify AppBar and Category Chips
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Announcements'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Coaching'), findsOneWidget);
    expect(find.widgetWithText(ChoiceChip, 'Bookings'), findsOneWidget);

    // Verify all 3 unified items are rendered under 'All'
    expect(find.text('Gym Maintenance Notice'), findsOneWidget);
    expect(find.text('Form check feedback'), findsOneWidget);
    expect(find.text('Session Rescheduled'), findsOneWidget);

    // Filter by Announcements
    await tester.tap(find.widgetWithText(ChoiceChip, 'Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('Gym Maintenance Notice'), findsOneWidget);
    expect(find.text('Form check feedback'), findsNothing);
    expect(find.text('Session Rescheduled'), findsNothing);

    // Tap announcement to view full details dialog
    await tester.tap(find.text('Gym Maintenance Notice'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'Weight area closed 2pm-4pm.'),
        findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    // Filter by Coaching
    await tester.tap(find.widgetWithText(ChoiceChip, 'Coaching'));
    await tester.pumpAndSettle();
    expect(find.text('Form check feedback'), findsOneWidget);
    expect(find.text('Gym Maintenance Notice'), findsNothing);
    expect(find.text('Session Rescheduled'), findsNothing);

    // Filter by Bookings
    await tester.tap(find.widgetWithText(ChoiceChip, 'Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('Session Rescheduled'), findsOneWidget);
    expect(find.text('Form check feedback'), findsNothing);

    // Opening the notice marks it as read and shows the booking details.
    await tester.tap(find.text('Session Rescheduled'));
    await tester.pumpAndSettle();
    expect(repo.readCalls, contains('n2'));
    expect(find.widgetWithText(AlertDialog, 'Coach moved booking to 4pm.'),
        findsOneWidget);
    expect(openedBookings, isFalse);

    await tester.tap(find.widgetWithText(FilledButton, 'View My Bookings'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(openedBookings, isTrue);
  });

  testWidgets('MemberNotificationsScreen shows category-specific empty states',
      (tester) async {
    final reader = _FakeAnnouncementReader([]);
    final repo = _FakeModule9Repo([]);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: MemberNotificationsScreen(
        session: testSession,
        announcementReader: reader,
        module9Repository: repo,
        isCurrent: () => true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No notifications at this time.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Announcements'));
    await tester.pumpAndSettle();
    expect(find.text('No gym announcements at this time.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Coaching'));
    await tester.pumpAndSettle();
    expect(find.text('No coaching notices yet.'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Bookings'));
    await tester.pumpAndSettle();
    expect(find.text('No booking updates yet.'), findsOneWidget);
  });

  testWidgets('Session changed blocks notification view', (tester) async {
    var isSessionCurrent = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(),
      home: MemberNotificationsScreen(
        session: testSession,
        isCurrent: () => isSessionCurrent,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Session changed. Return to sign in.'), findsOneWidget);
  });
}
