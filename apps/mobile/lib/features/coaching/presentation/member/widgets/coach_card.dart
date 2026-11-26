import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/identity.dart';
import '../../shared/member_coach_presentation.dart';

/// Essential comparison facts; richer coach information lives in the profile.
class CoachCard extends StatelessWidget {
  const CoachCard(
      {super.key,
      required this.coach,
      required this.onTap,
      this.published,
      this.photo,
      this.branchNames = const {}});
  final Coach coach;
  final VoidCallback onTap;
  final PublishedCoachProfile? published;
  final Widget? photo;
  final Map<String, String> branchNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final primaryPurple = isDark ? colors.primary : const Color(0xFF7027DC);
    final primaryText = isDark ? colors.onSurface : const Color(0xFF211A31);
    final secondaryText =
        isDark ? colors.onSurfaceVariant : const Color(0xFF766D87);
    final borderColor = isDark
        ? colors.outlineVariant.withValues(alpha: 0.35)
        : const Color(0xFFE7E3EF);
    final text = memberCoachTypography(context);
    final fee = memberCoachFeeMinor(coach, published);
    final avatar = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
            width: 64,
            height: 64,
            child: photo ?? networkAvatar(coach.imageUrl)));
    final locations = published?.branchIds
            .map((id) => branchNames[id])
            .whereType<String>()
            .toList() ??
        [];

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                coach.name,
                style: text.titleMedium?.copyWith(
                  color: primaryText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
            if (coach.verified) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: 'At least one certification approved by GainPath.',
                child: Icon(
                  Icons.verified_rounded,
                  size: 16,
                  color: primaryPurple,
                  semanticLabel: 'Verified coach',
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          coach.specialty,
          style: text.bodySmall?.copyWith(
            color: primaryPurple,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 16,
              color: colors.brightness == Brightness.dark
                  ? AppColors.accent
                  : AppColors.accentDark,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                memberCoachRating(coach, published),
                style: text.bodySmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final locationWidget = Row(
      children: [
        Icon(
          Icons.location_on_outlined,
          size: 14,
          color: secondaryText.withValues(alpha: 0.85),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            locations.join(' · '),
            style: text.bodySmall?.copyWith(
              color: secondaryText,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );

    final priceWidget = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Text(
          memberCoachPrice(fee),
          style: text.titleMedium?.copyWith(
            color: fee == null ? secondaryText : primaryPurple,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        if (fee != null)
          Text(
            'per session',
            style: text.bodySmall?.copyWith(
              color: secondaryText,
              fontSize: 11,
            ),
          ),
      ],
    );

    return Semantics(
      button: true,
      label: 'Open ${coach.name} coach profile',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isDark ? colors.surface : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: borderColor,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stackFooter = constraints.maxWidth < 278 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        avatar,
                        const SizedBox(width: 12),
                        Expanded(child: identity),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: colors.onSurfaceVariant),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 10),
                    if (locations.isEmpty)
                      Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: priceWidget)
                    else if (stackFooter) ...[
                      locationWidget,
                      const SizedBox(height: 6),
                      priceWidget,
                    ] else
                      Row(children: [
                        Expanded(child: locationWidget),
                        const SizedBox(width: 12),
                        Flexible(child: priceWidget),
                      ]),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
