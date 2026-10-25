import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/navigation/membership_access_gate.dart';

class _Access implements MembershipAccessRepository {
  String outcome = 'allowed';
  int reads = 0;
  @override
  bool current = true;
  @override
  Future<MembershipAccessDecision> check(
      MembershipAccessFeature feature, String resourceId) async {
    reads++;
    return MembershipAccessDecision.fromJson({
      'schemaVersion': 1,
      'policyVersion': 'gainpath-membership-access-v1',
      'organizationId': 'o',
      'memberId': 'm',
      'resolvedAtMillis': 1800000000000,
      'feature': feature.name,
      'resourceId': resourceId,
      'effectiveTier': outcome == 'unknown'
          ? null
          : outcome == 'allowed'
              ? 'premium'
              : 'free',
      'requiredTier':
          ['unknown', 'legacy'].contains(outcome) ? null : 'premium',
      'decision': outcome,
      'reason': 'paid_tier_required'
    },
        organizationId: 'o',
        memberId: 'm',
        feature: feature,
        resourceId: resourceId);
  }
}

void main() {
  testWidgets(
      'disabled gate preserves existing child without reading membership',
      (tester) async {
    final repo = _Access()..outcome = 'denied';
    await tester.pumpWidget(MaterialApp(
        home: MembershipAccessGate(
            repository: repo,
            feature: MembershipAccessFeature.advancedReport,
            resourceId: 'performance_trends',
            child: const Text('Measured report'))));
    expect(find.text('Measured report'), findsOneWidget);
    expect(repo.reads, 0);
  });
  testWidgets(
      'server legacy permits existing report and denied or unknown hides it',
      (tester) async {
    for (final outcome in ['legacy', 'denied', 'unknown']) {
      final repo = _Access()..outcome = outcome;
      await tester.pumpWidget(MaterialApp(
          home: MembershipAccessGate(
              key: ValueKey(outcome),
              enabled: true,
              repository: repo,
              feature: MembershipAccessFeature.advancedReport,
              resourceId: 'performance_trends',
              child: const Text('Measured report'))));
      await tester.pumpAndSettle();
      expect(find.text('Measured report'),
          outcome == 'legacy' ? findsOneWidget : findsNothing);
      if (outcome != 'legacy') {
        expect(find.text('Check access again'), findsOneWidget);
      }
    }
  });
  testWidgets(
      'admitted exercise survives pause and resume without rechecking or removing guidance',
      (tester) async {
    final repo = _Access();
    await tester.pumpWidget(MaterialApp(
        home: MembershipAccessGate(
            enabled: true,
            repository: repo,
            feature: MembershipAccessFeature.exercise,
            resourceId: 'supported',
            child: const Text('Running safety guidance'))));
    await tester.pumpAndSettle();
    repo.outcome = 'denied';
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Running safety guidance'), findsOneWidget);
    expect(repo.reads, 1);
  });
}
