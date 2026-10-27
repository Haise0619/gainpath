import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_reward_media_store.dart';

void main() {
  final image = EquipmentImage(Uint8List.fromList([255, 216, 255, 0]));
  final scope = SessionScope(userId: 'admin', organizationId: 'o');
  test('uncertain upload retry keeps the same immutable upload reference',
      () async {
    final paths = <String>[];
    var fail = true;
    final store = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => true,
        upload: (path, _, __) async {
          paths.add(path);
          if (fail) {
            throw FirebaseException(
                plugin: 'cloud_functions', code: 'unavailable');
          }
          return 'https://media.example.test/cover';
        });
    await expectLater(
        store.upload(image), throwsA(isA<RewardMediaUploadFailed>()));
    fail = false;
    await store.upload(image);
    expect(paths.length, 2);
    expect(paths[0], paths[1]);
  });
  test('keeps safe Storage error codes instead of hiding the upload failure',
      () async {
    final store = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => true,
        upload: (_, __, ___) async => throw FirebaseException(
            plugin: 'firebase_storage',
            code: 'unauthorized',
            message: 'private-token-sentinel'));
    await expectLater(
        store.upload(image),
        throwsA(isA<RewardMediaUploadFailed>()
            .having((e) => e.toString(), 'safe diagnostic',
                contains('unauthorized'))
            .having((e) => e.toString(), 'no private payload',
                isNot(contains('private-token-sentinel')))));
  });
  test('uploads validated bytes to an anonymous immutable scoped reward path',
      () async {
    String? path;
    final store = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => true,
        upload: (p, bytes, type) async {
          path = p;
          expect(bytes, image.bytes);
          expect(type, 'image/jpeg');
          return 'https://media.example.test/cover';
        });
    expect(await store.upload(image), 'https://media.example.test/cover');
    expect(path, matches(RegExp(r'^orgs/o/rewardImages/admin/[a-f0-9]{32}$')));
    final first = path;
    await store.upload(image);
    expect(path, isNot(first));
  });
  test('session loss blocks upload and rejects a result after session changes',
      () async {
    var current = false;
    var calls = 0;
    final store = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => current,
        upload: (_, __, ___) async {
          calls++;
          current = false;
          return 'https://media.example.test/cover';
        });
    await expectLater(
        store.upload(image), throwsA(isA<RewardCatalogSessionChanged>()));
    expect(calls, 0);
    current = true;
    await expectLater(
        store.upload(image), throwsA(isA<RewardCatalogSessionChanged>()));
    expect(calls, 1);
  });
  test('upload failures are safe and unusable URLs cannot enter reward records',
      () async {
    final store = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => true,
        upload: (_, __, ___) async => throw StateError('private-token'));
    await expectLater(
        store.upload(image), throwsA(isA<RewardMediaUploadFailed>()));
    final invalid = FirebaseRewardMediaStore(
        scope: scope,
        isCurrent: () => true,
        upload: (_, __, ___) async => 'file:///private/photo.jpg');
    await expectLater(
        invalid.upload(image), throwsA(isA<RewardMediaUploadFailed>()));
  });
}
