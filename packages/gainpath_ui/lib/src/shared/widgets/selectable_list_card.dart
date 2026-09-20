import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Selectable list-style card: icon, label, optional description, trailing
/// check. Covers both a plain single-line choice (e.g. gender) and a
/// choice-with-detail (e.g. activity level) from one component, used across
/// the onboarding wizard and the profile-edit screens that revisit the same
/// choices later.
class SelectableListCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final bool selected;
  final VoidCallback onTap;

  const SelectableListCard({
    super.key,
    required this.icon,
    required this.label,
    this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasDescription = description != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: hasDescription ? 14 : 18, vertical: hasDescription ? 14 : 16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.primary : AppColors.hairline, width: selected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            Container(
              width: hasDescription ? 42 : 44,
              height: hasDescription ? 42 : 44,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: selected ? Colors.white : AppColors.inkSoft, size: hasDescription ? 21 : 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: hasDescription
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: selected ? AppColors.primary : AppColors.ink)),
                        Text(description!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                      ],
                    )
                  : Text(label,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: selected ? AppColors.primary : AppColors.ink)),
            ),
            Icon(selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: selected ? AppColors.primary : AppColors.hairline, size: hasDescription ? 20 : 22),
          ],
        ),
      ),
    );
  }
}
