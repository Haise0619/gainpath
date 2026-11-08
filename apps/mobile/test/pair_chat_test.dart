import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/pair_chat_screen.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingPage;
import 'package:gainpath_mobile/features/coaching/presentation/member/booking_schedule_screen.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'booking_history_coach_fix_test.dart' show bookingJson;

class PairChatFake implements PairConversationRepository {
  bool writable = true;
  Completer<PairChatPage>? pending;
  int loads = 0;
  final intents = <String>[];
  bool failSend = false;
  PairChatPage? latestOverride;
  final olderPages = <String, PairChatPage>{};
  final requestedCursors = <String?>[];
  PairChatPage page({bool older = false}) => PairChatPage(
      conversationId: 'pair',
      peerId: 'coach',
      peerName: 'Jackson',
      serverNowMillis: DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
      canSend: writable,
      reason: writable
          ? 'Chat about your confirmed sessions.'
          : 'This conversation is read-only. Book another session to continue chatting.',
      context: writable
          ? PairSessionContext(
              bookingId: 'booking-next',
              kind: 'next',
              startAtMillis:
                  DateTime.utc(2026, 11, 12, 2, 30).millisecondsSinceEpoch,
              endAtMillis: DateTime.utc(2026, 11, 12, 3).millisecondsSinceEpoch,
              timeZone: 'Asia/Kuala_Lumpur',
              dateLabel: '12 Nov 2026 · 10:30 GMT+8',
              durationMinutes: 30)
          : null,
      messages: [
        PairChatMessage(
            id: older ? 'old' : 'latest',
            senderRole: 'coach',
            text: older ? 'Earlier booking message' : 'Bring water',
            sentAtMillis:
                DateTime.utc(2026, 11, older ? 1 : 8).millisecondsSinceEpoch,
            sourceBookingId: older ? 'booking-old' : null)
      ],
      nextBefore: older ? null : 'older');
  @override
  Future<PairChatPage> loadConversation(
      {String? bookingId,
      String? peerId,
      String? before,
      bool markRead = false}) async {
    loads++;
    requestedCursors.add(before);
    return pending?.future ??
        (before == null
            ? latestOverride ?? page()
            : olderPages[before] ?? page(older: true));
  }

  @override
  Future<PairChatPage> sendConversation(
      {required String peerId,
      required String requestId,
      required String text}) async {
    intents.add(requestId);
    if (failSend) throw Exception('Network');
    return page();
  }

  @override
  Future<PairChatInboxPage> loadInbox({String? cursor}) async =>
      const PairChatInboxPage([
        PairChatSummary(
            peerId: 'coach',
            name: 'Jackson',
            unreadCount: 2,
            preview: 'Bring water')
      ]);
}

Widget pairApp(PairChatFake repo) => MaterialApp(
    home: PairChatScreen(
        repository: repo,
        isCurrent: () => true,
        ownRole: 'member',
        bookingId: 'b'));
void main() {
  for (final status in [
    'pending_hold',
    'expired',
    'cancelled',
    'confirmed',
    'completed'
  ]) {
    testWidgets('$status booking uses the appropriate conversation entry',
        (t) async {
      final raw = bookingJson('entry', DateTime.utc(2026, 10, 21, 2, 30),
          status: status);
      if (status == 'expired') {
        raw['resolution'] = 'hold_expired';
        raw['resolvedAtMillis'] = raw['holdExpiresAtMillis'];
      }
      final page = BookingPage.fromJson({
        'schemaVersion': 1,
        'serverNowMillis': DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
        'timeZone': 'Asia/Kuala_Lumpur',
        'firstLocalDate': '2026-10-15',
        'throughLocalDate': '2026-11-14',
        'records': [raw]
      });
      final record = page.records.single;
      await t.pumpWidget(MaterialApp(
          home: BookingScheduleScreen(
              persistedBookings: [
            persistedBookingPresentation(record, coachName: 'Jackson')
          ],
              serverNowMillis: page.serverNowMillis,
              recordFor: (_) => record,
              onMessage: (_) {})));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('View details'));
      await t.tap(find.text('View details'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('SESSION ACTIVITY'), 300);
      await t.pumpAndSettle();
      expect(
          find.text('View conversation'),
          ['confirmed', 'completed'].contains(status)
              ? findsOneWidget
              : findsNothing);
      expect(find.text('Message Jackson'), findsNothing);
    });
  }
  testWidgets(
      'disjoint refresh fills a missed-message gap before resuming old history',
      (t) async {
    final repo = PairChatFake();
    await t.pumpWidget(pairApp(repo));
    await t.pumpAndSettle();
    final original = repo.page();
    PairChatPage withMessage(String id, String text, String? cursor) =>
        PairChatPage(
            conversationId: original.conversationId,
            peerId: original.peerId,
            peerName: original.peerName,
            serverNowMillis: original.serverNowMillis,
            canSend: true,
            reason: original.reason,
            messages: [
              PairChatMessage(
                  id: id,
                  senderRole: 'coach',
                  text: text,
                  sentAtMillis:
                      original.serverNowMillis + (id == 'after' ? 2000 : 1000))
            ],
            context: original.context,
            nextBefore: cursor);
    repo.latestOverride = withMessage('after', 'Newest after offline', 'gap');
    repo.olderPages['gap'] =
        withMessage('middle', 'Previously missed interval', 'older');
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    await t.tap(find.text('Load earlier messages'));
    await t.pumpAndSettle();
    expect(repo.requestedCursors.last, 'gap');
    expect(find.text('Previously missed interval'), findsOneWidget);
    expect(find.text('Bring water'), findsOneWidget);
  });
  testWidgets(
      'shows pinned next session and retains loaded history through refresh',
      (t) async {
    final repo = PairChatFake();
    await t.pumpWidget(pairApp(repo));
    await t.pumpAndSettle();
    expect(find.text('Next session'), findsOneWidget);
    await t.tap(find.text('Load earlier messages'));
    await t.pumpAndSettle();
    expect(find.text('Earlier booking message'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
    expect(find.text('Earlier booking message'), findsOneWidget);
    expect(find.text('Bring water'), findsOneWidget);
    expect(find.text('Load earlier messages'), findsNothing);
  });
  testWidgets('background refresh does not lock input or back', (t) async {
    final repo = PairChatFake();
    await t.pumpWidget(pairApp(repo));
    await t.pumpAndSettle();
    repo.pending = Completer<PairChatPage>();
    await t.pump(const Duration(seconds: 5));
    await t.pump();
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isNot(false));
    await t.enterText(find.byType(TextField), 'My question');
    repo.pending!.complete(repo.page());
    await t.pumpAndSettle();
    expect(find.text('My question'), findsOneWidget);
  });
  testWidgets('closed relationship is visibly read-only with booking action',
      (t) async {
    final repo = PairChatFake()..writable = false;
    await t.pumpWidget(pairApp(repo));
    await t.pumpAndSettle();
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('read-only'), findsOneWidget);
  });
  testWidgets('uncertain retry retains the same request and original text',
      (t) async {
    final repo = PairChatFake()..failSend = true;
    await t.pumpWidget(pairApp(repo));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Question');
    await t.pump();
    await t.tap(find.byTooltip('Send message'));
    await t.pumpAndSettle();
    await t.tap(find.text('Retry'));
    await t.pumpAndSettle();
    expect(repo.intents.length, 2);
    expect(repo.intents[0], repo.intents[1]);
  });
}
