import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_module9_repository.dart';

Map<String, Object?> memberDetail({String state = 'available'}) => {
      'schemaVersion': 1,
      'mode': 'synthetic_local',
      'organizationId': 'gym1',
      'recommendationId': 'r1',
      'kind': 'trainer',
      'revision': 1,
      'state': state,
      'title': 'Meet your Coach',
      'summary': 'Support for your next learning step.',
      'exerciseLabel': 'Squat',
      'objective': 'Technique',
      'explanations': ['Practice with verified guidance.'],
      'target': state == 'available'
          ? {
              'kind': 'trainer',
              'coachId': 'c1',
              'branchId': 'main',
              'observedStartAtMillis': 2000,
              'observedEndAtMillis': 3000
            }
          : null,
      'targetLabel': state == 'available' ? 'Coach Alex' : null,
      'specialization': null,
      'imageUrl': null,
      'photoPath': null,
      'createdAtMillis': 1000,
      'deliveredAtMillis': 1100,
      'expiresAtMillis': 4102444800000,
      'readAtMillis': null,
      'acknowledgedAtMillis': null,
      'dismissedAtMillis': null
    };
void main() {
  final scope = SessionScope(userId: 'm1', organizationId: 'gym1');
  test('legacy Module9 and optional typed recommendation parse together', () {
    final legacy = {
      'id': 'n1',
      'title': 'Booking',
      'message': 'Confirmed',
      'read': false,
      'createdAtMillis': 1000,
      'bookingId': 'b1'
    };
    expect(parseMemberNotice(legacy, 'gym1').bookingId, 'b1');
    final notice = parseMemberNotice({
      ...legacy,
      'bookingId': null,
      'recommendation': {
        'schemaVersion': 1,
        'recommendationId': 'r1',
        'kind': 'trainer',
        'state': 'available',
        'expiresAtMillis': 2000,
        'target': memberDetail()['target']
      }
    }, 'gym1');
    expect(notice.recommendation?.kind, RecommendationKind.trainer);
  });
  test('detail rejects private extras and foreign scope', () {
    expect(
        MemberRecommendationDetail.parse(memberDetail(), 'gym1', 'r1').target,
        isA<TrainerRecommendationTarget>());
    expect(
        () => MemberRecommendationDetail.parse(
            {...memberDetail(), 'rawModel': 'private'}, 'gym1', 'r1'),
        throwsFormatException);
    expect(
        () => MemberRecommendationDetail.parse(memberDetail(), 'other', 'r1'),
        throwsFormatException);
  });
  test('normal repository unavailable without explicit transport', () async {
    final repo = UnavailableMemberRecommendationRepository(scope);
    expect(repo.enabled, false);
    await expectLater(
        repo.get('r1'), throwsA(isA<MemberRecommendationUnavailable>()));
  });
  test('RPC binds request and rejects account drift', () async {
    var current = true;
    final calls = <Map<String, Object?>>[];
    final repo = RpcMemberRecommendationRepository(
        scope: scope,
        isCurrent: () => current,
        invoke: (request) async {
          calls.add(request);
          return memberDetail();
        });
    await repo.get('r1');
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'gym1',
      'recommendationId': 'r1',
      'action': 'get',
      'commandId': null,
      'expectedRevision': null
    });
    current = false;
    await expectLater(
        repo.resolve('r1'), throwsA(isA<MemberRecommendationUnavailable>()));
    expect(calls.length, 1);
  });
  test(
      'prepared revision zero is accepted only with no delivery or protected details',
      () {
    final prepared = {
      ...memberDetail(state: 'not_delivered'),
      'revision': 0,
      'deliveredAtMillis': null,
      'exerciseLabel': null,
      'objective': null,
      'explanations': <String>[]
    };
    expect(
        MemberRecommendationDetail.parse(prepared, 'gym1', 'r1').revision, 0);
    expect(
        () => MemberRecommendationDetail.parse(
            {...prepared, 'state': 'available'}, 'gym1', 'r1'),
        throwsFormatException);
    expect(
        () => MemberRecommendationDetail.parse(
            {...prepared, 'readAtMillis': 1200}, 'gym1', 'r1'),
        throwsFormatException);
  });
}
