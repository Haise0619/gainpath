import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show BookingException;
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_dashboard_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/shared/membership_data_view.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/browse_plans_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/purchase_plan_screen.dart';
import 'package:gainpath_mobile/features/membership/presentation/member/refund_request_screen.dart';
import 'membership_screens_test.dart' as fixture;

class CommercialMembershipFake extends fixture.MembershipFake {
  String? error;
  int creates = 0, quotes = 0;
  final requests = <String>[];
  CommercialMembershipFake() {
    overview['serverNowMillis'] = 1800000000000;
    overview['plans'] = [
      for (final tier in ['basic', 'premium'])
        {
          'planId': tier,
          'name': tier == 'basic' ? 'Basic' : 'Premium',
          'amountMinor': tier == 'basic' ? 8900 : 12900,
          'durationDays': 30,
          'benefits': ['Legacy billing capability'],
        }
    ];
  }
  @override
  Future<Map<String, dynamic>> quote(String id, String code) async {
    quotes++;
    return {
      'quoteId': 'quote-$quotes',
      'planId': id,
      'baseAmountMinor': 8900,
      'amountMinor': code.isEmpty ? 8900 : 8000,
      'durationDays': 30
    };
  }

  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
      {required bool renewal, String? quoteId}) async {
    creates++;
    requests.add(c);
    throw BookingException(error ?? 'unknown');
  }
}

void main() {
  test(
      'membership timestamps use exact Malaysia time regardless of device zone',
      () {
    expect(membershipDate(1800000000000), '15 Jan 2027, 16:00 MYT');
  });
  testWidgets('Free overview emphasizes full digital access and Explore Plans',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home:
            MembershipDashboardScreen(repository: CommercialMembershipFake())));
    await t.pumpAndSettle();
    expect(find.text('Explore Plans'), findsOneWidget);
    expect(find.textContaining('AI workouts'), findsOneWidget);
  });
  testWidgets(
      'active Basic comparison labels current renewal and excludes unconfigured marketing',
      (t) async {
    final repo = CommercialMembershipFake();
    repo.overview['entitlement'] =
        fixture.entitlement(tier: 'basic', paidStatus: 'active');
    await t.pumpWidget(MaterialApp(home: BrowsePlansScreen(repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('Renew Basic'), findsOneWidget);
    expect(find.text('Current plan'), findsOneWidget);
    expect(find.text('Legacy billing capability'), findsNothing);
    expect(find.textContaining('1.5'), findsNothing);
    expect(find.textContaining('Gym entry'), findsWidgets);
  });
  testWidgets(
      'explicit pre-bill quote rejection unlocks editing and requires fresh price',
      (t) async {
    final repo = CommercialMembershipFake()..error = 'membership-quote-changed';
    await t.pumpWidget(MaterialApp(
        home: PurchasePlanScreen(
            repository: repo,
            plan: MembershipPlan('basic', 'Basic', 89, '30 days', []))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Continue to Payment'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue to Payment'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.textContaining('Review updated price'), findsOneWidget);
    expect(
        t
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Continue to Payment'))
            .onPressed,
        isNull);
    await t.ensureVisible(find.text('Verify price / apply code'));
    await t.pumpAndSettle();
    await t.tap(find.text('Verify price / apply code'));
    await t.pumpAndSettle();
    expect(repo.quotes, 2);
  });
  testWidgets('uncertain checkout locks promo and retries immutable request',
      (t) async {
    final repo = CommercialMembershipFake();
    await t.pumpWidget(MaterialApp(
        home: PurchasePlanScreen(
            repository: repo,
            plan: MembershipPlan('basic', 'Basic', 89, '30 days', []))));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Continue to Payment'));
    await t.pumpAndSettle();
    await t.tap(find.text('Continue to Payment'));
    await t.pumpAndSettle();
    expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await t.scrollUntilVisible(find.text('Recover checkout'), 100,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Recover checkout'));
    await t.pumpAndSettle();
    expect(repo.requests.length, 2);
    expect(repo.requests.toSet().length, 1);
    expect(repo.quotes, 1);
  });
  testWidgets('old refund explains deadline before offering long form',
      (t) async {
    final repo = CommercialMembershipFake();
    repo.overview['transactions'] = [
      {
        'transactionId': 'old',
        'planName': 'Basic',
        'amountMinor': 8900,
        'paymentStatus': 'cleared',
        'clearedAtMillis': 1799000000000
      }
    ];
    await t.pumpWidget(MaterialApp(
        home: RefundRequestScreen(
            repository: repo, preselectedTransactionId: 'old')));
    await t.pumpAndSettle();
    expect(find.text('Submit refund request'), findsNothing);
    expect(find.textContaining('request window has ended'), findsOneWidget);
  });
}
