import 'dart:convert';
import '../identity.dart' show SessionScope;

const _editable = {
  'displayName',
  'specialty',
  'bio',
  'specializationTags',
  'yearsExperience',
  'consultationFeeMinor',
  'photoPath'
};
bool _id(String value) => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
int _number(Map<String, dynamic> data, String key, {int minimum = 0}) {
  final value = data[key];
  if (value is! int || value < minimum || value > 9007199254740991) {
    throw const FormatException('Unsupported Coach profile data.');
  }
  return value;
}

/// Real professional data has no required fabricated rating/fee/statistic.
/// The legacy mutable Coach/CoachRepository remain the mock contract.
class CoachProfessionalFields {
  CoachProfessionalFields(
      {required String displayName,
      required String specialty,
      required String bio,
      required List<String> specializationTags,
      required this.yearsExperience,
      this.consultationFeeMinor,
      this.photoPath})
      : displayName = displayName.trim(),
        specialty = specialty.trim(),
        bio = bio.trim(),
        specializationTags =
            List.unmodifiable(specializationTags.map((t) => t.trim())) {
    if ((consultationFeeMinor != null &&
            (consultationFeeMinor! < 0 || consultationFeeMinor! > 1000000)) ||
        (photoPath != null &&
            !RegExp(r'^orgs/[A-Za-z0-9_-]{1,128}/coachProfilePhotos/[A-Za-z0-9_-]{1,128}/[a-f0-9]{32}$')
                .hasMatch(photoPath!)) ||
        this.displayName.isEmpty ||
        this.displayName.length > 80 ||
        this.specialty.isEmpty ||
        this.specialty.length > 80 ||
        this.bio.length > 1000 ||
        this.specializationTags.isEmpty ||
        this.specializationTags.length > 8 ||
        this.specializationTags.toSet().length !=
            this.specializationTags.length ||
        this.specializationTags.any((t) => t.isEmpty || t.length > 40) ||
        (yearsExperience != null &&
            (yearsExperience! < 0 || yearsExperience! > 60))) {
      throw const FormatException(
          'Check the professional fields and supported lengths.');
    }
  }
  final String displayName, specialty, bio;
  final List<String> specializationTags;
  final int? yearsExperience;
  final int? consultationFeeMinor;
  final String? photoPath;
  factory CoachProfessionalFields.fromJson(Map<String, dynamic> data) {
    if ((data['consultationFeeMinor'] != null &&
            data['consultationFeeMinor'] is! int) ||
        (data['photoPath'] != null && data['photoPath'] is! String) ||
        data['displayName'] is! String ||
        data['specialty'] is! String ||
        data['bio'] is! String ||
        data['specializationTags'] is! List ||
        (data['specializationTags'] as List).any((v) => v is! String) ||
        !data.containsKey('yearsExperience') ||
        (data['yearsExperience'] != null && data['yearsExperience'] is! int)) {
      throw const FormatException('Unsupported Coach professional fields.');
    }
    return CoachProfessionalFields(
        displayName: data['displayName'],
        specialty: data['specialty'],
        bio: data['bio'],
        specializationTags: List<String>.from(data['specializationTags']),
        yearsExperience: data['yearsExperience'],
        consultationFeeMinor: data['consultationFeeMinor'],
        photoPath: data['photoPath']);
  }
  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'specialty': specialty,
        'bio': bio,
        'specializationTags': specializationTags,
        'yearsExperience': yearsExperience,
        'consultationFeeMinor': consultationFeeMinor,
        'photoPath': photoPath
      };
}

class CoachProfilePatch {
  CoachProfilePatch._(Map<String, dynamic> values)
      : _values = Map.unmodifiable(values);
  final Map<String, dynamic> _values;
  factory CoachProfilePatch.between(
      CoachProfessionalFields? original, CoachProfessionalFields edited) {
    final before = original?.toJson(), after = edited.toJson();
    return CoachProfilePatch._({
      for (final key in _editable)
        if (before == null || jsonEncode(before[key]) != jsonEncode(after[key]))
          key: after[key]
    });
  }
  bool get isEmpty => _values.isEmpty;
  Map<String, dynamic> toJson() => Map.of(_values);
}

class CoachProfessionalProfile {
  const CoachProfessionalProfile(
      {required this.id,
      required this.fields,
      required this.revision,
      required this.createdAtMillis,
      required this.updatedAtMillis});
  final String id;
  final CoachProfessionalFields fields;
  final int revision, createdAtMillis, updatedAtMillis;
  factory CoachProfessionalProfile.fromDocument(
      String id, Map<String, dynamic> data) {
    if (!_id(id) || data['schemaVersion'] != 1) {
      throw const FormatException('Unsupported Coach profile schema.');
    }
    return CoachProfessionalProfile(
        id: id,
        fields: CoachProfessionalFields.fromJson(data),
        revision: _number(data, 'revision', minimum: 1),
        createdAtMillis: _number(data, 'createdAtMillis'),
        updatedAtMillis: _number(data, 'updatedAtMillis'));
  }
}

