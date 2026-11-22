import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';

/// Standardized section header for GainPath Member app.
///
/// Section Title: 20sp / w700 (BarlowCondensed in Member theme)
/// Section Action: 14sp / w600 (Barlow in Member theme)
class MemberSectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? trailing;
  final bool padded;
  final bool showChevron;

  const MemberSectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onAction,
    this.trailing,
    this.padded = true,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final actionStyle = Theme.of(context)
        .textTheme
        .labelLarge
        ?.copyWith(color: AppColors.primary);

    Widget? actionWidget;
    if (trailing != null) {
      actionWidget = trailing;
    } else if (actionText != null) {
      actionWidget = InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                actionText!,
                style: actionStyle ??
                    const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      );
    }

    final content = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(title, style: titleStyle),
        if (actionWidget != null) actionWidget,
      ],
    );

    if (padded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: content,
      );
    }
    return content;
  }
}
