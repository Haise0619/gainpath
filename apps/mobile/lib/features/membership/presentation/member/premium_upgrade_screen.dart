import 'package:flutter/material.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/membership_feature_host.dart';
import '../shared/membership_data_view.dart';
import 'purchase_plan_screen.dart';

MembershipPlan? availablePremiumUpgrade(
    Map<String, dynamic> overview, MembershipEntitlement entitlement) {
  if (overview['upgradeSupported'] != true ||
      !entitlement.canStartCheckout ||
      entitlement.effectiveTier != MembershipTier.basic ||
      membershipUpgradeSchedule(overview) != null) {
    return null;
  }
  final plan = membershipRows(overview['plans'])
      .where((p) => p['planId'] == 'premium')
      .firstOrNull;
  return plan == null
      ? null
      : MembershipPlan(
          'premium',
          plan['name'] as String,
          (plan['amountMinor'] as num) / 100,
          membershipPlanPositioning('premium'),
          membershipProductBenefits('premium'));
}

class PremiumUpgradeScreen extends StatelessWidget {
  const PremiumUpgradeScreen(
      {super.key, required this.repository, required this.plan});

  final MembershipCommerceRepository repository;
  final MembershipPlan plan;

  @override
  Widget build(BuildContext context) {
    Future<void> review(MembershipUpgradeMode mode) => Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => PurchasePlanScreen(
                plan: plan, repository: repository, upgradeMode: mode)));

    return MembershipRepositoryGuard(
        repository: repository,
        child: Scaffold(
          appBar: AppBar(title: const Text('Upgrade to Premium')),
          body: PageBody(children: [
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text('Use Premium now',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Pay the difference for your remaining Basic time and buy another 30 days of Premium in one payment.'),
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => review(MembershipUpgradeMode.immediate),
                      child: const Text('Upgrade now and extend 30 days')),
                ])),
            const SizedBox(height: 16),
            Panel(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Text('Use Premium next term',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  const Text(
                      'Pay for 30 days of Premium now. Your current Basic access continues until it expires.'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                      onPressed: () => review(MembershipUpgradeMode.nextTerm),
                      child: const Text('Start Premium after Basic expires')),
                ])),
          ]),
        ));
  }
}
