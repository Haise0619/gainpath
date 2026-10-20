import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:gainpath_data/src/firebase_member_photo_repository.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';

const photoPath =
    'orgs/o/memberProfilePhotos/m/00000000000000000000000000000001';

class _Gateway implements MemberPhotoGateway {
  Map<String, Object?> user = {
    'organizationId': 'o',
    'displayName': 'Original',
    'goals': ['strength'],
    'notificationPreferences': {'emailAlerts': true}
  };
  Map<String, Object?> member = {
    'organizationId': 'o',
    'role': 'member',
    'status': 'active'
  };
  int writes = 0;
  @override
  Future<MemberPhotoDocuments> read() async =>
      MemberPhotoDocuments(user, member);
  @override
  Future<void> write(MemberPhotoDocuments expected, String path) async {
    if (!sameMemberDocumentValue(user, expected.user) ||
        !sameMemberDocumentValue(member, expected.member)) {
      throw const MemberPhotoException('Changed', reloadRequired: true);
    }
    user = {...user, 'memberPhotoPath': path};
    writes++;
  }
}

class _Photos implements AccountPhotoStore {
  String uploadedPath = photoPath;
  int uploads = 0;
  final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  @override
  Future<String> upload(AccountPhoto photo) async {
    uploads++;
    return uploadedPath;
  }

  @override
  Future<Uint8List> read(String path) async => bytes;
}

void main() {
  late _Gateway gateway;
  late _Photos photos;
  late FirebaseMemberPhotoRepository repo;
  var current = true;
  setUp(() {
    current = true;
    gateway = _Gateway();
    photos = _Photos();
    repo = FirebaseMemberPhotoRepository(
        scope: SessionScope(userId: 'm', organizationId: 'o'),
        gateway: gateway,
        photos: photos,
        isCurrent: () => current);
  });
  test(
      'save, reopen, replace and clear reference preserve unrelated identity fields',
      () async {
    final first = await repo.load();
    expect(first.path, isEmpty);
    final saved = await repo.save(first, photo: AccountPhoto(photos.bytes));
    expect(saved.path, photoPath);
    expect((await repo.load()).path, photoPath);
    expect(await repo.readPhoto(saved), photos.bytes);
    photos.uploadedPath =
        'orgs/o/memberProfilePhotos/m/00000000000000000000000000000002';
    final replaced = await repo.save(saved, photo: AccountPhoto(photos.bytes));
    expect(replaced.path, photos.uploadedPath);
    final cleared = await repo.save(replaced, remove: true);
    expect(cleared.path, isEmpty);
    expect(await repo.readPhoto(cleared), isNull);
    expect(gateway.user['goals'], ['strength']);
    expect(gateway.user['displayName'], 'Original');
    expect(gateway.user['notificationPreferences'], {'emailAlerts': true});
  });
  test('stale edit is rejected before upload or write', () async {
    final original = await repo.load();
    gateway.user['displayName'] = 'Changed elsewhere';
    await expectLater(repo.save(original, photo: AccountPhoto(photos.bytes)),
        throwsA(isA<MemberPhotoException>()));
    expect(photos.uploads, 0);
    expect(gateway.writes, 0);
  });
  test('foreign baseline and foreign uploaded path never reach identity write',
      () async {
    final other = FirebaseMemberPhotoRepository(
        scope: repo.scope,
        gateway: gateway,
        photos: photos,
        isCurrent: () => true);
    await expectLater(repo.save(await other.load(), remove: true),
        throwsA(isA<MemberPhotoException>()));
    final original = await repo.load();
    photos.uploadedPath =
        'orgs/o/memberProfilePhotos/other/00000000000000000000000000000001';
    await expectLater(repo.save(original, photo: AccountPhoto(photos.bytes)),
        throwsA(isA<MemberPhotoException>()));
    expect(gateway.writes, 0);
  });
  test('session loss stays invalid even when scope returns', () async {
    final original = await repo.load();
    current = false;
    await expectLater(repo.save(original, remove: true),
        throwsA(isA<MemberPhotoException>()));
    current = true;
    await expectLater(repo.load(), throwsA(isA<MemberPhotoException>()));
  });
  test(
      'wrong role, inactive member and canonical organization drift are denied',
      () async {
    for (final change in [
      {'role': 'coach'},
      {'role': 'member', 'status': 'suspended'},
      {'status': 'active', 'organizationId': 'foreign'}
    ]) {
      gateway.member.addAll(change);
      final candidate = FirebaseMemberPhotoRepository(
          scope: repo.scope,
          gateway: gateway,
          photos: photos,
          isCurrent: () => true);
      await expectLater(candidate.load(), throwsA(isA<MemberPhotoException>()));
    }
  });
}
