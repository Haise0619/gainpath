import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_module9_repository.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';

void main() {
  const enabled = bool.fromEnvironment('GAINPATH_VERIFY_PRODUCTION_PROJECTION');
  test(
      'read-only existing TEST production projections parse and merge without changing original IDs',
      () {
    final file = File(
        '../../build/module13-completion-20261118/acceptance-after.private.json');
    expect(file.existsSync(), isTrue,
        reason: 'Explicit verification requires the saved read-only response.');
    final r = jsonDecode(file.readAsStringSync()) as Map;
    final page =
        parseMemberNoticePage(r['inbox']['body']['result'] as Map, 'gainpath');
    expect(page.records.length, 6);
    const id =
        'de4dd23c3cc557f5290730e811d717e2862247ea0dd252f4065877f78746bc41';
    expect(
        page.records
            .where((n) => n.recommendation?.recommendationId == id)
            .length,
        1);
    final list = (r['list']['body']['result']['recommendations'] as List)
        .map((d) => MemberRecommendationDetail.parse(
            d, 'gainpath', d['recommendationId'] as String))
        .toList();
    expect(list.length, 6);
    final groups =
        mergeAvailableMemberRecommendations(list, file.lastModifiedSync());
    final jackson =
        groups.where((g) => g.first.targetLabel == 'Jackson').toList();
    expect(jackson.length, 1);
    expect(jackson.single.length, 2);
    expect(jackson.single.first.recommendationId, id);
    expect(jackson.single.first.durationMinutes, 60);
    expect(jackson.single.first.branchLabel, 'Main Branch');
  }, skip: !enabled);
}
