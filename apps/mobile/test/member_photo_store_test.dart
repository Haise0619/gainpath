// ignore_for_file: subtype_of_sealed_class
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_member_photo_store.dart';

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  bool get emailVerified => true;
  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async =>
      'local-test-token';
}

class _Storage extends Fake implements FirebaseStorage {
  @override
  Reference ref([String? path]) => _Ref();
}

class _Ref extends Fake implements Reference {
  @override
  String get bucket => 'private-test-bucket';
}

void main() {
  const path =
      'orgs/o/memberProfilePhotos/admin/00000000000000000000000000000001';
  final png = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
  test(
      'private photo bytes use Firebase authorization without any download token URL',
      () async {
    final store = FirebaseAccountPhotoStore(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => true,
        auth: _Auth(),
        storage: _Storage(),
        client: MockClient((request) async {
          expect(request.url.host, 'firebasestorage.googleapis.com');
          expect(request.url.pathSegments,
              ['v0', 'b', 'private-test-bucket', 'o', path]);
          expect(request.url.queryParameters, {'alt': 'media'});
          expect(request.headers['Authorization'], 'Firebase local-test-token');
          expect(request.followRedirects, false);
          return http.Response.bytes(png, 200);
        }));
    expect(await store.read(path), png);
  });
  test(
      'foreign paths make no request; failed authenticated reads return sanitized errors',
      () async {
    var requests = 0;
    final store = FirebaseAccountPhotoStore(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => true,
        auth: _Auth(),
        storage: _Storage(),
        client: MockClient((_) async {
          requests++;
          return http.Response('private-backend-details', 403);
        }));
    await expectLater(
        store.read(
            'orgs/o/memberProfilePhotos/other/00000000000000000000000000000001'),
        throwsA(isA<AccountPhotoUnavailable>()));
    expect(requests, 0);
    await expectLater(
        store.read(path), throwsA(isA<AccountPhotoUnavailable>()));
    expect(requests, 1);
  });
}
