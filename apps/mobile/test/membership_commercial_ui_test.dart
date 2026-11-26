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
  Future<Map<String, dynamic>> quote(String id, String code,
      {MembershipUpgradeMode? upgradeMode}) async {
    quotes++;
    if (code == 'INVALID') throw const BookingException('failed-precondition');
    final price = id == 'premium' ? 12900 : 8900;
    return {
      'quoteId': 'quote-$quotes',
      'planId': id,
      'baseAmountMinor': price,
      'amountMinor': code.isEmpty ? price : price - 900,
      'durationDays': 30,
      if (upgradeMode != null) ...{
        'upgradeMode': upgradeMode.wireValue,
        'amountMinor':
            upgradeMode == MembershipUpgradeMode.immediate ? 13167 : 12900,
        'upgradeChargeMinor':
            upgradeMode == MembershipUpgradeMode.immediate ? 267 : 0,
        'premiumTermAmountMinor': 12900,
        'basicExpiresAtMillis': 1800172800000,
        'startsAtMillis': 1800172800000,
        'expiresAtMillis': 1802764800000,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
      {required bool renewal,
      String? quoteId,
      MembershipUpgradeMode? upgradeMode}) async {
    creates++;
    requests.add(c);
    throw BookingException(error ?? 'unknown');
  }
}

class _ClearedCheckout extends CommercialMembershipFake {
  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
          {required bool renewal,
          String? quoteId,
          MembershipUpgradeMode? upgradeMode}) =>
      payment(c);

  @override
  Future<Map<String, dynamic>> payment(String id) async => {
        'transactionId': id,
        'planName': 'Basic',
        'amountMinor': 8900,
        'paymentStatus': 'cleared',
        'fulfilmentStatus': 'confirmed',
        'expiresAtMillis': 1802592000000,
      };
}

class _RecoveredBasicCheckout extends CommercialMembershipFake {
  _RecoveredBasicCheckout({this.samePlan = false});

  final bool samePlan;

  @override
  Future<Map<String, dynamic>> checkout(String a, String b, String c,
          {required bool renewal,
          String? quoteId,
          MembershipUpgradeMode? upgradeMode}) async =>
      {
        'transactionId': 'old-basic',
        'planId': samePlan ? 'premium' : 'basic',
        'planName': samePlan ? 'Premium' : 'Basic',
        'amountMinor': samePlan ? 12000 : 8900,
        if (samePlan) 'promoCode': 'EARLIER',
        'kind': 'MembershipPurchase',
        'paymentStatus': 'pending',
        'fulfilmentStatus': 'awaiting_payment',
      };
}

