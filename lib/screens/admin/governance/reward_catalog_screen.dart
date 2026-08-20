import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';

/// AD-M11.4 — Manage Reward Catalog. In-place Governance pane — items a
/// member can redeem gamification points for, mirroring the member-side
/// Rewards shop this same data feeds.
class RewardCatalogScreen extends StatelessWidget {
  const RewardCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lowStock = MockData.rewards.where((r) => r.stock <= 10).length;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${MockData.rewards.length} items in the shop'
                    '${lowStock > 0 ? '  ·  $lowStock running low on stock' : ''}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => showToast(context, 'Opening the reward item form.'),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add item'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ...MockData.rewards.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                              Text('${r.points} points', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${r.stock}',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    color: r.stock <= 10 ? AppColors.warning : AppColors.ink)),
                            Text('in stock', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 19),
                          onPressed: () => showToast(context, 'Edit ${r.title}.'),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
