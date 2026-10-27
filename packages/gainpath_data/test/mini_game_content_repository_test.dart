import 'package:test/test.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'dart:async';
import 'dart:typed_data';

void main() {
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
            'games': [MiniGameContent.defaults('gainpath').toJson()]
          };
        });
    expect((await repo.load()).single.title, 'Move & Catch');
    expect(calls.single,
        {'schemaVersion': 1, 'organizationId': 'gainpath', 'action': 'list'});
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
