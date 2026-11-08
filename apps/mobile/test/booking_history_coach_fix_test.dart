import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_booking_list_view.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/widgets/booking_card.dart';
import 'firebase_booking_repository_test.dart' show pageJson;
import 'member_coach_ux_test.dart' show coachProfile, shell;

final serverNow = DateTime.utc(2026, 11, 8, 6).millisecondsSinceEpoch;
Map<String, dynamic> bookingJson(String id, DateTime start,
    {String status = 'confirmed'}) {
  final record =
      Map<String, dynamic>.from((pageJson()['records'] as List).first as Map);
  return {
    ...record,
    'bookingId': id,
    'status': status,
    'startAtMillis': start.millisecondsSinceEpoch,
    'endAtMillis':
        start.add(const Duration(minutes: 30)).millisecondsSinceEpoch,
    'createdAtMillis':
        start.subtract(const Duration(days: 2)).millisecondsSinceEpoch,
    'holdExpiresAtMillis':
        start.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
    'localDate':
        start.add(const Duration(hours: 8)).toIso8601String().substring(0, 10),
    'startLabel': '10:30 GMT+8',
    'endLabel': '11:00 GMT+8',
    'feeMinor': 10000
  };
}

class HistoryBookings implements BookingListRepository {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  List<Map<String, dynamic>> rows = [
    bookingJson('old', DateTime.utc(2026, 10, 21, 2, 30)),
    bookingJson('future', DateTime.utc(2026, 11, 9, 2, 30))
  ];
  @override
  Future<BookingPage> load(
          {String? coachId,
          String? firstLocalDate,
          int? dayCount,
          BookingCursor? cursor}) async =>
      BookingPage.fromJson({
        ...pageJson(),
        'serverNowMillis': serverNow,
        'firstLocalDate': '2026-10-15',
        'throughLocalDate': '2026-11-14',
        'records': rows
      });
}

