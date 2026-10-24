import 'dart:async';
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
      this.approvedCertificationCount = 0,
      this.averageRating, this.reviewCount = 0})
      : branchIds = List.unmodifiable(branchIds);
  final double? averageRating;
  final int reviewCount;
  PublishedCoachProfile withRatings(double? average, int count) => PublishedCoachProfile(
    id: id, fields: fields, revision: revision, sourceRevision: sourceRevision, status: status,
    branchIds: branchIds, createdAtMillis: createdAtMillis, updatedAtMillis: updatedAtMillis,
    publishedAtMillis: publishedAtMillis, certificationVerified: certificationVerified,
    approvedCertificationCount: approvedCertificationCount, averageRating: average, reviewCount: count);
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
      required this.targetMembershipEligible,
      this.certificationVerified = false,
      this.approvedCertificationCount = 0})
      : branchIds = List.unmodifiable(branchIds);
  final String coachId;
  final CoachProfessionalProfile? draft;
  final PublishedCoachProfile? publication;
  final List<String> branchIds;
  final bool targetMembershipEligible;
  final bool certificationVerified;
  final int approvedCertificationCount;
  bool get canPublish =>
      draft != null &&
      targetMembershipEligible &&
      branchIds.isNotEmpty &&
      certificationVerified &&
      approvedCertificationCount > 0;

  bool get hasPublishableChanges {
    final pub = publication;
    if (pub == null || !pub.isPublished) return true;
    if (draft != null && draft!.revision > pub.sourceRevision) return true;
    if (certificationVerified != pub.certificationVerified) return true;
    if (approvedCertificationCount != pub.approvedCertificationCount) return true;
    if (branchIds.length != pub.branchIds.length ||
        !branchIds.toSet().containsAll(pub.branchIds)) {
      return true;
    }
    return false;
  }

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

const safeCoachAllowlistedMessages = <String>{
  'An approved certification is required for publication.',
  'Coach assignments changed. Reload the review.',
  'Coach professional profile not found.',
  'Public Coach profile not found.',
  'Certification changed. Reload before continuing.',
  'Certification unavailable.',
  'Archived certification cannot change. Upload a new certification.',
  'Certification limit reached.',
  'Certification summary requires review.',
  'Certification revision limit reached. Upload a new certification.',
  'Invalid certification ID.',
  'Invalid decision.',
  'Invalid certification cursor.',
  'A reason is required to reject a certification.',
  'A reason is required to reject or revoke a certification.',
  'A reason is required to revoke an approval.',
  'Enter a reason before rejecting.',
  'The profile changed. Discard and reload.',
  'This Coach operation is unavailable for the current account.',
  'The profile or service is unavailable.',
  'Profile or account eligibility needs review.',
  'Check the professional fields.',
};

bool isSafeCoachMessage(String msg) {
  final trimmed = msg.trim();
  if (trimmed.isEmpty) return false;
  if (safeCoachAllowlistedMessages.contains(trimmed)) return true;
  if (trimmed.length > 200) return false;
  final lower = trimmed.toLowerCase();
  if (lower.contains('token') ||
      lower.contains('bearer') ||
      lower.contains('auth') ||
      lower.contains('uid') ||
      lower.contains('exception') ||
      lower.contains('error:') ||
      lower.contains('stack') ||
      lower.contains('http') ||
      lower.contains('/') ||
      lower.contains(r'\') ||
      lower.contains('projects/') ||
      lower.contains('databases/')) {
    return false;
  }
  return true;
}

String safeCoachErrorMessage(Object? error,
    {String fallback =
        'Could not complete the Coach operation. Retry or refresh.'}) {
  if (error == null) return fallback;
  if (error is CoachRepositoryException) {
    return error.message;
  }
  if (error is FormatException) {
    return 'This Admin build cannot read the Coach record format. Open the main Admin at http://localhost:7359/ and reload. No records were changed.';
  }
  if (error is TimeoutException) {
    return 'Coach operation timed out. Check your connection and retry.';
  }
  return fallback;
}

class CoachRepositoryException implements Exception {
  const CoachRepositoryException(this.code, [this.customMessage]);
  final String code;
  final String? customMessage;
  String get message {
    if (customMessage != null && isSafeCoachMessage(customMessage!)) {
      return customMessage!.trim();
    }
    return switch (code) {
      'aborted' => 'The profile changed. Discard and reload.',
      'permission-denied' ||
      'unauthenticated' =>
        'This Coach operation is unavailable for the current account.',
      'not-found' => 'The profile or service is unavailable.',
      'failed-precondition' => 'Profile or account eligibility needs review.',
      'invalid-argument' => 'Check the professional fields.',
      'resource-exhausted' => 'The limit for this operation was reached.',
      'unavailable' =>
        'Service temporarily unavailable. Check connection and retry.',
      _ => 'Could not complete the Coach operation. Retry or refresh.'
    };
  }
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
