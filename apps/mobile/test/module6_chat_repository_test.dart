import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_chat_repository.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'org');
  test('verified tomorrow slots take priority over an eligible directory',
      () async {
    final start = ((DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 1))
                    .millisecondsSinceEpoch ~/
                1800000) +
            1) *
        1800000;
    final localDate = DateTime.fromMillisecondsSinceEpoch(start, isUtc: true)
        .add(const Duration(hours: 8))
        .toIso8601String()
        .substring(0, 10);
    final availability = <String, dynamic>{
      'schemaVersion': 1,
      'localDate': localDate,
      'timeZone': 'Asia/Kuala_Lumpur',
      'durationMinutes': 60,
      'expiresAtMillis': DateTime.now().millisecondsSinceEpoch + 60000,
      'truncated': false,
      'items': [
        {
          'coachId': 'coach-1',
          'name': 'Coach Jo',
          'branchId': 'branch-1',
          'branchName': 'Main',
          'startAtMillis': start,
          'endAtMillis': start + 3600000,
          'startLabel': '10:00',
          'endLabel': '11:00',
          'amountMinor': 12500,
          'currency': 'MYR'
        }
      ]
    };
    final repository = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (_) async => {
              'text': 'Here are the available times for tomorrow.',
              'responseId': 'slot-r',
              'coachAvailability': availability,
              'coachSuggestions': []
            });
    final reply = await repository
        .generateReply(text: 'available coach in tomorrow', history: []);
    expect(reply.attachment, isA<CoachAvailabilityAttachment>());
    expect(repository.lastMetrics['providerRequests'], isNull);
    availability['durationMinutes'] = 30;
    await expectLater(
        repository.generateReply(text: 'tomorrow coaching', history: []),
        throwsA(isA<FormatException>()));
  });
  test(
      'trusted coach suggestions become typed cards and reject malformed prices',
      () async {
    Map<String, dynamic> row = {
      'coachId': 'coach-1',
      'name': 'Coach Jo',
      'branchName': 'Main',
      'amountMinor': 12500,
      'durationMinutes': 60,
      'currency': 'MYR'
    };
    final repository = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (_) async => {
              'text': 'Choose a coach for your next session.',
              'responseId': 'r',
              'coachSuggestions': [row]
            });
    final reply =
        await repository.generateReply(text: 'Find a coach', history: []);
    expect(
        (reply.attachment as CoachDirectoryAttachment)
            .coaches
            .single
            .amountMinor,
        12500);
    row = {...row, 'amountMinor': -1};
    await expectLater(
        repository.generateReply(text: 'Find a coach', history: []),
        throwsA(isA<FormatException>()));
  });
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
    expect(calls.last.containsKey('history'), isFalse);
    expect(calls.last.containsKey('deviceProgress'), isFalse);
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

  test('generic replies never load or transmit personal progress', () async {
    var progressReads = 0;
    Map<String, dynamic>? sent;
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        progressLoader: () async {
          progressReads++;
          throw StateError('must not read');
        },
        transport: (data) async {
          sent = data;
          return {'responseId': 'r', 'text': 'Warm up gently.'};
        });
    await repo.generateReply(
        text: 'Explain warming up',
        history: [const ChatMessage('PRIVATE', true)]);
    expect(progressReads, 0);
    expect(sent!.containsKey('deviceProgress'), false);
    expect(sent!.containsKey('history'), false);
  });
  test('deterministic authorized facts make zero provider calls', () async {
    var calls = 0;
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        contextualReply: (text) async => const ChatMessage(
            'No saved workout records.', false,
            attachment: FitnessFactsAttachment(
                title: 'Your workout', subtitle: 'Device records', facts: [])),
        transport: (data) async {
          calls++;
          throw StateError('must not send');
        });
    final reply = await repo.generateReply(text: 'Last workout', history: []);
    expect(reply.id, startsWith('local-'));
    expect(calls, 0);
    expect(repo.lastMetrics['providerRequests'], 0);
  });
  test('history is bounded only for explicitly reviewed private mode',
      () async {
    Map<String, dynamic>? sent;
    final repo = FirebaseChatRepository(
        scope: scope,
        activeScope: () => scope,
        currentUid: () => scope.userId,
        transport: (data) async {
          sent = data;
          return data['action'] == 'bootstrap'
              ? {
                  'contextMode': 'private-approved',
                  'disclaimer': {'text': 'Notice', 'revision': 1},
                  'bookmarks': [],
                  'acknowledged': true
                }
              : {'responseId': 'r', 'text': 'Advice'};
        });
    await repo.initialize();
    await repo.generateReply(
        text: 'Advice',
        history: List.generate(20, (i) => ChatMessage('$i', i.isEven)));
    expect((sent!['history'] as List).length, 12);
  });
}
