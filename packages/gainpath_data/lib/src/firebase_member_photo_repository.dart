import 'dart:typed_data';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'member_document_snapshot.dart';

class MemberPhotoDocuments {
  MemberPhotoDocuments(Map<String, Object?> user, Map<String, Object?> member)
      : user = freezeMemberDocument(user)!,
        member = freezeMemberDocument(member)!;
  final Map<String, Object?> user, member;
}

abstract interface class MemberPhotoGateway {
  Future<MemberPhotoDocuments> read();
  Future<void> write(MemberPhotoDocuments expected, String path);
}

class FirebaseMemberPhotoRepository implements MemberPhotoRepository {
  FirebaseMemberPhotoRepository(
      {required this.scope,
      required this.gateway,
      required this.photos,
      required this.isCurrent});
  final SessionScope scope;
  final MemberPhotoGateway gateway;
  final AccountPhotoStore photos;
  final bool Function() isCurrent;
  final Object _lifetime = Object();
  bool _invalidated = false;

  void _check() {
    if (_invalidated || !isCurrent()) {
      _invalidated = true;
      throw const MemberPhotoException('Your session changed. Sign in again.',
          reloadRequired: true);
    }
  }

  bool _owned(String path) => RegExp(
          '^orgs/${RegExp.escape(scope.organizationId)}/memberProfilePhotos/${RegExp.escape(scope.userId)}/[a-f0-9]{32}\$')
      .hasMatch(path);
  void _authorize(MemberPhotoDocuments data) {
    _check();
    if (data.user['organizationId'] != scope.organizationId ||
        data.member['organizationId'] != scope.organizationId ||
        data.member['role'] != 'member' ||
        data.member['status'] != 'active') {
      _invalidated = true;
      throw const MemberPhotoException('Profile photo access is unavailable.',
          reloadRequired: true);
    }
  }

  _Baseline _baseline(MemberPhoto original) {
    _check();
    final baseline = original.editBaseline;
    if (baseline is! _Baseline ||
        !identical(baseline.lifetime, _lifetime) ||
        original.path != (baseline.documents.user['memberPhotoPath'] ?? '')) {
      throw const MemberPhotoException(
          'Reload your profile photo before saving.',
          reloadRequired: true);
    }
    return baseline;
  }

  void _unchanged(MemberPhotoDocuments current, MemberPhotoDocuments expected) {
    _authorize(current);
    if (!sameMemberDocumentValue(current.member, expected.member)) {
      _invalidated = true;
      throw const MemberPhotoException('Your account changed. Sign in again.',
          reloadRequired: true);
    }
    if (!sameMemberDocumentValue(current.user, expected.user)) {
      throw const MemberPhotoException(
          'Your account changed elsewhere. Reload before saving.',
          reloadRequired: true);
    }
  }

  @override
  Future<MemberPhoto> load() async {
    _check();
    final data = await gateway.read();
    _authorize(data);
    final path = data.user['memberPhotoPath'] ?? '';
    if (path is! String || (path.isNotEmpty && !_owned(path))) {
      throw const MemberPhotoException(
          'Your saved photo reference is unavailable.');
    }
    return MemberPhoto(path: path, editBaseline: _Baseline(_lifetime, data));
  }

  @override
  Future<MemberPhoto> save(MemberPhoto original,
      {AccountPhoto? photo, bool remove = false}) async {
    final baseline = _baseline(original);
    if ((photo == null) == !remove) {
      throw const MemberPhotoException(
          'Choose a photo or remove the current photo.');
    }
    _unchanged(await gateway.read(), baseline.documents);
    final path = remove ? '' : await photos.upload(photo!);
    _check();
    if (path.isNotEmpty && !_owned(path)) {
      throw const MemberPhotoException(
          'The uploaded photo could not be saved.');
    }
    await gateway.write(baseline.documents, path);
    _check();
    final saved = await load();
    if (saved.path != path) {
      throw const MemberPhotoException(
          'Save could not be confirmed. Reload your profile.',
          reloadRequired: true);
    }
    return saved;
  }

  @override
  Future<Uint8List?> readPhoto(MemberPhoto original) async {
    final baseline = _baseline(original);
    _unchanged(await gateway.read(), baseline.documents);
    if (original.path.isEmpty) return null;
    final bytes = await photos.read(original.path);
    _check();
    return bytes;
  }
}

class _Baseline {
  const _Baseline(this.lifetime, this.documents);
  final Object lifetime;
  final MemberPhotoDocuments documents;
}
