import 'package:test/test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

void main() {
  final scope = SessionScope(userId: 'member', organizationId: 'gainpath');
  test('Reach & Tap has an isolated built-in identity and media scope', () {
    final guide = MiniGameContent.defaults('gainpath', gameId: 'reach-tap-v1');
    expect(guide.title, 'Reach & Tap');
    expect(
        MiniGameContent.fromJson(guide.toJson(), scope).gameId, 'reach-tap-v1');
    final url =
        'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/${Uri.encodeComponent('orgs/gainpath/miniGameMedia/reach-tap-v1/cover/admin/${'a' * 32}')}?alt=media&token=12345678-1234-1234-1234-123456789abc';
    expect(guide.copyWith(coverUrl: url).toFields()['coverUrl'], url);
    expect(
        () => MiniGameContent.defaults('gainpath')
            .copyWith(coverUrl: url)
            .toFields(),
        throwsFormatException);
    expect(() => MiniGameContent.defaults('gainpath', gameId: 'invented'),
        throwsArgumentError);
  });
  test(
      'supported built-in guide roundtrips without creating other game settings',
      () {
    final guide = MiniGameContent.defaults('gainpath');
    final parsed = MiniGameContent.fromJson(guide.toJson(), scope);
    expect(parsed.gameId, MiniGameContent.supportedId);
    expect(parsed.revision, 0);
    expect(parsed.instructions.length, 3);
    expect(parsed.toFields().keys.toSet(), {
      'title',
      'introduction',
      'instructions',
      'coverUrl',
      'previewVideoUrl'
    });
    expect(() => parsed.instructions.add('extra'), throwsUnsupportedError);
  });
  test('forged scope, unsupported games and gameplay settings are rejected',
      () {
    final json = MiniGameContent.defaults('gainpath').toJson();
    expect(
        () => MiniGameContent.fromJson(
            {...json, 'organizationId': 'other'}, scope),
        throwsFormatException);
    expect(
        () => MiniGameContent.fromJson({...json, 'gameId': 'new-game'}, scope),
        throwsFormatException);
    expect(() => MiniGameContent.fromJson({...json, 'points': 100}, scope),
        throwsFormatException);
    expect(
        () => MiniGameContent.defaults('gainpath')
            .copyWith(instructions: []).toFields(),
        throwsFormatException);
  });
  test('media belongs to the same organization, supported game and kind', () {
    final url =
        'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/${Uri.encodeComponent('orgs/gainpath/miniGameMedia/move-catch-v1/cover/admin/0123456789abcdef0123456789abcdef')}?alt=media&token=12345678-1234-1234-1234-123456789abc';
    expect(
        MiniGameContent.defaults('gainpath')
            .copyWith(coverUrl: url)
            .toFields()['coverUrl'],
        url);
    expect(
        () => MiniGameContent.defaults('gainpath')
            .copyWith(previewVideoUrl: url)
            .toFields(),
        throwsFormatException);
    expect(
        () => MiniGameContent.defaults('gainpath')
            .copyWith(coverUrl: 'https://example.com/cover.jpg')
            .toFields(),
        throwsFormatException);
  });
}