void main() {
  testWidgets('Basic can open both Premium upgrade options', (t) async {
    final repo = CommercialMembershipFake();
    repo.overview['entitlement'] =
        fixture.entitlement(tier: 'basic', paidStatus: 'active');
    repo.overview['upgradeSupported'] = true;
    await t.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    await t.pumpAndSettle();
    final upgrade = find.text('Upgrade to Premium');
    await t.scrollUntilVisible(upgrade, 100);
    await t.tap(upgrade);
    await t.pumpAndSettle();
    expect(find.text('Upgrade now and extend 30 days'), findsOneWidget);
    expect(find.text('Start Premium after Basic expires'), findsOneWidget);
    await t.tap(find.text('Upgrade now and extend 30 days'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('RM 131.67'), 100);
    expect(find.text('RM 2.67'), findsOneWidget);
    expect(find.text('When payment is confirmed'), findsOneWidget);
    expect(find.text('Estimated Premium expiry'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    await t.tap(find.text('Start Premium after Basic expires'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Total'), 100);
    expect(find.text('RM 129.00'), findsWidgets);
    expect(find.text('17 Jan 2027, 16:00 MYT'), findsOneWidget);
    expect(find.text('RM 2.67'), findsNothing);
  });

  testWidgets(
      'scheduled Premium shows both dates and hides new checkout actions',
      (t) async {
    final repo = CommercialMembershipFake();
    repo.overview.addAll({
      'entitlement': {
        ...fixture.entitlement(tier: 'basic', paidStatus: 'active'),
        'paidExpiresAtMillis': 1800172800000,
      },
      'upgradeSupported': true,
      'scheduledUpgrade': {
        'planId': 'premium',
        'startsAtMillis': 1800172800000,
        'expiresAtMillis': 1802764800000
      },
    });
    await t.pumpWidget(
        MaterialApp(home: MembershipDashboardScreen(repository: repo)));
    await t.pumpAndSettle();
    expect(find.text('Premium scheduled'), findsOneWidget);
    expect(find.text('Starts 17 Jan 2027, 16:00 MYT'), findsOneWidget);
    expect(find.text('Expires 16 Feb 2027, 16:00 MYT'), findsOneWidget);
    expect(find.text('Renew Basic'), findsNothing);
    expect(find.text('Upgrade to Premium'), findsNothing);
  });

  testWidgets(
      'old pending Basic order requires confirmation when choosing Premium',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: PurchasePlanScreen(
      repository: _RecoveredBasicCheckout(),
      plan: MembershipPlan('premium', 'Premium', 129, '30 days', []),
    )));
    await t.pumpAndSettle();
    final pay = find.text('Continue to Payment');
    await t.scrollUntilVisible(pay, 100,
        scrollable: find.byType(Scrollable).first);
    await t.tap(pay);
    await t.pumpAndSettle();
    expect(find.text('Existing payment found'), findsOneWidget);
    expect(find.textContaining('Basic · RM 89.00'), findsOneWidget);
    expect(find.byType(MembershipPaymentScreen), findsNothing);
    await t.tap(find.text('Back'));
    await t.pumpAndSettle();
    expect(find.byType(MembershipPaymentScreen), findsNothing);
    await t.tap(find.text('Recover checkout'));
    await t.pumpAndSettle();
    await t.tap(find.text('View existing order'));
    await t.pumpAndSettle();
    expect(find.byType(MembershipPaymentScreen), findsOneWidget);
  });
  testWidgets(
      'existing order for the selected plan still shows its different price',
      (t) async {
    await t.pumpWidget(MaterialApp(
        home: PurchasePlanScreen(
      repository: _RecoveredBasicCheckout(samePlan: true),
      plan: MembershipPlan('premium', 'Premium', 129, '30 days', []),
    )));
    await t.pumpAndSettle();
    final pay = find.text('Continue to Payment');
    await t.scrollUntilVisible(pay, 100,
        scrollable: find.byType(Scrollable).first);
    await t.tap(pay);
    await t.pumpAndSettle();
    expect(find.text('Existing payment found'), findsOneWidget);
    expect(find.textContaining('Premium · RM 120.00'), findsOneWidget);
    expect(find.byType(MembershipPaymentScreen), findsNothing);
  });

  for (final tier in ['Basic', 'Premium']) {
    testWidgets(
        '$tier can renew with thirteen days left and sees estimated expiry',
        (t) async {
      final id = tier.toLowerCase();
      final repo = CommercialMembershipFake();
      repo.overview['entitlement'] = {
        ...fixture.entitlement(tier: id, paidStatus: 'active'),
        'resolvedAtMillis':
            DateTime.utc(2026, 11, 12, 10).millisecondsSinceEpoch,
        'paidExpiresAtMillis':
            DateTime.utc(2026, 11, 25, 10).millisecondsSinceEpoch,
      };
      await t.pumpWidget(
          MaterialApp(home: MembershipDashboardScreen(repository: repo)));
      await t.pumpAndSettle();
      expect(find.text('$tier Membership'), findsOneWidget);
      await t.tap(find.text('Renew $tier'));
      await t.pumpAndSettle();
      await t.tap(find.text('Review renewal'));
      await t.pumpAndSettle();
      expect(
          find.text('Current expiry: 25 Nov 2026, 18:00 MYT'), findsOneWidget);
      final estimate =
          find.text('Estimated new expiry: 25 Dec 2026, 18:00 MYT');
      await t.scrollUntilVisible(estimate, 120,
          scrollable: find.byType(Scrollable).first);
      expect(estimate, findsOneWidget);
    });
  }
  test('payment copy separates confirmation, activation and review', () {
    expect(membershipPaymentLabel({'fulfilmentStatus': 'awaiting_payment'}),
        'Awaiting payment');
    expect(
        membershipPaymentLabel(
            {'paymentStatus': 'cleared', 'fulfilmentStatus': 'confirmed'}),
        'Payment confirmed · Membership activated');
    expect(
        membershipPaymentLabel({
          'paymentStatus': 'cleared',
          'fulfilmentStatus': 'reconciliation_required'
        }),
        'Payment confirmed · Membership requires review');
  });
  testWidgets('View membership remains open after a checkout activates',
      (t) async {
    final repo = _ClearedCheckout();
    await t.pumpWidget(MaterialApp(home: BrowsePlansScreen(repository: repo)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Choose Basic'), 120);
    await t.pumpAndSettle();
    await t.tap(find.text('Choose Basic'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Continue to Payment'), 120,
        scrollable: find.byType(Scrollable).first);
    await t.pumpAndSettle();
    await t.tap(find.text('Continue to Payment'));
    await t.pumpAndSettle();
    await t.tap(find.text('View membership'));
    await t.pumpAndSettle();
    expect(find.byType(MembershipDashboardScreen), findsOneWidget);
  });
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
    expect(find.text('Explore Membership Plans'), findsOneWidget);
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
    await t.scrollUntilVisible(find.text('Continue to Payment'), 120,
        scrollable: find.byType(Scrollable).first);
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
    await t.scrollUntilVisible(find.text('Continue to Payment'), 120,
        scrollable: find.byType(Scrollable).first);
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

  testWidgets(
      'membership home layout preserves complete labels across 320, 360, 393, 430 widths and 1.0, 1.3, 1.5, 2.0 scales',
      (t) async {
    final repo = CommercialMembershipFake();
    repo.overview['entitlement'] =
        fixture.entitlement(tier: 'basic', paidStatus: 'active');
    repo.overview['upgradeSupported'] = true;

    for (final width in [320.0, 360.0, 393.0, 430.0]) {
      for (final scale in [1.0, 1.3, 1.5, 2.0]) {
        t.view.physicalSize = Size(width, 844);
        t.view.devicePixelRatio = 1.0;
        addTearDown(t.view.reset);

        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(width, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              home: MembershipDashboardScreen(repository: repo),
            ),
          ),
        );
        await t.pumpAndSettle();

        // 1. Critical action buttons: fully visible, no ellipsis
        expect(find.text('Renew Basic'), findsOneWidget,
            reason: 'Renew Basic missing at width $width, scale $scale');
        expect(find.text('Upgrade to Premium'), findsOneWidget,
            reason: 'Upgrade to Premium missing at width $width, scale $scale');

        // Scroll down to benefits if needed at high text scales
        await t.scrollUntilVisible(find.text('Gym Entry'), 50,
            scrollable: find.byType(Scrollable).first);

        // 2. All 4 compact benefit titles: fully visible without truncation
        expect(find.text('Gym Entry'), findsOneWidget,
            reason: 'Gym Entry missing at width $width, scale $scale');
        expect(find.text('Coach Booking'), findsOneWidget,
            reason: 'Coach Booking missing at width $width, scale $scale');
        expect(find.text('Mini-Games'), findsOneWidget,
            reason: 'Mini-Games missing at width $width, scale $scale');
        expect(find.text('Physical Rewards'), findsOneWidget,
            reason: 'Physical Rewards missing at width $width, scale $scale');

        // 3. Status and expiry information
        expect(find.text('Basic Membership'), findsOneWidget);
        expect(find.textContaining('Paid membership active'), findsOneWidget);

        // 4. Zero RenderFlex overflow exceptions
        expect(t.takeException(), isNull,
            reason: 'Overflow caught at width $width, scale $scale');

        // Unmount to reset scroll state for next test combination
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      }
    }
  });
}
