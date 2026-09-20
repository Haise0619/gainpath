import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';
import 'panel.dart';

/// Headline figure with a caption underneath.
///
/// The label reserves a fixed two-line height regardless of how many
/// words it actually needs — a one-word label like "Rating" sitting next
/// to a two-word label like "Sessions run" in the same `Row` used to make
/// that tile visibly taller than its siblings once the longer label
/// wrapped, since neither `Row` nor `Panel` stretches children to match
/// height on their own. Reserving the space up front keeps every StatTile
/// in a row the same height no matter what each one says.
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final String? delta;
  final Color? valueColor;

  /// A smaller footprint for contexts where three or four of these sit in
  /// a header row that should stay out of the way — reduced padding and a
  /// smaller value size, same label-height symmetry guarantee.
  final bool compact;

  const StatTile(this.value, this.label,
      {super.key, this.delta, this.valueColor, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final labelStyle = compact
        ? Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)
        : Theme.of(context).textTheme.bodyMedium;
    final lineHeight = (labelStyle?.fontSize ?? 14) * (labelStyle?.height ?? 1.45);
    return Panel(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: (compact
                      ? Theme.of(context).textTheme.titleLarge
                      : Theme.of(context).textTheme.headlineMedium)
                  ?.copyWith(color: valueColor ?? AppColors.ink)),
          SizedBox(height: compact ? 1 : 2),
          SizedBox(
            height: lineHeight * 2,
            child: Text(label, style: labelStyle, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          if (delta != null) ...[
            const SizedBox(height: 6),
            Text(delta!,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.success)),
          ],
        ],
      ),
    );
  }
}
