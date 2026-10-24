import 'package:test/test.dart';
import 'package:gainpath_domain/identity.dart';

CoachProfessionalFields fields({int? years, String bio = 'Bio'}) =>
    CoachProfessionalFields(
        displayName: 'Coach',
        specialty: 'Strength',
        bio: bio,
        specializationTags: ['Strength'],
        yearsExperience: years);
void main() {
  test(
      'presence-aware patch can clear experience without changing unrelated fields',
      () {
    final patch = CoachProfilePatch.between(fields(years: 3), fields());
    expect(patch.toJson(), {'yearsExperience': null});
    expect(CoachProfilePatch.between(fields(), fields()).isEmpty, isTrue);
    expect(
        () => fields().specializationTags.add('Other'), throwsUnsupportedError);
  });
  test('public parse rejects private fields and unsupported revisions', () {
    final data = {
      ...fields().toJson(),
      'schemaVersion': 1,
      'revision': 1,
      'sourceRevision': 1,
      'status': 'published',
      'branchIds': ['main'],
      'createdAtMillis': 1,
      'updatedAtMillis': 2,
      'publishedAtMillis': 2
    };
    expect(
        PublishedCoachProfile.fromDocument('coach', data)
            .fields
            .yearsExperience,
        isNull);
    expect(
        () => PublishedCoachProfile.fromDocument(
            'coach', {...data, 'email': 'private'}),
        throwsFormatException);
    expect(
        () => PublishedCoachProfile.fromDocument(
            'coach', {...data, 'revision': 0}),
        throwsFormatException);
  });
  test(
      'validation is bounded and publication review supports missing-draft withdrawal',
      () {
    expect(
        () => CoachProfessionalFields(
            displayName: '',
            specialty: 'S',
            bio: '',
            specializationTags: ['S'],
            yearsExperience: null),
        throwsFormatException);
    expect(
        () => CoachProfessionalFields(
            displayName: 'C',
            specialty: 'S',
            bio: '',
            specializationTags: ['S'],
            yearsExperience: -1),
        throwsFormatException);
    final review = CoachPublicationReview(
        coachId: 'coach',
        draft: null,
        publication: null,
        branchIds: [],
        targetMembershipEligible: false);
    expect(review.canPublish, isFalse);
    expect(review.publicRevision, 0);

    final eligibleWithoutCert = CoachPublicationReview(
        coachId: 'coach',
        draft: CoachProfessionalProfile(
            id: 'coach',
            fields: fields(),
            revision: 1,
            createdAtMillis: 1,
            updatedAtMillis: 2),
        publication: null,
        branchIds: ['b1'],
        targetMembershipEligible: true,
        certificationVerified: false,
        approvedCertificationCount: 0);
    expect(eligibleWithoutCert.canPublish, isFalse);

    final eligibleWithCert = CoachPublicationReview(
        coachId: 'coach',
        draft: CoachProfessionalProfile(
            id: 'coach',
            fields: fields(),
            revision: 1,
            createdAtMillis: 1,
            updatedAtMillis: 2),
        publication: null,
        branchIds: ['b1'],
        targetMembershipEligible: true,
        certificationVerified: true,
        approvedCertificationCount: 1);
    expect(eligibleWithCert.canPublish, isTrue);
    expect(eligibleWithCert.hasPublishableChanges, isTrue);

    final publishedUpToDate = CoachPublicationReview(
        coachId: 'coach',
        draft: CoachProfessionalProfile(
            id: 'coach',
            fields: fields(),
            revision: 2,
            createdAtMillis: 1,
            updatedAtMillis: 2),
        publication: PublishedCoachProfile(
            id: 'coach',
            fields: fields(),
            revision: 3,
            sourceRevision: 2,
            status: 'published',
            branchIds: const ['b1'],
            createdAtMillis: 1,
            updatedAtMillis: 2,
            publishedAtMillis: 2,
            certificationVerified: true,
            approvedCertificationCount: 1),
        branchIds: ['b1'],
        targetMembershipEligible: true,
        certificationVerified: true,
        approvedCertificationCount: 1);
    expect(publishedUpToDate.canPublish, isTrue);
    expect(publishedUpToDate.hasPublishableChanges, isFalse);

    final publishedWithNewDraft = CoachPublicationReview(
        coachId: 'coach',
        draft: CoachProfessionalProfile(
            id: 'coach',
            fields: fields(),
            revision: 3,
            createdAtMillis: 1,
            updatedAtMillis: 3),
        publication: publishedUpToDate.publication,
        branchIds: ['b1'],
        targetMembershipEligible: true,
        certificationVerified: true,
        approvedCertificationCount: 1);
    expect(publishedWithNewDraft.hasPublishableChanges, isTrue);

    final publishedInactive = CoachPublicationReview(
        coachId: 'coach',
        draft: publishedUpToDate.draft,
        publication: PublishedCoachProfile(
            id: 'coach',
            fields: fields(),
            revision: 3,
            sourceRevision: 2,
            status: 'inactive',
            branchIds: const ['b1'],
            createdAtMillis: 1,
            updatedAtMillis: 2,
            publishedAtMillis: 2,
            certificationVerified: true,
            approvedCertificationCount: 1),
        branchIds: ['b1'],
        targetMembershipEligible: true,
        certificationVerified: true,
        approvedCertificationCount: 1);
    expect(publishedInactive.hasPublishableChanges, isTrue);

    expect(
        const CoachRepositoryException('failed-precondition',
                'An approved certification is required for publication.')
            .message,
        'An approved certification is required for publication.');
    expect(
        const CoachRepositoryException('failed-precondition').message,
        'Profile or account eligibility needs review.');
    // Unsafe or raw exception messages with paths or tokens are safely discarded
    expect(
        const CoachRepositoryException('failed-precondition',
                'Error: at orgs/o1/coachProfiles/c1 with token secret_xyz')
            .message,
        'Profile or account eligibility needs review.');
    expect(
        safeCoachErrorMessage(const CoachRepositoryException('not-found')),
        'The profile or service is unavailable.');
    expect(
        safeCoachErrorMessage(Exception('internal server crash stack trace')),
        'Could not complete the Coach operation. Retry or refresh.');
  });
}
