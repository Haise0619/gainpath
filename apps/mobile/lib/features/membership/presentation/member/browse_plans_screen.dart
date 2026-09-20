import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'purchase_plan_screen.dart';
import 'widgets/plan_card.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/membership.dart';

/// AD-M4.1 — Purchase Membership Plan (browse step). A dedicated screen
/// for comparing tiers, split out from the dashboard so switching plans
/// reads as a deliberate decision rather than one option buried in a long
/// account page.
class BrowsePlansScreen extends StatelessWidget {
  const BrowsePlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Membership plans')),
      body: PageBody(
        children: [
          Text('Compare plans and switch anytime. Changes apply from your next billing date.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          ...context.read<MembershipRepository>().membershipPlans.map((plan) {
            final isCurrent = plan.id == context.read<MembershipRepository>().currentPlanId;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PlanCard(
                plan: plan,
                isCurrent: isCurrent,
                onSelect: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => PurchasePlanScreen(plan: plan))),
              ),
            );
          }),
        ],
      ),
    );
  }
}
