import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_mobile/features/coaching/presentation/coach/message_inbox_screen.dart';

class _Messages implements BookingCommunicationRepository {
  final sent = <String>[];
  final requests = <String>[];
  bool failNext = false;
  SessionConversation page = const SessionConversation([]);
  Completer<SessionConversation>? pendingLoad;
  bool failLoad = false;
  @override
  Future<SessionConversation> load(String id, {int? beforeSequence}) async {
    if (failLoad) throw Exception('network');
    return pendingLoad?.future ?? Future.value(page);
  }

  @override
  Future<SessionConversation> send(
      String id, String request, String text) async {
    sent.add(text);
    requests.add(request);
    if (failNext) {
      failNext = false;
      throw Exception('network');
    }
    return SessionConversation([
      SessionMessage(
          sequence: 1, senderRole: 'coach', text: text, sentAtMillis: 1)
    ]);
  }
}

void main() {
  testWidgets(
      'failed initial history load never claims the conversation is empty',
      (tester) async {
    final repository = _Messages()..failLoad = true;
    final booking = Booking(
        id: 'b',
        coachId: 'c',
        coachName: 'Fixture Coach',
        memberName: 'Fixture Member',
        start: DateTime(2026),
        durationMin: 60,
        branch: 'main',
        status: BookingStatus.pending,
        fee: 0);
    await tester.pumpWidget(MaterialApp(
        home: CoachMessageThreadScreen(
            booking: booking,
            ownRole: 'Member',
            repository: repository,
            isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(
        find.text('Messages unavailable. Refresh to retry.'), findsOneWidget);
    expect(find.textContaining('No messages yet'), findsNothing);
  });
  testWidgets(
      'Member chat loads Coach name and never claims empty history while loading',
      (tester) async {
    final repository = _Messages()
      ..pendingLoad = Completer<SessionConversation>();
    final name = Completer<String?>();
    final booking = Booking(
        id: 'b',
        coachId: 'c',
        coachName: '-',
        memberName: 'Fixture Member',
        start: DateTime(2026),
        durationMin: 60,
        branch: 'main',
        status: BookingStatus.pending,
        fee: 0);
    await tester.pumpWidget(MaterialApp(
        home: CoachMessageThreadScreen(
            booking: booking,
            ownRole: 'Member',
            repository: repository,
            isCurrent: () => true,
            loadCoachName: () => name.future)));
    await tester.pump();
    expect(find.text('Loading messages…'), findsOneWidget);
    expect(find.textContaining('No messages yet'), findsNothing);
    name.complete('Fixture Coach');
    repository.pendingLoad!.complete(const SessionConversation([]));
    await tester.pumpAndSettle();
    expect(find.text('Fixture Coach'), findsOneWidget);
    expect(find.text('No messages yet with Fixture Coach.'), findsOneWidget);
    expect(find.textContaining('with Fixture Member'), findsNothing);
  });
  testWidgets(
      'live inbox loads genuine preview and accepts repeated whitespace in client names',
      (tester) async {
    final repository = _Messages()
      ..page = const SessionConversation([
        SessionMessage(
            sequence: 1,
            senderRole: 'member',
            text: 'What should I bring?',
            sentAtMillis: 1)
      ]);
    final booking = Booking(
        id: 'b',
        coachId: 'c',
        coachName: '-',
        memberName: 'Fixture  Client',
        start: DateTime(2026),
        durationMin: 60,
        branch: 'main',
        status: BookingStatus.pending,
        fee: 0);
    await tester.pumpWidget(MaterialApp(
        home: CoachMessageInboxScreen(
            bookings: [booking],
            repository: repository,
            isCurrent: () => true)));
    await tester.pumpAndSettle();
    expect(find.text('What should I bring?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('uncertain send retains text and retries the original intent',
      (tester) async {
    final repository = _Messages()..failNext = true;
    final booking = Booking(
        id: 'b',
        coachId: 'c',
        coachName: '-',
        memberName: '-',
        start: DateTime(2026),
        durationMin: 60,
        branch: 'main',
        status: BookingStatus.pending,
        fee: 0);
    await tester.pumpWidget(MaterialApp(
        home: CoachMessageThreadScreen(
            booking: booking, repository: repository, isCurrent: () => true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Question');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('Send was not confirmed'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Question');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(repository.requests, hasLength(2));
    expect(repository.requests[0], repository.requests[1]);
  });
  testWidgets(
      'shared thread confirms persistence and hides content after session loss',
      (tester) async {
    final repository = _Messages();
    var current = true;
    final booking = Booking(
        id: 'b',
        coachId: 'c',
        coachName: '-',
        memberName: '-',
        start: DateTime(2026),
        durationMin: 60,
        branch: 'main',
        status: BookingStatus.pending,
        fee: 0);
    Widget app() => MaterialApp(
        home: CoachMessageThreadScreen(
            booking: booking,
            repository: repository,
            isCurrent: () => current));
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Bring water');
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();
    expect(repository.sent, ['Bring water']);
    expect(find.text('Bring water'), findsOneWidget);
    current = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(find.text('Bring water'), findsNothing);
  });
}
