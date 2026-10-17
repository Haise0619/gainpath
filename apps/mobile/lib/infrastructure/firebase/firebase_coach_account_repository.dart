import 'dart:math';
import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';

class FirebaseCoachAccountRepository {
  FirebaseCoachAccountRepository(
      {required this.scope,
      required this.isCurrent,
      FirebaseFunctions? functions,
      FirebaseAuth? auth,
      FirebaseStorage? storage})
      : _providedFunctions = functions,
        _providedAuth = auth,
        _providedStorage = storage;
  final SessionScope scope;
  final bool Function() isCurrent;
  final FirebaseFunctions? _providedFunctions;
  final FirebaseAuth? _providedAuth;
  final FirebaseStorage? _providedStorage;
  FirebaseFunctions get _functions =>
      _providedFunctions ?? FirebaseFunctions.instance;
  FirebaseAuth get _auth => _providedAuth ?? FirebaseAuth.instance;
  FirebaseStorage get _storage => _providedStorage ?? FirebaseStorage.instance;
  bool _invalidated = false;
  String get email {
    check();
    return _auth.currentUser?.email ?? '';
  }

  void check() {
    if (_invalidated ||
        !isCurrent() ||
        _auth.currentUser?.uid != scope.userId ||
        _auth.currentUser?.emailVerified != true) {
      _invalidated = true;
      throw const CoachRepositoryException('unauthenticated');
    }
  }

  static String randomId() {
    final random = Random.secure();
    return List.generate(
            16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
  }

  Future<Map<String, dynamic>> command(String name,
      [Map<String, dynamic> values = const {}]) async {
    check();
    try {
      final result = await _functions
          .httpsCallable(name)
          .call<Map<String, dynamic>>({
        'schemaVersion': 1,
        'organizationId': scope.organizationId,
        ...values
      });
      check();
      return result.data;
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code);
    }
  }

  Future<CoachAccountSettings> loadSettings() async =>
      CoachAccountSettings.fromJson(
          await command('getCoachAccountSettingsCommand'));
  Future<CoachAccountSettings> saveSettings(
      CoachAccountSettings baseline,
      String phone,
      bool bookings,
      bool cancellations,
      bool reminders,
      String requestId) async {
    if (phone.isNotEmpty && !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      throw const FormatException(
          'Use international phone format, for example +60123456789.');
    }
    return CoachAccountSettings.fromJson(
        await command('saveCoachAccountSettingsCommand', {
      'requestId': requestId,
      'expectedRevision': baseline.revision,
      'contactPhone': phone,
      'coachNotificationPreferences': {
        'newBookings': bookings,
        'cancellations': cancellations,
        'reminders': reminders
      }
    }));
  }

  String? certificationCursor;
  Future<List<PrivateCoachCertification>> loadCertifications(
      {String? afterId}) async {
    final data = await command('getCoachCertificationsCommand',
        {if (afterId != null) 'afterId': afterId});
    if (data['nextCursor'] != null && data['nextCursor'] is! String) {
      throw const FormatException('Unsupported certification cursor.');
    }
    certificationCursor = data['nextCursor'];
    if (data['schemaVersion'] != 1 || data['certifications'] is! List) {
      throw const FormatException('Unsupported certifications.');
    }
    return (data['certifications'] as List)
        .map((e) => PrivateCoachCertification.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> submitCertification(String id, String title, String issuer,
      String path, String requestId) async {
    await command('submitCoachCertificationCommand', {
      'requestId': requestId,
      'certificationId': id,
      'title': title,
      'issuer': issuer,
      'storagePath': path
    });
  }

  Future<void> archive(PrivateCoachCertification cert, String requestId) async {
    await command('archiveCoachCertificationCommand', {
      'requestId': requestId,
      'certificationId': cert.id,
      'expectedRevision': cert.revision
    });
  }

  String path(String collection, String id) =>
      'orgs/${scope.organizationId}/$collection/${scope.userId}/$id';
  Future<String> upload(
      String collection, String id, Uint8List bytes, String contentType) async {
    check();
    final target = path(collection, id);
    await _storage.ref(target).putData(
        bytes,
        SettableMetadata(
            contentType: contentType, cacheControl: 'private, no-store'));
    check();
    return target;
  }

  Future<Uint8List> read(String path) async {
    check();
    final escapedOrg = RegExp.escape(scope.organizationId),
        escapedUser = RegExp.escape(scope.userId);
    if (!RegExp(
            '^orgs/$escapedOrg/(coachCertifications|coachProfilePhotos)/$escapedUser/[a-f0-9]{32}\$')
        .hasMatch(path)) {
      throw const CoachRepositoryException('permission-denied');
    }
    final token = await _auth.currentUser!.getIdToken();
    check();
    if (token == null) throw const CoachRepositoryException('unauthenticated');
    final client = http.Client();
    try {
      final uri = Uri(
          scheme: 'https',
          host: 'firebasestorage.googleapis.com',
          pathSegments: ['v0', 'b', _storage.ref(path).bucket, 'o', path],
          queryParameters: {'alt': 'media'});
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['Authorization'] = 'Firebase $token';
      final appCheckToken = await FirebaseAppCheck.instance.getToken();
      check();
      if (appCheckToken != null) {
        request.headers['X-Firebase-AppCheck'] = appCheckToken;
      }
      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > CoachCertificationFile.maxBytes) {
        throw const CoachRepositoryException('permission-denied');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 20))) {
        if (bytes.length + chunk.length > CoachCertificationFile.maxBytes) {
          throw const FormatException('Evidence exceeds 5 MB.');
        }
        bytes.add(chunk);
      }
      check();
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }
}
