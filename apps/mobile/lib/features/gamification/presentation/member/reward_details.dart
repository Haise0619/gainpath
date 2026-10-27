import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

String rewardDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true)
      .add(const Duration(hours: 8));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.day}/${d.month}/${d.year} · ${two(d.hour)}:${two(d.minute)} MYT';
}

class RewardCover extends StatelessWidget {
  const RewardCover({super.key, required this.url});
  final String url;
  @override
  Widget build(BuildContext context) {
    final uri = Uri.tryParse(url);
    final placeholder = Container(
        color: AppColors.surfaceAlt,
        alignment: Alignment.center,
        child: const Icon(Icons.card_giftcard_rounded,
            size: 52, color: AppColors.primary));
    return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
            height: 150,
            width: double.infinity,
            child: uri?.scheme == 'https' && (uri?.host.isNotEmpty ?? false)
                ? Image.network(url,
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => placeholder)
                : placeholder));
  }
}

class RewardTerms extends StatelessWidget {
  const RewardTerms(
      {super.key,
      required this.description,
      required this.conditions,
      required this.instructions});
  final String description, conditions, instructions;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (description.isNotEmpty) ...[
          Text(description),
          const SizedBox(height: 20)
        ],
        Text('Conditions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(conditions.isEmpty
            ? 'No saved conditions are available for this legacy voucher. Ask reception before collection.'
            : conditions),
        const SizedBox(height: 20),
        Text('How to collect', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(instructions.isEmpty
            ? 'Show your voucher reference at reception for staff verification.'
            : instructions),
      ]);
}

class RewardDetailsScreen extends StatelessWidget {
  const RewardDetailsScreen(
      {super.key,
      required this.item,
      required this.enabled,
      required this.isCurrent,
      required this.disabledReason});
  final VerifiedRewardItem item;
  final bool enabled;
  final bool Function() isCurrent;
  final String disabledReason;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reward details')),
      body: SafeArea(
          child: PageBody(children: [
        RewardCover(url: item.imageUrl),
        const SizedBox(height: 20),
        Text(item.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text('${item.pointCost} points',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(item.validityDays == null
            ? 'Validity is shown on your issued voucher.'
            : 'Valid for ${item.validityDays} days from redemption.'),
        const SizedBox(height: 20),
        Panel(
            child: RewardTerms(
                description: item.description,
                conditions: item.conditions,
                instructions: item.collectionInstructions)),
        const SizedBox(height: 16),
        const Text(
            'Points are spent when redemption is confirmed. If the voucher expires unused, points remain spent. No automatic refund.'),
        const SizedBox(height: 12),
        const Text(
            'Your issued voucher remains valid until its expiry even if your membership expires.'),
        const SizedBox(height: 20),
        if (!enabled)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(disabledReason)),
        FilledButton(
            onPressed: enabled
                ? () {
                    if (isCurrent()) Navigator.pop(context, true);
                  }
                : null,
            child: const Text('Confirm redemption')),
      ])));
}
