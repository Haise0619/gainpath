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
    final text = memberCoachTypography(context);
    final fee = memberCoachFeeMinor(coach, published);
    final avatar = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
            width: 52,
            height: 52,
            child: photo ?? networkAvatar(coach.imageUrl)));
    final identity = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
              spacing: 5,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(coach.name,
                    style: text.titleMedium?.copyWith(
                        color: colors.onSurface, fontWeight: FontWeight.w700)),
                if (coach.verified)
                  Tooltip(
                      message:
                          'At least one certification approved by GainPath.',
                      child: Icon(Icons.verified_rounded,
                          size: 16,
                          color: colors.primary,
                          semanticLabel: 'Verified coach')),
              ]),
          const SizedBox(height: 4),
          Text(coach.specialty,
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ]);
    final facts = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    size: 16,
                    color: colors.brightness == Brightness.dark
                        ? AppColors.accent
                        : AppColors.accentDark),
                const SizedBox(width: 4),
                Flexible(
                    child: Text(memberCoachRating(coach, published),
                        style: text.bodySmall?.copyWith(
                            color: colors.onSurface,
                            fontWeight: FontWeight.w600))),
              ]),
          const SizedBox(height: 8),
          Text(memberCoachPrice(fee),
              style: text.titleSmall?.copyWith(
                  color: fee == null ? colors.onSurfaceVariant : colors.primary,
                  fontWeight: FontWeight.w800)),
          if (fee != null)
            Text('/ session',
                style:
                    text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        ]);
    return Semantics(
        button: true,
        label: 'Open ${coach.name} coach profile',
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.onSurface.withValues(alpha: .1))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: LayoutBuilder(builder: (context, constraints) {
                    final large =
                        MediaQuery.textScalerOf(context).scale(14) > 19;
                    if (large) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            avatar,
                            const SizedBox(height: 12),
                            identity,
                            const SizedBox(height: 14),
                            facts
                          ]);
                    }
                    if (constraints.maxWidth < 290) {
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
                                      size: 18, color: colors.onSurfaceVariant)
                                ]),
                            const SizedBox(height: 12),
                            facts
                          ]);
                    }
                    return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          avatar,
                          const SizedBox(width: 12),
                          Expanded(child: identity),
                          const SizedBox(width: 12),
                          SizedBox(width: 112, child: facts),
                        ]);
                  }))),
        ));
  }
}
