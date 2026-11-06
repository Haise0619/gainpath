import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_workout_report.dart';
import 'admin_workout_reporting_test.dart' show workoutResponse;
import 'firebase_admin_reporting_test.dart' as support;

void main() {
  final scope = SessionScope(
      userId: support.reportingScope.userId,
      organizationId: support.reportingScope.organizationId,
      datasetScope: const VerifiedDatasetScope(
          datasetId: 'fyp-v1',
          seedId: 'gainpath-fyp-v1',
          revision: 1,
          rootPath: 'orgs/gainpath/cohorts/fyp-v1'));
  test('fictional report preserves aggregation and labels CSV honestly', () {
    final report = parseAdminWorkoutReport({
      ...workoutResponse(),
      'classification': 'fictional_synthetic_observation',
      'fictional': true
    }, scope, support.reportingQuery);
    expect(report.fictional, isTrue);
    expect(report.totals.sessions, 2);
    expect(report.toCsv().first.last, 'fictional_synthetic_observation');
    expect(
        report
            .toCsv()
            .expand((r) => r)
            .whereType<String>()
            .any((v) => v.contains('not physical camera')),
        isTrue);
  });
  test('canonical and fictional report classifications cannot cross sessions',
      () {
    expect(
        () => parseAdminWorkoutReport({
              ...workoutResponse(),
              'classification': 'fictional_synthetic_observation',
              'fictional': true
            }, support.reportingScope, support.reportingQuery),
        throwsFormatException);
    expect(
        () => parseAdminWorkoutReport(
            workoutResponse(), scope, support.reportingQuery),
        throwsFormatException);
  });
}
