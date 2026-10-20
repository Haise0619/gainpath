import 'dart:typed_data';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import '../../features/identity/application/coach_account_gateway.dart';
import 'coach_avatar_image.dart';

/// Adapts the existing sample repository to the same contracts as Firebase.
/// No production identity, Storage, publication or booking writes occur here.
class MockCoachModule8Repository
    implements CoachProfileRepository, CoachAccountGateway {
  MockCoachModule8Repository(
      {required this.legacy, required this.scope, required this.isCurrent}) {
    final coach = legacy.currentCoach,
        now = DateTime.now().millisecondsSinceEpoch;
    final fields = CoachProfessionalFields(
        displayName: coach.name,
        specialty: coach.specialty,
        bio: coach.bio,
        specializationTags: coach.specializationTags,
        yearsExperience: coach.yearsExperience,
        consultationFeeMinor: (coach.fee * 100).round());
    _profile = CoachProfessionalProfile(
        id: scope.userId,
        fields: fields,
        revision: 1,
        createdAtMillis: now,
        updatedAtMillis: now);
    _publication = PublishedCoachProfile(
        id: scope.userId,
        fields: fields,
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: ['main'],
        createdAtMillis: now,
        updatedAtMillis: now,
        publishedAtMillis: now,
        certificationVerified: coach.verified,
        approvedCertificationCount: legacy.coachCertifications
            .where((c) => c.status == CertificationStatus.verified)
            .length);
    _settings = CoachAccountSettings(
        revision: 0,
        contactPhone: legacy.coachPhone,
        newBookings: true,
        cancellations: true,
        reminders: false);
    for (final entry in legacy.coachCertifications.indexed) {
      final id = (entry.$1 + 1).toRadixString(16).padLeft(32, '0'),
          cert = entry.$2;
      final state = switch (cert.status) {
        CertificationStatus.verified => 'approved',
        CertificationStatus.pendingReview => 'pending',
        CertificationStatus.rejected => 'rejected'
      };
      _certifications[id] = PrivateCoachCertification(
          id: id,
          title: cert.name,
          issuer: '—',
          storagePath: _path('coachCertifications', id),
          status: state,
          revision: 1,
          createdAtMillis: cert.uploadedAt.millisecondsSinceEpoch,
          updatedAtMillis: cert.uploadedAt.millisecondsSinceEpoch,
          reason: cert.rejectionReason);
      _history[id] = [_event(_certifications[id]!)];
    }
  }
  final CoachRepository legacy;
  @override
  final SessionScope scope;
  @override
  final bool Function() isCurrent;
  late CoachProfessionalProfile _profile;
  late PublishedCoachProfile _publication;
  late CoachAccountSettings _settings;
  final _certifications = <String, PrivateCoachCertification>{};
  final _history = <String, List<Map<String, dynamic>>>{};
  final _uploads = <String, Uint8List>{};
  final _settingsReceipts = <String, CoachAccountSettings>{};
  final _profileReceipts = <String, CoachCommandResult>{};
  @override
  String? certificationCursor;
  @override
  String get email => legacy.coachEmail;
  @override
  String? get publicAvatarUrl => legacy.currentCoach.imageUrl;
  @override
  bool get passwordManagementAvailable => false;
  @override
  CoachAccountMetrics get metrics => CoachAccountMetrics(
      branch: legacy.currentCoach.branch,
      rating: legacy.currentCoach.rating,
      sessions: legacy.currentCoach.sessionsCompleted,
      reviews: legacy.currentCoach.reviews);
  @override
  void check() {
    if (!isCurrent()) throw const CoachRepositoryException('unauthenticated');
  }

  @override
  Future<void> verifyCurrentPassword(String password) async {
    check();
    throw const CoachRepositoryException('unavailable');
  }

  @override
  Future<void> changePassword(String password) async {
    check();
    throw const CoachRepositoryException('unavailable');
  }

  @override
  Future<CoachProfessionalProfile?> loadOwn() async {
    check();
    return _profile;
  }

  @override
  Future<PublishedCoachProfile?> loadOwnPublication() async {
    check();
    return _publication;
  }

  @override
  Future<CoachCommandResult> save(
      {required int expectedRevision,
      required CoachProfilePatch patch,
      required String requestId}) async {
    check();
    if (_profileReceipts.containsKey(requestId)) {
      return _profileReceipts[requestId]!;
    }
    if (_profile.revision != expectedRevision) {
      throw const CoachRepositoryException('aborted');
    }
    final fields = CoachProfessionalFields.fromJson(
        {..._profile.fields.toJson(), ...patch.toJson()});
    _profile = CoachProfessionalProfile(
        id: scope.userId,
        fields: fields,
        revision: expectedRevision + 1,
        createdAtMillis: _profile.createdAtMillis,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch);
    legacy.currentCoach.bio = fields.bio;
    legacy.currentCoach.specializationTags = [...fields.specializationTags];
    if (fields.consultationFeeMinor != null) {
      legacy.currentCoach.fee = fields.consultationFeeMinor! / 100;
    }
    return _profileReceipts[requestId] = CoachCommandResult(
        requestId: requestId,
        coachId: scope.userId,
        revision: _profile.revision,
        outcome: 'saved');
  }

  @override
  Future<CoachAccountSettings> loadSettings() async {
    check();
    return _settings;
  }

  @override
  Future<CoachAccountSettings> saveSettings(
      CoachAccountSettings baseline,
      String phone,
      bool bookings,
      bool cancellations,
      bool reminders,
      String requestId) async {
    check();
    if (_settingsReceipts.containsKey(requestId)) {
      return _settingsReceipts[requestId]!;
    }
    if (baseline.revision != _settings.revision) {
      throw const CoachRepositoryException('aborted');
    }
    if (phone.isNotEmpty && !RegExp(r'^\+[1-9][0-9]{7,14}$').hasMatch(phone)) {
      throw const FormatException('Use an international phone number.');
    }
    _settings = CoachAccountSettings(
        revision: baseline.revision + 1,
        contactPhone: phone,
        newBookings: bookings,
        cancellations: cancellations,
        reminders: reminders);
    return _settingsReceipts[requestId] = _settings;
  }

  @override
  Future<CoachCertificationSummary> loadCertificationSummary() async {
    check();
    final count =
        _certifications.values.where((c) => c.status == 'approved').length;
    return CoachCertificationSummary(
        approved: count,
        pending:
            _certifications.values.where((c) => c.status == 'pending').length,
        verified: count > 0);
  }

  @override
  Future<List<PrivateCoachCertification>> loadCertifications(
      {String? afterId}) async {
    check();
    final ids = _certifications.keys
        .where((id) => afterId == null || id.compareTo(afterId) > 0)
        .toList()
      ..sort();
    final page = ids.take(20).toList();
    certificationCursor = ids.length > 20 ? page.last : null;
    return page.map((id) => _certifications[id]!).toList();
  }

  @override
  Future<CoachCertificationDetail> loadCertificationDetail(String id) async {
    check();
    final cert = _certifications[id];
    if (cert == null) throw const CoachRepositoryException('not-found');
    return CoachCertificationDetail(
        cert, List.unmodifiable(_history[id] ?? []));
  }

  @override
  Future<void> submitCertification(String id, String title, String issuer,
      String path, String requestId) async {
    check();
    if (_certifications.containsKey(id)) return;
    if (path != _path('coachCertifications', id) ||
        !_uploads.containsKey(path)) {
      throw const CoachRepositoryException('failed-precondition');
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final cert = PrivateCoachCertification(
        id: id,
        title: title,
        issuer: issuer,
        storagePath: path,
        status: 'pending',
        revision: 1,
        createdAtMillis: now,
        updatedAtMillis: now);
    _certifications[id] = cert;
    _history[id] = [_event(cert)];
    legacy.coachCertifications.add(CoachCertification(
        title,
        CertificationStatus.pendingReview,
        DateTime.fromMillisecondsSinceEpoch(now)));
  }

  @override
  Future<void> archive(PrivateCoachCertification cert, String requestId) async {
    check();
    final current = _certifications[cert.id];
    if (current?.status == 'archived') return;
    if (current == null || current.revision != cert.revision) {
      throw const CoachRepositoryException('aborted');
    }
    final next = PrivateCoachCertification(
        id: cert.id,
        title: cert.title,
        issuer: cert.issuer,
        storagePath: cert.storagePath,
        status: 'archived',
        revision: cert.revision + 1,
        createdAtMillis: cert.createdAtMillis,
        updatedAtMillis: DateTime.now().millisecondsSinceEpoch);
    _certifications[cert.id] = next;
    _history[cert.id]!.add(_event(next));
    final summary = await loadCertificationSummary();
    if (summary.approved == 0) {
      _publication = PublishedCoachProfile(
          id: _publication.id,
          fields: _publication.fields,
          revision: _publication.revision + 1,
          sourceRevision: _publication.sourceRevision,
          status: 'inactive',
          branchIds: _publication.branchIds,
          createdAtMillis: _publication.createdAtMillis,
          updatedAtMillis: next.updatedAtMillis,
          publishedAtMillis: _publication.publishedAtMillis);
    }
  }

  String _path(String collection, String id) =>
      'orgs/${scope.organizationId}/$collection/${scope.userId}/$id';
  @override
  Future<String> upload(
      String collection, String id, Uint8List bytes, String contentType) async {
    check();
    if (!['coachProfilePhotos', 'coachCertifications'].contains(collection) ||
        !RegExp(r'^[a-f0-9]{32}$').hasMatch(id)) {
      throw const CoachRepositoryException('invalid-argument');
    }
    if (collection == 'coachCertifications') {
      CoachCertificationFile(bytes);
    } else {
      AccountPhoto(bytes);
    }
    final path = _path(collection, id);
    if (_uploads.containsKey(path)) {
      throw const CoachRepositoryException('already-exists');
    }
    _uploads[path] = Uint8List.fromList(bytes);
    return path;
  }

  @override
  Future<Uint8List> read(String path) async {
    check();
    if (!_uploads.containsKey(path)) {
      throw const CoachRepositoryException('not-found');
    }
    return Uint8List.fromList(_uploads[path]!);
  }

  @override
  Future<Uint8List?> loadProfilePhoto(String? path) async {
    check();
    if (path == null) return null;
    if (!path.startsWith(
        'orgs/${scope.organizationId}/coachProfilePhotos/${scope.userId}/')) {
      throw const CoachRepositoryException('permission-denied');
    }
    final bytes = await decodeStaticCoachAvatar(await read(path));
    check();
    return bytes;
  }

  Map<String, dynamic> _event(PrivateCoachCertification c) => {
        'status': c.status,
        'revision': c.revision,
        'updatedAtMillis': c.updatedAtMillis,
        'reason': c.reason,
      };
}
