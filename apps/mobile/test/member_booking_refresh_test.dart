import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart'
    show
        BookingCommunicationRepository,
        SessionConversation,
        BookingChangeSource;
import 'package:gainpath_mobile/features/coaching/presentation/shared/pair_chat_screen.dart';
import 'pair_chat_test.dart' show PairChatFake;
import 'package:gainpath_mobile/features/coaching/application/live_booking_cubit.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'booking_history_coach_fix_test.dart' show bookingJson;
import 'member_coach_ux_test.dart' show shell;

class RangeBookings implements BookingListRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  final calls = <({String? first, int? days, BookingCursor? cursor})>[];
  bool empty = false, fail = false;
  String today = '2026-11-08';
  Completer<void>? pending;
  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) async {
    calls.add((first: firstLocalDate, days: dayCount, cursor: cursor));
    await pending?.future;
    if (fail) throw const BookingException('unavailable');
    final past = firstLocalDate != null;
    return BookingPage.fromJson({
      'schemaVersion': 1,
      'serverNowMillis':
          DateTime.parse('${today}T06:00:00Z').millisecondsSinceEpoch,
      'timeZone': 'Asia/Kuala_Lumpur',
      'firstLocalDate': firstLocalDate ?? today,
      'throughLocalDate': past
          ? DateTime.parse('${firstLocalDate}T00:00:00Z')
              .add(const Duration(days: 29))
              .toIso8601String()
              .substring(0, 10)
          : dayCount == 1
              ? today
              : '2026-12-07',
      'records': empty || dayCount == 1
          ? <dynamic>[]
          : [
              bookingJson(
                  past ? 'past' : 'future',
                  past
                      ? DateTime.utc(2026, 10, 21, 2, 30)
                      : DateTime.utc(2026, 11, 12, 2, 30))
            ],
    });
  }
}

class SharedMessages extends PairChatFake
    implements BookingCommunicationRepository {
  @override
  Future<SessionConversation> load(String bookingId,
          {int? beforeSequence}) async =>
      const SessionConversation([]);
  @override
  Future<SessionConversation> send(
          String bookingId, String requestId, String text) async =>
      const SessionConversation([]);
}

class WatchedRangeBookings extends RangeBookings
    implements BookingChangeSource {
  final events = StreamController<void>.broadcast();
  @override
  Stream<void> watchBookingChanges() => events.stream;
}

class PagedRangeBookings extends RangeBookings {
  @override
  Future<BookingPage> load(
      {String? coachId,
      String? firstLocalDate,
      int? dayCount,
      BookingCursor? cursor}) async {
    final page = await super.load(
        coachId: coachId,
        firstLocalDate: firstLocalDate,
        dayCount: dayCount,
        cursor: cursor);
    if (dayCount == 1 || firstLocalDate == null) return page;
    final row = bookingJson(cursor == null ? 'past' : 'past-next',
        DateTime.utc(2026, 10, cursor == null ? 21 : 22, 2, 30));
    return BookingPage.fromJson({
      'schemaVersion': 1,
      'serverNowMillis': page.serverNowMillis,
      'timeZone': page.timeZone,
      'firstLocalDate': page.firstLocalDate,
      'throughLocalDate': page.throughLocalDate,
      'records': [row],
      if (cursor == null)
        'nextCursor': {
          'startAtMillis': row['startAtMillis'],
          'bookingId': row['bookingId']
        }
    });
  }
}

