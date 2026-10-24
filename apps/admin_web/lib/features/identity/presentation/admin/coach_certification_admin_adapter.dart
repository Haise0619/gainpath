import 'dart:typed_data';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/coach_direct_reads.dart';
import '../../../../infrastructure/firebase/firebase_coach_direct_reads.dart';
import '../../../../infrastructure/firebase/firebase_function_transport.dart';

/// Private, scoped review access. Document bytes never use download URLs.
class CoachCertificationAdminAdapter {
  CoachCertificationAdminAdapter(this.repository,
      {CoachDirectReads? directReads})
      : _providedDirectReads = directReads {
    if (directReads != null && directReads.scope != repository.scope) {
      throw const CoachRepositoryException('permission-denied');
    }
  }
  final CoachProfileAdminRepository repository;
  final CoachDirectReads? _providedDirectReads;
  late final CoachDirectReads? _directReads = _providedDirectReads ??
      (directCoachReadsEnabled
          ? firebaseCoachDirectReads(
              scope: repository.scope, checkSession: () {})
          : null);
  Future<void> _check() async {
    if (!await repository.canManageDirectory()) {
      throw const CoachRepositoryException('permission-denied');
    }
  }

  Future<Map<String, dynamic>> load(String coachId,
      {String? afterId, String? certificationId}) async {
    await _check();
    try {
      final direct = _directReads;
      if (direct != null) {
        final result = await direct.loadCertifications(
            coachId: coachId,
            afterId: afterId,
            certificationId: certificationId);
        await _check();
        return result;
      }
      final result =
          await firebaseCallable('getCoachCertificationsCommand').call({
        'schemaVersion': 1,
        'organizationId': repository.scope.organizationId,
        'coachId': coachId,
        if (afterId != null) 'afterId': afterId,
        if (certificationId != null) 'certificationId': certificationId,
      });
      await _check();
      return Map<String, dynamic>.from(result.data as Map);
    } on FirebaseFunctionsException catch (e) {
      throw CoachRepositoryException(e.code, e.message);
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code, e.message);
    }
  }

  Future<Uint8List> bytes(
      String coachId, Map<String, dynamic> certification) async {
    await _check();
    final path = certification['storagePath'];
    if (!isPrivateCertificationPath(
        path, repository.scope.organizationId, coachId)) {
      throw const CoachRepositoryException('invalid-argument');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user?.uid != repository.scope.userId) {
      throw const CoachRepositoryException('permission-denied');
    }
    final token = await user!.getIdToken();
    await _check();
    if (token == null) {
      throw const CoachRepositoryException('permission-denied');
    }
    final client = http.Client();
    try {
      final uri = Uri(
          scheme: 'https',
          host: 'firebasestorage.googleapis.com',
          pathSegments: [
            'v0',
            'b',
            FirebaseStorage.instance.ref(path as String).bucket,
            'o',
            path
          ],
          queryParameters: {
            'alt': 'media'
          });
      final request = http.Request('GET', uri)..followRedirects = false;
      request.headers['Authorization'] = 'Firebase $token';
      String? appCheck;
      try {
        appCheck = await FirebaseAppCheck.instance.getToken();
      } catch (_) {}
      if (appCheck != null) request.headers['X-Firebase-AppCheck'] = appCheck;
      final response =
          await client.send(request).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > 5 * 1024 * 1024) {
        throw const CoachRepositoryException('unavailable');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk
          in response.stream.timeout(const Duration(seconds: 20))) {
        if (bytes.length + chunk.length > 5 * 1024 * 1024) {
          throw const CoachRepositoryException('resource-exhausted');
        }
        bytes.add(chunk);
      }
      await _check();
      return bytes.takeBytes();
    } finally {
      client.close();
    }
  }

  Future<void> review(
      {required String coachId,
      required Map<String, dynamic> certification,
      required String decision,
      required String reason,
      required String requestId}) async {
    await _check();
    if (decision == 'reject' && reason.trim().isEmpty) {
      throw const CoachRepositoryException('invalid-argument',
          'A reason is required to reject a certification.');
    }
    try {
      await firebaseCallable('reviewCoachCertificationCommand').call({
        'schemaVersion': 1,
        'organizationId': repository.scope.organizationId,
        'coachId': coachId,
        'certificationId': certification['id'],
        'expectedRevision': certification['revision'],
        'decision': decision,
        'requestId': requestId,
        if (reason.trim().isNotEmpty) 'reason': reason.trim(),
      });
      await _check();
    } on FirebaseFunctionsException catch (e) {
      throw CoachRepositoryException(e.code, e.message);
    } on FirebaseException catch (e) {
      throw CoachRepositoryException(e.code, e.message);
    }
  }
}

bool isPrivateCertificationPath(
        Object? path, String organizationId, String coachId) =>
    path is String &&
    RegExp('^orgs/${RegExp.escape(organizationId)}/coachCertifications/${RegExp.escape(coachId)}/[a-f0-9]{32}\$')
        .hasMatch(path);
