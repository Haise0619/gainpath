import 'package:test/test.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'dart:async';
import 'dart:typed_data';

void main() {
  test('Reach & Tap save and upload retain the selected game', () async {
    final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
    final content =
        MiniGameContent.defaults('gainpath', gameId: 'reach-tap-v1');
    final url =
        'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/${Uri.encodeComponent('orgs/gainpath/miniGameMedia/reach-tap-v1/cover/admin/${'a' * 32}')}?alt=media&token=12345678-1234-1234-1234-123456789abc';
    final repo = RemoteMiniGameContentRepository(
        scope: scope,
        isCurrent: () => true,
        call: (input) async {
          expect(input['gameId'], 'reach-tap-v1');
          if (input['action'] == 'uploadMedia') {
            return {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'gameId': 'reach-tap-v1',
              'kind': 'cover',
              'url': url
            };
          }
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'confirmed': true,
            'game': {
              ...content.toJson(),
              'revision': 1,
              'updatedAtMillis': 1000
            }
          };
        });
    expect(
        await repo.upload(
            gameId: 'reach-tap-v1',
            kind: 'cover',
            uploadId: 'a' * 32,
            bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            contentType: 'image/png'),
        url);
    expect(
        (await repo.save(
                requestId: 'b' * 32, baseRevision: 0, content: content))
            .gameId,
        'reach-tap-v1');
  });
  test('legacy fallback cannot disclose a swapped game or stale session',
      () async {
    for (final stale in [false, true]) {
      var current = true, calls = 0;
      final repo = RemoteMiniGameContentReader(
          scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
          isCurrent: () => current,
          call: (input) async {
            calls++;
            if (input.containsKey('supportedGameIds')) {
              if (stale) current = false;
              throw const MiniGameContentRegistryUnsupported();
            }
            return {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'games': [
                MiniGameContent.defaults('gainpath', gameId: 'reach-tap-v1')
                    .toJson()
              ]
            };
          });
      await expectLater(
          repo.load(),
          stale
              ? throwsA(isA<MiniGameContentSessionChanged>())
              : throwsFormatException);
      expect(calls, stale ? 1 : 2);
    }
  });
  test('a later negotiated reload restores expanded registry capability',
      () async {
    var legacy = true;
    final repo = RemoteMiniGameContentReader(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => true,
        call: (input) async {
          if (legacy && input.containsKey('supportedGameIds')) {
            throw const MiniGameContentRegistryUnsupported();
          }
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'games': [
              for (final id in legacy
                  ? [MiniGameContent.supportedId]
                  : MiniGameContent.supportedIds)
                MiniGameContent.defaults('gainpath', gameId: id).toJson()
            ]
          };
        });
    await repo.load();
    expect(repo.expandedRegistryAvailable, isFalse);
    legacy = false;
    expect((await repo.load()).length, 2);
    expect(repo.expandedRegistryAvailable, isTrue);
  });
  test(
      'only explicit negotiation rejection retries legacy and reports capability',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repo = RemoteMiniGameContentReader(
        scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
        isCurrent: () => true,
        call: (input) async {
          calls.add(input);
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
    expect(calls.length, 2);
    expect(calls.last.containsKey('supportedGameIds'), isFalse);
  });
  test('network and malformed negotiated results never trigger legacy fallback',
      () async {
    for (final result in [
      null,
      <String>['move-catch-v1'],
      <String>['reach-tap-v1', 'move-catch-v1'],
      <String>['move-catch-v1', 'move-catch-v1']
    ]) {
      var calls = 0;
      final repo = RemoteMiniGameContentReader(
          scope: SessionScope(userId: 'member', organizationId: 'gainpath'),
          isCurrent: () => true,
          call: (_) async {
            calls++;
            if (result == null) throw const MiniGameContentUnavailable();
            return {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'games': [
                for (final id in result)
                  MiniGameContent.defaults('gainpath', gameId: id).toJson()
              ]
            };
          });
      await expectLater(repo.load(), throwsA(anything));
      expect(calls, 1);
    }
  });
  test('save cannot confirm another supported game with matching fields',
      () async {
    final content = MiniGameContent.defaults('gainpath');
    final repo = RemoteMiniGameContentRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'gainpath'),
        isCurrent: () => true,
        call: (_) async => {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'confirmed': true,
              'game': {
                ...content.toJson(),
                'gameId': 'reach-tap-v1',
                'revision': 1,
                'updatedAtMillis': 1000
              }
            });
    await expectLater(
        repo.save(requestId: 'a' * 32, baseRevision: 0, content: content),
        throwsA(isA<MiniGameContentConflict>()));
  });
  test('upload confirmation must match the exact uploader and upload reference',
      () async {
    final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
    final url =
        'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/${Uri.encodeComponent('orgs/gainpath/miniGameMedia/move-catch-v1/cover/other-admin/${'b' * 32}')}?alt=media&token=12345678-1234-1234-1234-123456789abc';
    final repo = RemoteMiniGameContentRepository(
        scope: scope,
        isCurrent: () => true,
        call: (_) async => {
              'schemaVersion': 1,
              'organizationId': 'gainpath',
              'gameId': MiniGameContent.supportedId,
              'kind': 'cover',
              'url': url
            });
    await expectLater(
        repo.upload(
            gameId: MiniGameContent.supportedId,
            kind: 'cover',
            uploadId: 'a' * 32,
            bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
            contentType: 'image/png'),
        throwsFormatException);
  });
  final scope = SessionScope(userId: 'admin', organizationId: 'gainpath');
  test('reader loads only supported scoped content and never writes', () async {
    final calls = <Map<String, dynamic>>[];
    final repo = RemoteMiniGameContentReader(
        scope: scope,
        isCurrent: () => true,
        call: (input) async {
          calls.add(input);
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'games': [
              for (final id in ['move-catch-v1', 'reach-tap-v1'])
                MiniGameContent.defaults('gainpath', gameId: id).toJson()
            ]
          };
        });
    expect((await repo.load()).map((game) => game.title),
        ['Move & Catch', 'Reach & Tap']);
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'action': 'list',
      'supportedGameIds': ['move-catch-v1', 'reach-tap-v1']
    });
  });
  test('account changes reject both outbound and pending response data',
      () async {
    var current = true;
    final pending = Completer<Map<String, dynamic>>();
    final repo = RemoteMiniGameContentReader(
        scope: scope, isCurrent: () => current, call: (_) => pending.future);
    final load = repo.load();
    current = false;
    pending.complete({
      'schemaVersion': 1,
      'organizationId': 'gainpath',
      'games': [MiniGameContent.defaults('gainpath').toJson()]
    });
    await expectLater(load, throwsA(isA<MiniGameContentSessionChanged>()));
    await expectLater(
        repo.load(), throwsA(isA<MiniGameContentSessionChanged>()));
  });
  test(
      'admin save sends only editable fields and verifies committed revision/content',
      () async {
    Map<String, dynamic>? sent;
    final content =
        MiniGameContent.defaults('gainpath').copyWith(title: 'Catch stars');
    final repo = RemoteMiniGameContentRepository(
        scope: scope,
        isCurrent: () => true,
        call: (input) async {
          sent = input;
          return {
            'schemaVersion': 1,
            'organizationId': 'gainpath',
            'confirmed': true,
            'game': {
              ...content.toJson(),
              'revision': 1,
              'updatedAtMillis': 1000
            }
          };
        });
    expect(
        (await repo.save(
                requestId: 'a' * 32, baseRevision: 0, content: content))
            .revision,
        1);
    expect(sent!['action'], 'save');
    expect(sent!.containsKey('points'), isFalse);
    expect(sent!.containsKey('duration'), isFalse);
  });
}
