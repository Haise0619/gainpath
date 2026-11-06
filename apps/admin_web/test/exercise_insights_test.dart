import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/recommendation/application/exercise_insights.dart';
import 'support/exercise_insights_fixture.dart';

void main() {
  test('uses Malaysia calendar dates and caps the exclusive end at now', () {
    final q = ExerciseInsightsQuery.recent('gainpath', insightsNow, 7);
    expect(q.start, DateTime.utc(2026, 10, 25, 16));
    expect(q.end, insightsNow);
    expect(q.malaysiaLabel, '2026-10-26 – 2026-11-01');
  });
  test(
      'parses the A1-derived projection without inventing a threshold or eligibility',
      () {
    final s = ExerciseInsightsSnapshot.parse(insightsFixture(), insightsQuery);
    expect(s.groups.single.score, 65);
    expect(s.groups.single.members, 3);
    expect(s.groups.single.scoredSessions, 6);
    expect(s.groups.single.coverage, 0.8);
    expect(s.groups.single.attention, 'not_assessed');
    expect(s.mode, 'descriptive_only');
  });
  test('applies identical exercise/category filters to display and section CSV',
      () {
    final s = ExerciseInsightsSnapshot.parse(insightsFixture(), insightsQuery);
    expect(
        s.filteredContent(category: 'Upper Body').single.name, 'Wall push-up');
    expect(s.filteredGroups(category: 'Upper Body'), isEmpty);
    final csv = s.contentCsv(category: 'Upper Body', synthetic: true);
    expect(csv.expand((r) => r), contains('Wall push-up'));
    expect(csv.expand((r) => r), isNot(contains('Squat')));
    expect(
        s.gapsCsv(synthetic: true).expand((r) => r), contains('Wall push-up'));
    expect(
        s.gapsCsv(synthetic: true).expand((r) => r), isNot(contains('Squat')));
    expect(s.insightsCsv(synthetic: true).expand((r) => r), contains(65.0));
  });
  test('preserves null and deliberately unscored states in screen/CSV values',
      () {
    final raw = insightsFixture();
    final g = (raw['groups'] as List).single as Map<String, Object?>;
    (g['compatibility'] as Map)['scoreSupport'] = 'unscored';
    final m = g['metrics'] as Map;
    m['meanEstimatedFormScore'] = null;
    m['scoredSessions'] = 0;
    m['unscoredSessions'] = 6;
    m['evidenceState'] = 'unscored';
    final s = ExerciseInsightsSnapshot.parse(raw, insightsQuery);
    expect(s.groups.single.score, isNull);
    expect(
        s.insightsCsv(synthetic: true).expand((r) => r), contains('Unscored'));
  });
  test('rejects observed groups while disclosure review is pending', () {
    final raw = insightsFixture();
    raw['privacy'] = {'state': 'review_required', 'policyId': null};
    expect(() => ExerciseInsightsSnapshot.parse(raw, insightsQuery),
        throwsFormatException);
  });
  test('rejects source scope/query drift and leaked fields', () {
    final raw = insightsFixture();
    raw['organizationId'] = 'foreign';
    expect(() => ExerciseInsightsSnapshot.parse(raw, insightsQuery),
        throwsFormatException);
    final private = insightsFixture();
    ((private['groups'] as List).single as Map)['memberIds'] = [
      'private-member'
    ];
    expect(() => ExerciseInsightsSnapshot.parse(private, insightsQuery),
        throwsFormatException);
  });
  test(
      'rejects inconsistent sample counts instead of displaying reassuring metrics',
      () {
    final raw = insightsFixture();
    ((((raw['groups'] as List).single as Map)['metrics']) as Map)['members'] =
        7;
    expect(() => ExerciseInsightsSnapshot.parse(raw, insightsQuery),
        throwsFormatException);
  });
  test('rejects duplicate compatibility even if JSON property order differs',
      () {
    final raw = insightsFixture(), groups = insightsFixture()['groups'] as List;
    final copy = Map<String, Object?>.from(groups.single as Map);
    final c = Map<String, Object?>.from(copy['compatibility'] as Map);
    copy['compatibility'] =
        Map<String, Object?>.fromEntries(c.entries.toList().reversed);
    raw['groups'] = <Object?>[...(raw['groups'] as List), copy];
    expect(() => ExerciseInsightsSnapshot.parse(raw, insightsQuery),
        throwsFormatException);
  });
  test('escapes formula-leading catalog labels in all section exports', () {
    final raw = insightsFixture();
    ((raw['content'] as List).last as Map)['name'] = '=HYPERLINK("unsafe")';
    final s = ExerciseInsightsSnapshot.parse(raw, insightsQuery);
    expect(s.contentCsv(synthetic: true).expand((r) => r),
        contains('\'=HYPERLINK("unsafe")'));
  });
  test('CSV preserves exact model/schema identity for otherwise equal groups',
      () {
    final raw = insightsFixture();
    final copy = Map<String, Object?>.from(
        (insightsFixture()['groups'] as List).single as Map);
    final c = Map<String, Object?>.from(copy['compatibility'] as Map);
    c['detectorVersion'] = 'older-reviewed-model';
    copy['compatibility'] = c;
    raw['groups'] = <Object?>[...(raw['groups'] as List), copy];
    final csv = ExerciseInsightsSnapshot.parse(raw, insightsQuery)
        .insightsCsv(synthetic: true);
    expect(csv.expand((r) => r), contains('older-reviewed-model'));
    expect(
        csv.expand((r) => r), contains('mediapipe-full-e9a5c5cb-det-9ba9dd3d'));
    expect(csv.expand((r) => r), contains('Metric schema'));
  });
  test('pending disclosure cannot expose attention-derived content flags', () {
    final raw = insightsFixture();
    raw['groups'] = <Object?>[];
    raw['privacy'] = {'state': 'review_required', 'policyId': null};
    ((raw['content'] as List).last as Map)['attentionGap'] = true;
    expect(() => ExerciseInsightsSnapshot.parse(raw, insightsQuery),
        throwsFormatException);
  });
}