void main() {
  test('historical pagination keeps its original range across server midnight',
      () async {
    final repo = PagedRangeBookings();
    final c = BookingListCubit(repository: repo, isCurrent: () => true);
    await c.refresh();
    await c.showRecentHistory(true);
    final count = repo.calls.length;
    repo.today = '2026-11-09';
    await c.loadMore();
    expect(repo.calls.length, count + 1);
    expect(repo.calls.last.first, '2026-10-10');
    expect(repo.calls.last.cursor, isNotNull);
    expect(c.state.page!.throughLocalDate, '2026-11-08');
    expect(c.state.records.map((r) => r.bookingId), ['past', 'past-next']);
    await c.close();
  });
  test(
      'account drift during server-date lookup prevents the historical request',
      () async {
    var current = true;
    final repo = RangeBookings();
    final c = BookingListCubit(repository: repo, isCurrent: () => current);
    await c.refresh();
    repo.pending = Completer<void>();
    final request = c.showRecentHistory(true);
    await Future<void>.delayed(Duration.zero);
    current = false;
    repo.pending!.complete();
    await request;
    expect(repo.calls, hasLength(2));
    expect(c.state.records, isEmpty);
    expect(c.state.page, isNull);
    await c.close();
  });
  testWidgets('Member does not subscribe to background booking changes',
      (t) async {
    final repo = WatchedRangeBookings();
    await t.pumpWidget(
        shell(LiveBookingListView(repository: repo, isCurrent: () => true)));
    await t.pumpAndSettle();
    expect(repo.events.hasListener, false);
    repo.events.add(null);
    await t.pumpAndSettle();
    expect(repo.calls, hasLength(1));
    await t.pumpWidget(const SizedBox());
    await repo.events.close();
  });
  testWidgets(
      'Past range resets an explicit Upcoming tab and old category selection',
      (t) async {
    final repo = RangeBookings();
    await t.pumpWidget(
        shell(LiveBookingListView(repository: repo, isCurrent: () => true)));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tab_upcoming')));
    await t.pumpAndSettle();
    await t.tap(find.text('Next 30 days'));
    await t.pumpAndSettle();
    expect(repo.calls.last.first, '2026-10-10');
    expect(repo.calls.last.days, 30);
    expect(find.textContaining('21 Oct 2026'), findsOneWidget);
    expect(find.text('Session ended'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('filter_completed')));
    await t.pumpAndSettle();
    await t.tap(find.text('Past 30 days'));
    await t.pumpAndSettle();
    await t.tap(find.text('Next 30 days'));
    await t.pumpAndSettle();
    expect(find.text('Session ended'), findsOneWidget);
  });
  testWidgets(
      'Member has no periodic poll or refresh icon and empty list supports pull refresh',
      (t) async {
    final repo = RangeBookings()..empty = true;
    await t.pumpWidget(shell(LiveBookingListView(
        repository: repo, isCurrent: () => true, embedded: true)));
    await t.pumpAndSettle();
    expect(find.textContaining('Auto-syncs'), findsNothing);
    expect(find.byTooltip('Refresh bookings'), findsNothing);
    expect(find.byType(RefreshIndicator), findsOneWidget);
    await t.pump(const Duration(seconds: 61));
    await t.pumpAndSettle();
    expect(repo.calls, hasLength(1));
    await t.drag(find.byType(ListView).first, const Offset(0, 500));
    await t.pumpAndSettle();
    expect(repo.calls, hasLength(2));
  });
  test('failed date-range request preserves active range and successful rows',
      () async {
    final repo = RangeBookings();
    final controller =
        BookingListCubit(repository: repo, isCurrent: () => true);
    await controller.refresh();
    repo.fail = true;
    await controller.showRecentHistory(true);
    expect(controller.recentHistory, false);
    expect(controller.state.records.single.bookingId, 'future');
    repo.fail = false;
    await controller.refresh();
    expect(repo.calls.last.first, isNull);
    await controller.close();
  });
  testWidgets('Member booking entry opens the shared pair conversation',
      (t) async {
    final repo = RangeBookings();
    await t.pumpWidget(shell(LiveBookingListView(
        repository: repo,
        isCurrent: () => true,
        communication: SharedMessages(),
        loadCoachName: (_) async => 'Jackson')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('View details'));
    await t.tap(find.text('View details'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Message Jackson'), 250);
    await t.ensureVisible(find.text('Message Jackson'));
    await t.tap(find.text('Message Jackson'));
    await t.pumpAndSettle();
    expect(find.byType(PairChatScreen), findsOneWidget);
  });
  testWidgets(
      'pull refresh awaits the request and keeps selected historical range',
      (t) async {
    final repo = RangeBookings();
    await t.pumpWidget(
        shell(LiveBookingListView(repository: repo, isCurrent: () => true)));
    await t.pumpAndSettle();
    await t.tap(find.text('Next 30 days'));
    await t.pumpAndSettle();
    final indicator = t.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    repo.pending = Completer<void>();
    var done = false;
    final refresh = indicator.onRefresh().then((_) => done = true);
    await t.pump();
    expect(done, false);
    expect(
        repo.calls.last.first, isNull); // Awaiting the fresh server-day anchor.
    repo.pending!.complete();
    await refresh;
    await t.pumpAndSettle();
    expect(done, true);
    expect(repo.calls.last.first, '2026-10-10');
    expect(find.text('Past 30 days'), findsOneWidget);
  });
  test(
      'historical refresh includes today and advances its server-day range after midnight',
      () async {
    final repo = RangeBookings();
    final c = BookingListCubit(repository: repo, isCurrent: () => true);
    await c.refresh();
    await c.showRecentHistory(true);
    expect(repo.calls.last.first, '2026-10-10');
    repo.today = '2026-11-09';
    await c.refresh();
    expect(repo.calls.last.first, '2026-10-11');
    expect(c.state.page!.throughLocalDate, '2026-11-09');
    expect(c.recentHistory, true);
    await c.close();
  });
}
