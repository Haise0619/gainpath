import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_mini_game_content_repository.dart';

void main() {
  final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
  test('Admin transport exposes explicit legacy registry capability', () async {
    var calls = 0;
    final repo = FirebaseMiniGameContentRepository(
        scope: scope,
        isCurrent: () => true,
        verifiedSession: () => true,
        call: (input) async {
          calls++;
          if (input.containsKey('supportedGameIds')) {
            throw const MiniGameContentRegistryUnsupported();
          }
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'games': [MiniGameContent.defaults('gainpath').toJson()]
          };
        });
    expect((await repo.load()).single.gameId, MiniGameContent.supportedId);
    expect(repo.expandedRegistryAvailable, isFalse);
    expect(calls, 2);
  });
  test(
      'verified Admin transport keeps reads scoped and blocks pending session drift',
      () async {
    var current = true;
    final pending = Completer<Map<String, dynamic>>();
    final repo = FirebaseMiniGameContentRepository(
        scope: scope,
        isCurrent: () => current,
        verifiedSession: () => true,
        call: (input) {
          expect(input['organizationId'], 'gainpath');
          return pending.future;
        });
    final result = repo.load();
    current = false;
    pending.complete({
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'games': [MiniGameContent.defaults('gainpath').toJson()]
    });
    await expectLater(result, throwsA(isA<MiniGameContentSessionChanged>()));
  });
  test('unverified current session cannot send Admin content commands',
      () async {
    var calls = 0;
    final repo = FirebaseMiniGameContentRepository(
        scope: scope,
        isCurrent: () => true,
        verifiedSession: () => false,
        call: (_) async {
          calls++;
          return {};
        });
    await expectLater(
        repo.load(), throwsA(isA<MiniGameContentSessionChanged>()));
    expect(calls, 0);
  });
}
