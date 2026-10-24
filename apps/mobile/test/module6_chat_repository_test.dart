import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_mobile/features/analytics/domain/local_member_progress_repository.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_chat_repository.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  test(
      'booking follow-up context is ephemeral and a late reply cannot restore it after clear',
      () async {
    final calls = <Map<String, dynamic>>[];
    final context = {
      'coachId': 'coach',
      'localDate': '2026-10-23',
      'durationMinutes': 30,
      'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 60000
    };
    Completer<Map<String, dynamic>>? pending;
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (d) async {
          calls.add(d);
          return pending == null
              ? {
                  'responseId': 'r',
                  'text': 'Current options',
                  'bookingContext': context
                }
              : pending.future;
        });
    await repo.generateReply(text: 'Find times', history: []);
    await repo.generateReply(text: '10 am please', history: []);
    expect(calls.last['bookingContext'], context);
    pending = Completer<Map<String, dynamic>>();
    final late = repo.generateReply(text: 'More times', history: []);
    repo.clearSessionContext();
    pending.complete(
        {'responseId': 'late', 'text': 'Options', 'bookingContext': context});
    await late;
    pending = null;
    await repo.generateReply(text: 'New question', history: []);
    expect(calls.last.containsKey('bookingContext'), isFalse);
  });
  test(
      'live repository bootstrap, bounded session request, saved advice and ratings use only scoped callable',
      () async {
    final calls = <Map<String, dynamic>>[];
    final saved = <String>['Saved'];
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (data) async {
          calls.add(data);
          if (data['action'] == 'bootstrap') {
            return {
              'disclaimer': {'text': 'Admin notice', 'revision': 2},
              'acknowledged': false,
              'bookmarks': ['Saved']
            };
          }
          if (data['action'] == 'reply') {
            return {
              'responseId': 'r1',
              'text': 'Generated real response',
              'sources': ['find_equipment']
            };
          }
          if (data['action'] == 'bookmark') saved.add(data['text'] as String);
          if (data['action'] == 'removeBookmark') saved.remove(data['text']);
          return {'ok': true, 'bookmarks': List.of(saved)};
        });
    final session = await repo.initialize();
    expect(session.disclaimer.text, 'Admin notice');
    expect(session.acknowledged, false);
    expect(repo.savedAdvice, ['Saved']);
    await repo.acknowledgeDisclaimer(session.disclaimer);
    final message = await repo.generateReply(
        text: 'Equipment?',
        history: List.generate(20, (i) => ChatMessage('$i', i.isEven)));
    expect(message.id, 'r1');
    expect(message.sources, ['find_equipment']);
    expect((calls.last['history'] as List).length, 12);
    await repo.setBookmarked(message.text, true);
    expect(repo.savedAdvice, contains(message.text));
    await repo.setBookmarked(message.text, false);
    expect(repo.savedAdvice, isNot(contains(message.text)));
    await repo.rateAdvice(message, true);
    expect(
        calls.every(
            (c) => c['organizationId'] == 'org' && !c.containsKey('userId')),
        true);
  });
  test('account drift discards late reply and clears private bookmarks',
      () async {
    SessionScope? active = scope;
    final pending = Completer<Map<String, dynamic>>();
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => active,
        currentUid: () => scope.userId,
        transport: (_) => pending.future);
    final reply = repo.generateReply(text: 'Hi', history: []);
    active = null;
    pending.complete({'responseId': 'r', 'text': 'Private answer'});
    await expectLater(reply, throwsA(isA<ChatFailure>()));
    expect(repo.savedAdvice, isEmpty);
  });
  test('provider errors and empty replies do not leak internal messages',
      () async {
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (_) async => throw FirebaseFunctionsException(
            code: 'resource-exhausted', message: 'private-key-or-url'));
    await expectLater(
        repo.generateReply(text: 'Hi', history: []),
        throwsA(isA<ChatFailure>().having(
            (e) => e.message, 'message', isNot(contains('private-key')))));
  });
  test('bookmark cache follows authoritative server cap and serializes writes',
      () async {
    var running = 0;
    final server = List.generate(50, (i) => 'tip$i');
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (data) async {
          expect(running++, 0);
          await Future<void>.delayed(Duration.zero);
          server.add(data['text'] as String);
          if (server.length > 50) server.removeAt(0);
          running--;
          return {'bookmarks': List.of(server)};
        });
    await Future.wait(
        [repo.setBookmarked('new1', true), repo.setBookmarked('new2', true)]);
    expect(repo.savedAdvice, server);
    expect(repo.savedAdvice.length, 50);
    expect(repo.savedAdvice, isNot(contains('tip0')));
  });

  test(
      'progress context uses actual account-owned local measurements and labels read failure unknown',
      () async {
    final now = DateTime.now().toUtc();
    final record = LocalWorkoutProgressRecord(
        scope: scope,
        sessionId: 'real_session',
        exerciseId: 'squat',
        startedAt: now.subtract(const Duration(minutes: 2)),
        endedAt: now.subtract(const Duration(minutes: 1)),
        repetitions: 7,
        partialRepetitions: 1,
        trackedDurationMicros: 30000000,
        rejectedDurationMicros: 1000000,
        formScorePercent: 80,
        scoringVersion: 'v1',
        detectorId: 'blazepose',
        detectorVersion: 'v1',
        cameraView: 'side',
        status: LocalWorkoutRecordStatus.localOnly);
    Map<String, dynamic>? sent;
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        progressLoader: () async =>
            LocalMemberProgressSnapshot(records: [record]),
        transport: (data) async {
          sent = data;
          return {'responseId': 'reply', 'text': 'Your tracked measurements.'};
        });
    await repo.generateReply(text: 'My progress?', history: []);
    final sessions = ((sent!['deviceProgress'] as Map)['sessions'] as List);
    expect(sessions.single['repetitions'], 7);
    expect(sessions.single['formScorePercent'], 80);
    expect(sessions.single.containsKey('userId'), false);
    final unknown = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        progressLoader: () async => throw StateError('Private path'),
        transport: (data) async {
          sent = data;
          return {'responseId': 'reply', 'text': 'Local data unavailable.'};
        });
    await unknown.generateReply(text: 'My progress?', history: []);
    expect((sent!['deviceProgress'] as Map)['unavailable'], true);
  });
}