void main() {
  testWidgets(
      'history categories stay on one horizontally scrollable row at large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = HistoryBookings()..rows.removeLast();
    final expired = bookingJson('expired', DateTime.utc(2026, 10, 23, 2, 30),
        status: 'expired');
    expired['resolution'] = 'hold_expired';
    expired['resolvedAtMillis'] = expired['holdExpiresAtMillis'];
    repo.rows.add(expired);
    await tester.pumpWidget(shell(
        LiveBookingListView(repository: repo, isCurrent: () => true),
        scale: 2));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('booking-history-filters'));
    expect(row, findsOneWidget);
    expect(tester.widget<SingleChildScrollView>(row).scrollDirection,
        Axis.horizontal);
    final y = tester.getTopLeft(find.byKey(const ValueKey('filter_all'))).dy;
    for (final key in [
      'filter_past',
      'filter_expired',
      'filter_completed',
      'filter_cancelled'
    ]) {
      expect(tester.getTopLeft(find.byKey(ValueKey(key))).dy, y);
    }
    await tester.drag(row, const Offset(-280, 0));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('filter_expired')));
    await tester.tap(find.byKey(const ValueKey('filter_expired')));
    await tester.pumpAndSettle();
    expect(find.text('Expired'), findsWidgets);
    expect(find.text('Session ended'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'details opened during coach lookup update when the same authorized read completes',
      (tester) async {
    final pending = Completer<PublishedCoachProfile?>();
    await tester.pumpWidget(shell(LiveBookingListView(
        repository: HistoryBookings(),
        isCurrent: () => true,
        loadCoachProfile: (_) => pending.future)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    pending.complete(coachProfile(id: 'coach', name: 'Jackson'));
    await tester.pumpAndSettle();
    expect(find.text('Loading coach…'), findsNothing);
    expect(find.text('Jackson'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('server clock distinguishes ended confirmation from actual expired hold',
      () {
    final r = PersistedBookingRecord.fromJson(
        bookingJson('old', DateTime.utc(2026, 10, 21, 2, 30)));
    expect(memberBookingStatus(r, serverNow), 'Session ended');
    expect(r.rawStatus, 'confirmed');
    expect(memberBookingStatus(r, r.endAtMillis - 1), 'Confirmed');
    expect(memberBookingStatus(r, r.endAtMillis), 'Session ended');
    expect(memberBookingStatus(r, r.startAtMillis + 1), 'Confirmed');
    final pending = PersistedBookingRecord.fromJson(bookingJson(
        'hold', DateTime.utc(2026, 11, 9, 2, 30),
        status: 'pending_hold'));
    expect(memberBookingStatus(pending, pending.holdExpiresAtMillis),
        'Hold time elapsed');
    for (final status in ['completed', 'cancelled', 'refunded']) {
      final stored = PersistedBookingRecord.fromJson(bookingJson(
          status, DateTime.utc(2026, 10, 21, 2, 30),
          status: status));
      expect(memberBookingStatus(stored, serverNow),
          status[0].toUpperCase() + status.substring(1));
    }
    final expiredJson = bookingJson('expired', DateTime.utc(2026, 11, 9, 2, 30),
        status: 'expired');
    expiredJson['resolution'] = 'hold_expired';
    expiredJson['resolvedAtMillis'] = expiredJson['holdExpiresAtMillis'];
    final expired = PersistedBookingRecord.fromJson(expiredJson);
    expect(memberBookingStatus(expired, serverNow), 'Expired');
  });
  testWidgets(
      'October confirmed booking moves to Past with coach name and honest details',
      (tester) async {
    final repo = HistoryBookings();
    var loads = 0;
    await tester.pumpWidget(shell(LiveBookingListView(
        repository: repo,
        isCurrent: () => true,
        loadCoachProfile: (id) async {
          loads++;
          return coachProfile(id: id, name: 'Jackson');
        },
        coachPhotoBuilder: (_) =>
            const Icon(Icons.person, semanticLabel: 'Published coach photo'))));
    await tester.pumpAndSettle();
    expect(find.text('Jackson'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(
        tester
            .widgetList<BookingCard>(find.byType(BookingCard))
            .single
            .booking
            .id,
        'future');
    await tester.tap(find.byKey(const ValueKey('tab_history')));
    await tester.pumpAndSettle();
    expect(find.text('Session ended'), findsOneWidget);
    expect(find.text('Jackson'), findsOneWidget);
    expect(loads, 1);
    expect(
        tester.widget<BookingCard>(find.byType(BookingCard)).booking.id, 'old');
    await tester.tap(find.text('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Paid'), findsNothing);
    expect(find.text('Certified Fitness Coach'), findsNothing);
    expect(find.text('Completion has not been recorded.'), findsOneWidget);
    expect(find.text('Jackson'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'unpublished or failed coach reads stay honest without certification claims',
      (tester) async {
    for (final fail in [false, true]) {
      await tester.pumpWidget(shell(LiveBookingListView(
          key: ValueKey(fail),
          repository: HistoryBookings(),
          isCurrent: () => true,
          loadCoachProfile: (_) async {
            if (fail) throw StateError('private transport information');
            return null;
          })));
      await tester.pumpAndSettle();
      expect(
          find.text(fail
              ? 'Coach information unavailable'
              : 'Coach profile unavailable'),
          findsOneWidget);
      expect(find.text('private transport information'), findsNothing);
      expect(find.text('Certified Fitness Coach'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('late coach lookup cannot expose former-account name',
      (tester) async {
    var current = true;
    final pending = Completer<PublishedCoachProfile?>();
    await tester.pumpWidget(shell(LiveBookingListView(
        repository: HistoryBookings(),
        isCurrent: () => current,
        loadCoachProfile: (_) => pending.future)));
    await tester.pump();
    current = false;
    pending.complete(coachProfile(name: 'Private former coach'));
    await tester.pumpAndSettle();
    expect(find.text('Private former coach'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
