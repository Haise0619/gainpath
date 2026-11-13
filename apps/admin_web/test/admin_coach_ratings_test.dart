import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/admin_coach_ratings.dart';

PublishedCoachProfile profile(String id, {String status = 'published'}) =>
    PublishedCoachProfile(
        id: id,
        fields: CoachProfessionalFields(
            displayName: 'Jackson',
            specialty: 'Strength',
            bio: 'Reviewable bio',
            specializationTags: ['Strength'],
            yearsExperience: null),
        revision: 1,
        sourceRevision: 1,
        status: status,
        branchIds: ['main'],
        createdAtMillis: 1,
        updatedAtMillis: 1,
        publishedAtMillis: 1);

void main() {
  test('Admin hydrates Jackson from reviews and preserves inactive profiles',
      () async {
    final result = await loadAdminCoachRatings(
        [profile('jackson'), profile('inactive', status: 'inactive')],
        (ids) async {
      expect(ids, ['jackson']);
      return {
        'schemaVersion': 1,
        'records': [
          {'coachId': 'jackson', 'averageRating': 4.0, 'reviewCount': 1}
        ]
      };
    });
    expect(result.first.averageRating, 4.0);
    expect(result.first.reviewCount, 1);
    expect(result.last.status, 'inactive');
  });
  test('no reviews keeps the rating empty', () async {
    final result = await loadAdminCoachRatings(
        [profile('jackson')],
        (_) async => {
              'schemaVersion': 1,
              'records': [
                {'coachId': 'jackson', 'averageRating': null, 'reviewCount': 0}
              ]
            });
    expect(result.single.averageRating, isNull);
  });
  test('missing or invalid aggregates fail rather than fabricate ratings',
      () async {
    for (final records in [
      [],
      [
        {'coachId': 'jackson', 'averageRating': 6, 'reviewCount': 1}
      ]
    ]) {
      await expectLater(
          loadAdminCoachRatings([profile('jackson')],
              (_) async => {'schemaVersion': 1, 'records': records}),
          throwsA(isA<CoachRepositoryException>()));
    }
  });
}

