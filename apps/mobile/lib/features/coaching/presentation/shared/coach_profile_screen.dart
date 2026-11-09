import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/identity.dart';
import '../member/book_session_screen.dart';
import 'member_coach_presentation.dart';

class CoachProfileScreen extends StatelessWidget {
  const CoachProfileScreen(
      {super.key,
      required this.coach,
      this.published,
      this.photo,
      this.onOpenBooking,
      this.onOpenSchedule,
      this.onRefresh,
      this.branchNames = const {},
      this.previewOnly = false,
      this.previewRatingUnavailable = false,
      this.previewHeader,
      this.sessionsCount,
      this.reviewsDisplay});

  final bool previewOnly, previewRatingUnavailable;
  final Widget? previewHeader;
  final Coach coach;
  final PublishedCoachProfile? published;
  final Widget? photo;
  final VoidCallback? onOpenBooking, onOpenSchedule, onRefresh;
  final Map<String, String> branchNames;
  final String? sessionsCount;
  final String? reviewsDisplay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);
    final fee = memberCoachFeeMinor(coach, published);
    final experience = published != null
        ? published!.fields.yearsExperience
        : (coach.yearsExperience > 0 ? coach.yearsExperience : null);
    final bio = (published?.fields.bio ?? coach.bio).trim();
    final canBook = !previewOnly &&
        fee != null &&
        (published == null || onOpenBooking != null);
    final location = memberCoachLocation(published?.branchIds ?? const [],
        branchNames: branchNames);
    final ratingText = previewOnly && previewRatingUnavailable
        ? 'Rating unavailable'
        : memberCoachRating(coach, published);
    final count = published != null ? published!.reviewCount : coach.reviews;
    final reviewsText = reviewsDisplay ??
        (previewOnly && previewRatingUnavailable
            ? 'Unavailable'
            : '$count');
    final sessionsText = sessionsCount ??
        (coach.sessionsCompleted > 0
            ? '${coach.sessionsCompleted}'
            : 'Unavailable');

    void book() {
      if (!canBook) return;
      if (published != null) {
        onOpenBooking?.call();
      } else {
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => BookSessionScreen(coach: coach)));
      }
    }

    Widget section(String title, Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: text.titleMedium?.copyWith(
                  color: colors.onSurface, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          child,
        ]));

    return Scaffold(
      appBar: AppBar(
          title: Text(previewOnly ? 'Profile preview' : 'Coach profile'),
          actions: [
            if (onRefresh != null)
              IconButton(
                  tooltip: 'Refresh profile',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded)),
          ]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (previewHeader != null) ...[
            previewHeader!,
            const SizedBox(height: 16),
          ],
          // Hero Card with purple gradient
          Container(
            key: const Key('coach-preview-hero'),
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: SizedBox(
                    width: 88,
                    height: 88,
                    child: photo ??
                        (coach.imageUrl.isEmpty
                            ? const Icon(Icons.person,
                                color: Colors.white70, size: 42)
                            : networkAvatar(coach.imageUrl)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        coach.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (coach.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  coach.specialty,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    const Icon(Icons.star_rounded,
                        color: AppColors.accent, size: 20),
                    Text(
                      ratingText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                if (location.isNotEmpty &&
                    location != 'Location confirmed when booking') ...[
                  const SizedBox(height: 6),
                  Text(
                    location,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          // 3 Statistics tiles
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CoachProfileStat(
                  value: experience != null && experience > 0
                      ? '${experience}y'
                      : 'Not provided',
                  label: 'Experience',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CoachProfileStat(
                  value: sessionsText,
                  label: 'Sessions',
                  semanticLabel: 'Completed sessions',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CoachProfileStat(
                  value: reviewsText,
                  label: 'Reviews',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (coach.specializationTags.isNotEmpty)
            section(
              'Specializations',
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in coach.specializationTags)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          section(
            'About ${coach.name}',
            Panel(
              child: Text(
                bio.isEmpty || bio == '-'
                    ? 'Biography not provided yet.'
                    : bio,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
          section(
            'Your session',
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    location.isEmpty
                        ? 'Location confirmed when booking'
                        : location,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose your duration and time in booking. Availability, eligibility and the final price are checked there.',
                    style: text.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (!previewOnly && onOpenSchedule != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenSchedule,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('View schedule'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        key: const ValueKey('coach-booking-bar'),
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(14) > 19;
            final price = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  memberCoachPrice(fee),
                  style: text.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (fee != null)
                  Text(
                    'per session',
                    style: text.bodySmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
              ],
            );
            final button = FilledButton(
              onPressed: canBook ? book : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
              child: const Text('Book a session'),
            );
            final reason = previewOnly
                ? 'Preview only — booking actions are disabled.'
                : fee == null
                    ? 'Booking unavailable until a session price is published.'
                    : onOpenBooking == null && published != null
                        ? 'Booking is unavailable in this view.'
                        : null;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stacked) ...[
                  price,
                  const SizedBox(height: 10),
                  SizedBox(width: double.infinity, child: button),
                ] else
                  Row(
                    children: [
                      Expanded(child: price),
                      const SizedBox(width: 14),
                      button,
                    ],
                  ),
                if (reason != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      reason,
                      style: text.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

/// Stat card for Experience, Sessions, Reviews.
class CoachProfileStat extends StatelessWidget {
  const CoachProfileStat(
      {super.key,
      required this.value,
      required this.label,
      this.valueColor,
      this.semanticLabel});
  final String value, label;
  final Color? valueColor;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticLabel,
        child: Panel(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? AppColors.ink,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 12.5,
                      height: 1.3,
                      color: AppColors.inkSoft,
                    ),
              ),
            ],
          ),
        ),
      );
}
