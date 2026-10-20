import 'dart:math';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

class FirebaseAccountPhotoStore implements AccountPhotoStore {
  FirebaseAccountPhotoStore(
      {required this.scope,
      required this.isCurrent,
      FirebaseStorage? storage,
      FirebaseAuth? auth,
      http.Client? client})
      : _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _client = client;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final http.Client? _client;
  bool _invalidated = false;
  void _check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const MemberPhotoException('Your session changed. Sign in again.',
          reloadRequired: true);
    }
  }

  bool _owned(String path) => RegExp(
          '^orgs/${RegExp.escape(scope.organizationId)}/memberProfilePhotos/${RegExp.escape(scope.userId)}/[a-f0-9]{32}\$')
      .hasMatch(path);

  @override
  Future<String> upload(AccountPhoto photo) async {
    _check();
    final random = Random.secure();
    final id = List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    final path =
        'orgs/${scope.organizationId}/memberProfilePhotos/${scope.userId}/$id';
    try {
      await _storage.ref(path).putData(
          photo.bytes,
          SettableMetadata(
              contentType: photo.contentType,
              cacheControl: 'private, no-store'));
      _check();
      return path;
    } on MemberPhotoException {
      rethrow;
    } catch (_) {
      throw const AccountPhotoUnavailable();
    }
  }

  @override
  Future<Uint8List> read(String path) async {
    _check();
    if (!_owned(path)) throw const AccountPhotoUnavailable();
    final client = _client ?? http.Client();
    try {
      // FlutterFire Web getData uses a bearer download URL internally.
      // Authenticate this byte request directly so Storage Rules apply each time.
      final token = await _auth.currentUser!.getIdToken();
      _check();
      if (token == null) throw const AccountPhotoUnavailable();
      final uri = Uri(
          scheme: 'https',
          host: 'firebasestorage.googleapis.com',
          pathSegments: ['v0', 'b', _storage.ref(path).bucket, 'o', path],
          queryParameters: {'alt': 'media'});
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['Authorization'] = 'Firebase $token';
      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > AccountPhoto.maxBytes) {
        throw const AccountPhotoUnavailable();
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 20))) {
        if (bytes.length + chunk.length > AccountPhoto.maxBytes) {
          throw const AccountPhotoUnavailable();
        }
        bytes.add(chunk);
      }
      _check();
      return AccountPhoto(bytes.takeBytes()).bytes;
    } on MemberPhotoException {
      rethrow;
    } catch (_) {
      throw const AccountPhotoUnavailable();
    } finally {
      if (_client == null) client.close();
    }
  }
}
