import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/identity.dart';
import '../../shared/member_coach_presentation.dart';

/// Member comparison card using published facts without live-status claims.
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
    final text = memberCoachTypography(context);
    final fee = memberCoachFeeMinor(coach, published);
    final tags = coach.specializationTags
        .where((t) =>
            t.trim().toLowerCase() != coach.specialty.trim().toLowerCase())
        .take(2);
    return Semantics(
      button: true,
      label: 'Open ${coach.name} coach profile',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: colors.surface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.onSurface.withValues(alpha: .12))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(builder: (context, constraints) {
                      final avatar = ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                              width: 56,
                              height: 56,
                              child: photo ?? networkAvatar(coach.imageUrl)));
                      final identity = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(coach.name,
                                style: text.titleMedium?.copyWith(
                                    color: colors.onSurface,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(coach.specialty,
                                style: text.bodyMedium
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                            if (coach.verified)
                              Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Tooltip(
                                      message:
                                          'At least one certification approved by GainPath.',
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified_rounded,
                                                size: 16,
                                                color: colors.primary),
                                            const SizedBox(width: 4),
                                            Flexible(
                                                child: Text('Verified',
                                                    style: text.labelMedium
                                                        ?.copyWith(
                                                            color: colors
                                                                .primary))),
                                          ]))),
                          ]);
                      return MediaQuery.textScalerOf(context).scale(14) > 19
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  avatar,
                                  const SizedBox(height: 12),
                                  identity
                                ])
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  avatar,
                                  const SizedBox(width: 12),
                                  Expanded(child: identity),
                                  const SizedBox(width: 4),
                                  Icon(Icons.chevron_right_rounded,
                                      color: colors.onSurfaceVariant, size: 20)
                                ]);
                    }),
                    const SizedBox(height: 14),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.star_rounded,
                              size: 18,
                              color: colors.brightness == Brightness.dark
                                  ? AppColors.accent
                                  : AppColors.accentDark),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(memberCoachRating(coach, published),
                                  style: text.bodyMedium?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w600))),
                        ]),
                    const SizedBox(height: 8),
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 18, color: colors.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Expanded(
                              child: Text(
                                  memberCoachLocation(
                                      published?.branchIds ?? const [],
                                      branchNames: branchNames),
                                  style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant))),
                        ]),
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                        color: colors.primary.withValues(
                                            alpha: colors.brightness ==
                                                    Brightness.dark
                                                ? .18
                                                : .07),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Text(tag,
                                        style: text.labelMedium?.copyWith(
                                            color: colors.onSurface)),
                                  ))
                              .toList()),
                    ],
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colors.outlineVariant),
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(memberCoachPrice(fee),
                              style: text.titleSmall?.copyWith(
                                  color: fee == null
                                      ? colors.onSurfaceVariant
                                      : colors.primary,
                                  fontWeight: FontWeight.w700)),
                          if (fee != null)
                            Text('/ session',
                                style: text.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant)),
                        ]),
                  ]),
            )),
      ),
    );
  }
}