class PublishedCoachProfile {
  PublishedCoachProfile(
      {required this.id,
      required this.fields,
      required this.revision,
      required this.sourceRevision,
      required this.status,
      required List<String> branchIds,
      required this.createdAtMillis,
      required this.updatedAtMillis,
      required this.publishedAtMillis,
      this.certificationVerified = false,
      this.approvedCertificationCount = 0})
      : branchIds = List.unmodifiable(branchIds);
  final String id, status;
  final bool certificationVerified;
  final int approvedCertificationCount;
  final CoachProfessionalFields fields;
  final List<String> branchIds;
  final int revision,
      sourceRevision,
      createdAtMillis,
      updatedAtMillis,
      publishedAtMillis;
  bool get isPublished => status == 'published';
  factory PublishedCoachProfile.fromDocument(
      String id, Map<String, dynamic> data) {
    const meta = {
      'schemaVersion',
      'revision',
      'sourceRevision',
      'status',
      'branchIds',
      'createdAtMillis',
      'updatedAtMillis',
      'publishedAtMillis',
      'certificationVerified',
      'approvedCertificationCount'
    };
    final branches = data['branchIds'];
    if ((data['certificationVerified'] != null &&
            data['certificationVerified'] is! bool) ||
        (data['approvedCertificationCount'] != null &&
            (data['approvedCertificationCount'] is! int ||
                data['approvedCertificationCount'] < 0)) ||
        !_id(id) ||
        data['schemaVersion'] != 1 ||
        data.keys.any((k) => !_editable.contains(k) && !meta.contains(k)) ||
        !['published', 'inactive'].contains(data['status']) ||
        branches is! List ||
        branches.isEmpty ||
        branches.length > 8 ||
        branches.any((v) => v is! String || !_id(v)) ||
        branches.toSet().length != branches.length) {
      throw const FormatException('Unsupported public Coach profile.');
    }
    return PublishedCoachProfile(
        id: id,
        fields: CoachProfessionalFields.fromJson(data),
        revision: _number(data, 'revision', minimum: 1),
        sourceRevision: _number(data, 'sourceRevision', minimum: 1),
        status: data['status'],
        branchIds: List<String>.from(branches),
        createdAtMillis: _number(data, 'createdAtMillis'),
        updatedAtMillis: _number(data, 'updatedAtMillis'),
        publishedAtMillis: _number(data, 'publishedAtMillis'),
        certificationVerified: data['certificationVerified'] == true &&
            (data['approvedCertificationCount'] ?? 0) > 0,
        approvedCertificationCount: data['approvedCertificationCount'] ?? 0);
  }
}

class CoachDirectoryPage<T> {
  CoachDirectoryPage(List<T> items, {this.nextCursor})
      : items = List.unmodifiable(items);
  final List<T> items;
  final String? nextCursor;
}

enum CoachDirectoryAction { publish, deactivate }

class CoachPublicationReview {
  CoachPublicationReview(
      {required this.coachId,
      required this.draft,
      required this.publication,
      required List<String> branchIds,
      required this.targetMembershipEligible})
      : branchIds = List.unmodifiable(branchIds);
  final String coachId;
  final CoachProfessionalProfile? draft;
  final PublishedCoachProfile? publication;
  final List<String> branchIds;
  final bool targetMembershipEligible;
  bool get canPublish =>
      draft != null && targetMembershipEligible && branchIds.isNotEmpty;
  int get publicRevision => publication?.revision ?? 0;
}

class CoachCommandResult {
  const CoachCommandResult(
      {required this.requestId,
      required this.coachId,
      required this.revision,
      required this.outcome});
  final String requestId, coachId, outcome;
  final int revision;
  factory CoachCommandResult.fromJson(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        data['requestId'] is! String ||
        data['coachId'] is! String ||
        !['saved', 'published', 'inactive'].contains(data['outcome'])) {
      throw const FormatException('Unsupported Coach command response.');
    }
    return CoachCommandResult(
        requestId: data['requestId'],
        coachId: data['coachId'],
        revision: _number(data, 'revision', minimum: 1),
        outcome: data['outcome']);
  }
}

class CoachRepositoryException implements Exception {
  const CoachRepositoryException(this.code);
  final String code;
  String get message => switch (code) {
        'aborted' => 'The profile changed. Discard and reload.',
        'permission-denied' ||
        'unauthenticated' =>
          'This Coach operation is unavailable for the current account.',
        'not-found' => 'The profile or service is unavailable.',
        'failed-precondition' => 'Profile or account eligibility needs review.',
        'invalid-argument' => 'Check the professional fields.',
        _ => 'Could not complete the Coach operation. Retry or refresh.'
      };
  @override
  String toString() => message;
}

abstract interface class CoachProfileRepository {
  SessionScope get scope;
  Future<CoachProfessionalProfile?> loadOwn();
  Future<PublishedCoachProfile?> loadOwnPublication();
  Future<CoachCommandResult> save(
      {required int expectedRevision,
      required CoachProfilePatch patch,
      required String requestId});
}

abstract interface class CoachDirectoryRepository {
  SessionScope get scope;
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage({String? afterId});
  Future<PublishedCoachProfile?> loadPublished(String coachId);
}

abstract interface class CoachProfileAdminRepository {
  SessionScope get scope;
  Future<bool> canManageDirectory();
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId});
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
      {String? afterId});
  Future<CoachPublicationReview> loadReview(String coachId);
  Future<CoachCommandResult> setStatus(
      {required CoachPublicationReview baseline,
      required CoachDirectoryAction action,
      required String requestId});
}
