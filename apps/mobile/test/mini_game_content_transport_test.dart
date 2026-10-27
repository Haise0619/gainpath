import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_mini_game_content_reader.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test(
      'Member transport reads scoped supported content without write capabilities',
      () async {
    final repo = FirebaseMiniGameContentReader(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => scope.userId,
        call: (input) async {
          expect(input['action'], 'list');
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'games': [MiniGameContent.defaults('gainpath').toJson()]
          };
        });
    expect((await repo.load()).single.gameId, MiniGameContent.supportedId);
    expect(repo, isNot(isA<MiniGameContentRepository>()));
  });
  test('Member transport rejects a different Firebase subject', () async {
    var calls = 0;
    final repo = FirebaseMiniGameContentReader(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => 'other',
        call: (_) async {
          calls++;
          return {};
        });
    await expectLater(
        repo.load(), throwsA(isA<MiniGameContentSessionChanged>()));
    expect(calls, 0);
  });
  test(
      'an injected signed-out subject never falls back to another Firebase session',
      () async {
    final repo = FirebaseMiniGameContentReader(
        scope: scope,
        isCurrent: () => true,
        currentUid: () => null,
        call: (_) async => throw StateError('must not call'));
    await expectLater(
        repo.load(), throwsA(isA<MiniGameContentSessionChanged>()));
  });
}
