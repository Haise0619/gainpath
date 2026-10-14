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
  });
}
