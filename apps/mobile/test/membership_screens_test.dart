import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/browse_plans_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/purchase_plan_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/refund_request_screen.dart';

Map<String, dynamic> entitlement(
        {String tier = 'free',
        String paidStatus = 'none',
        bool unknown = false}) =>
    {
      'schemaVersion': 1,
      'policyVersion': 'gainpath-effective-membership-v1',
      'organizationId': 'gainpath',
      'memberId': 'member',
      'resolvedAtMillis': 1800000000000,
      'status': unknown ? 'unknown' : 'resolved',
      'effectiveTier': unknown ? null : tier,
      'paidTier': paidStatus == 'none'
          ? null
          : tier == 'free'
              ? 'premium'
              : tier,
      'paidPlanId': paidStatus == 'none'
          ? null
          : tier == 'free'
              ? 'premium'
              : tier,
      'paidPlanName': paidStatus == 'none' ? null : 'Configured paid plan',
      'paidStatus': unknown ? 'unknown' : paidStatus,
      'paidExpiresAtMillis': paidStatus == 'none'
          ? null
          : paidStatus == 'expired'
              ? 1800000000000
              : 1800000000001,
      'benefits':
          paidStatus == 'active' && !unknown ? ['Configured paid benefit'] : [],
      'reason': 'fixture',
    };

class MembershipFake implements MembershipCommerceRepository {
  @override
  bool get sandbox => false;
  @override
  bool get current => true;
  Future<Map<String, dynamic>>? pending;
  Map<String, dynamic> overview = {
    'account': {'status': 'none'},
    'entitlement': entitlement(),
    'plans': [],
    'transactions': []
  };
  @override
  Future<Map<String, dynamic>> load() => pending ?? Future.value(overview);
  @override
  Future<Map<String, dynamic>> payment(String id) async => {
        'transactionId': id,
        'planName': 'Fixture',
        'amountMinor': 10000,
        'paymentStatus': 'pending',
        'fulfilmentStatus': 'reconciliation_required'
      };
  @override
  Future<Map<String, dynamic>> quote(String id, String code) async =>
      {'planId': id, 'amountMinor': 10000, 'durationDays': 30};
  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
          {required bool renewal, String? quoteId}) =>
      payment(c);
  @override
  Future<Map<String, dynamic>> refund(String a, String b, String c) async =>
      {'refundStatus': 'pending_review'};
}

void main() {
  testWidgets(
      'dashboard loads, shows real empty state and disables recurring promises',
      (tester) async {
    final repo = MembershipFake(), pending = Completer<Map<String, dynamic>>();
    repo.pending = pending.future;
    await tester.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.complete(repo.overview);
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('No expiry · No membership charge'), findsOneWidget);
    expect(find.text('Upgrade'), findsOneWidget);
    expect(find.textContaining('Auto-renew unavailable'), findsOneWidget);
    expect(find.text('No membership payments yet.'), findsOneWidget);
  });
  testWidgets('empty trusted catalogue has no fabricated plan cards',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: BrowsePlansScreen(repository: MembershipFake())));
    await tester.pumpAndSettle();
    expect(find.textContaining('No membership plans are configured'),
        findsOneWidget);
    expect(find.textContaining('RM '), findsNothing);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Choose Free'), findsNothing);
  });
  testWidgets('expired paid membership shows Free with retained previous facts',
      (tester) async {
    final repo = MembershipFake();
    repo.overview['entitlement'] = entitlement(paidStatus: 'expired');
    await tester.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('PREVIOUS PAID MEMBERSHIP'), findsOneWidget);
    expect(find.textContaining('Premium · Expired'), findsOneWidget);
    expect(find.text('Renew Premium'), findsOneWidget);
  });
  testWidgets('legacy unavailable projection never silently becomes Free',
      (tester) async {
    final repo = MembershipFake()..overview.remove('entitlement');
    await tester.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Membership status unavailable'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    expect(find.text('Renew now'), findsNothing);
  });
  testWidgets('cached paid status is historical and disables renewal',
      (tester) async {
    final repo = MembershipFake();
    repo.overview.addAll({
      'cached': true,
      'entitlement': entitlement(tier: 'premium', paidStatus: 'active')
    });
    await tester.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Last verified tier · Premium'), findsOneWidget);
    expect(find.textContaining('Last recorded paid status'), findsOneWidget);
    expect(find.textContaining('Paid membership active'), findsNothing);
    final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Renew now'));
    expect(button.onPressed, isNull);
  });
  testWidgets(
      'comparison uses configured sen prices and blocks active tier switching',
      (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = MembershipFake();
    repo.overview['entitlement'] =
        entitlement(tier: 'basic', paidStatus: 'active');
    repo.overview['plans'] = [
      for (final tier in ['basic', 'premium', 'elite'])
        {
          'planId': tier,
          'name': tier == 'basic'
              ? 'Basic'
              : tier == 'premium'
                  ? 'Premium'
                  : 'Elite',
          'amountMinor': 1234,
          'durationDays': 30,
          'benefits': ['Catalogue fixture benefit'],
        },
    ];
    await tester
        .pumpWidget(MaterialApp(home: BrowsePlansScreen(repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('Basic'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
    expect(find.text('Elite'), findsNothing);
    expect(find.text('RM 12.34'), findsNWidgets(2));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Choose Basic'))
            .onPressed,
        isNotNull);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Choose Premium'))
            .onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
  for (final tier in ['basic', 'premium']) {
    testWidgets('verified $tier shows paid status and configured benefits',
        (tester) async {
      final repo = MembershipFake()
        ..overview['entitlement'] =
            entitlement(tier: tier, paidStatus: 'active');
      await tester.pumpWidget(
          MaterialApp(home: MembershipDashboardScreen(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text(tier == 'basic' ? 'Basic' : 'Premium'), findsOneWidget);
      expect(find.textContaining('Paid membership active'), findsOneWidget);
      expect(find.text('Configured paid benefit'), findsOneWidget);
      expect(find.textContaining('1.5'), findsNothing);
    });
  }
  testWidgets(
      'payment reconciliation cannot show activation or create another bill',
      (tester) async {
    final repo = MembershipFake();
    await tester.pumpWidget(MaterialApp(
        home: MembershipPaymentScreen(
            repository: repo, initial: await repo.payment('m1'))));
    await tester.pump();
    expect(find.textContaining('Admin review required'), findsOneWidget);
    expect(find.text('Paid · Membership activated'), findsNothing);
    expect(find.text('Open Billplz Sandbox'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
      'approved refund remains a decision, displays no sent-money claim',
      (tester) async {
    final repo = MembershipFake();
    repo.overview['transactions'] = [
      {
        'transactionId': 'm1',
        'planName': 'Fixture',
        'amountMinor': 10000,
        'paymentStatus': 'cleared',
        'refundStatus': 'approved',
        'reviewReason': 'Reviewed'
      }
    ];
    await tester.pumpWidget(MaterialApp(
        home: RefundRequestScreen(
            repository: repo, preselectedTransactionId: 'm1')));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Approval does not mean money has been returned'),
        findsOneWidget);
    expect(find.text('Submit refund request'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed load offers retry', (tester) async {
    final pending = Completer<Map<String, dynamic>>();
    final repo = MembershipFake()..pending = pending.future;
    await tester.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    pending.completeError(StateError('offline'));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
  });
}
