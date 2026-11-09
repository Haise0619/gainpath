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
      this.reviewsDisplay,
      this.reviews});

  final bool previewOnly, previewRatingUnavailable;
  final Widget? previewHeader;
  final Coach coach;
  final PublishedCoachProfile? published;
  final Widget? photo;
  final VoidCallback? onOpenBooking, onOpenSchedule, onRefresh;
  final Map<String, String> branchNames;
  final String? sessionsCount;
  final String? reviewsDisplay;
  final List<CoachReview>? reviews;

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
        branchNames: branchNames.isEmpty
            ? published?.statistics?.branchNames ?? const {}
            : branchNames);
    final ratingText = previewOnly && previewRatingUnavailable
        ? 'Rating unavailable'
        : memberCoachRating(coach, published);
    final count = published != null ? published!.reviewCount : coach.reviews;
    final reviewsText = reviewsDisplay ??
        (previewOnly && previewRatingUnavailable ? 'Unavailable' : '$count');
    final sessionsText = sessionsCount ??
        (published != null
            ? published!.statistics?.completedSessions.toString() ??
                'Unavailable'
            : coach.sessionsCompleted > 0
                ? '${coach.sessionsCompleted}'
                : 'Unavailable');

    final sessionLocation =
        published == null && coach.branch.isNotEmpty && coach.branch != '-'
            ? coach.branch
            : location;
    final effectiveReviews = reviews ?? _resolveReviews(coach, published);

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
                bio.isEmpty || bio == '-' ? 'Biography not provided yet.' : bio,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  height: 1.5,
                ),
              ),
            ),
          ),
          section(
            'Session details',
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SessionInfoTile(
                    icon: Icons.location_on_rounded,
                    label: 'Location',
                    value: sessionLocation,
                    sublabel: 'In-person facility access',
                  ),
                  const Divider(height: 24, color: AppColors.hairline),
                  _SessionInfoTile(
                    icon: Icons.payments_rounded,
                    label: 'Session rate',
                    value: fee != null && fee > 0
                        ? '${memberCoachPrice(fee)} / session'
                        : 'Price unavailable',
                    sublabel: 'Final price is confirmed before payment',
                  ),
                  const Divider(height: 24, color: AppColors.hairline),
                  const _SessionInfoTile(
                    icon: Icons.timer_rounded,
                    label: 'Session format',
                    value: 'Choose duration when booking',
                    sublabel: 'Available options are confirmed before payment',
                  ),
                  if (coach.responseTime.isNotEmpty &&
                      coach.responseTime != '-') ...[
                    const Divider(height: 24, color: AppColors.hairline),
                    _SessionInfoTile(
                      icon: Icons.bolt_rounded,
                      label: 'Responsiveness',
                      value: coach.responseTime,
                      sublabel: 'In-app booking & chat confirmation',
                    ),
                  ],
                  if (!previewOnly && onOpenSchedule != null) ...[
                    const SizedBox(height: 18),
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
          section(
            'Reviews & feedback',
            _ReviewsSection(
              reviews: effectiveReviews,
              averageRating: coach.rating > 0
                  ? coach.rating
                  : (published?.averageRating ?? 0.0),
              reviewCount: published?.reviewCount ?? coach.reviews,
              previewOnly: previewOnly,
              ratingUnavailable: previewRatingUnavailable,
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

class _SessionInfoTile extends StatelessWidget {
  const _SessionInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.sublabel,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primaryTint,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: text.bodySmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  sublabel!,
                  style: text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.averageRating,
    required this.reviewCount,
    required this.previewOnly,
    required this.ratingUnavailable,
  });

  final List<CoachReview> reviews;
  final double averageRating;
  final int reviewCount;
  final bool previewOnly;
  final bool ratingUnavailable;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);

    if (ratingUnavailable) {
      return Panel(
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: AppColors.inkSoft),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reviews unavailable. Refresh your profile to retry.',
                style: text.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (reviews.isEmpty && reviewCount == 0) {
      return Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(Icons.rate_review_outlined, size: 36, color: colors.outline),
              const SizedBox(height: 8),
              Text(
                'No reviews yet',
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Reviews from verified member sessions will appear here.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isStacked = MediaQuery.textScalerOf(context).scale(14) > 18;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (averageRating > 0 || reviewCount > 0)
          Panel(
            child: Wrap(
              spacing: 16,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          averageRating > 0
                              ? averageRating.toStringAsFixed(1)
                              : 'Unavailable',
                          style: text.titleLarge?.copyWith(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          '/ 5.0',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(5, (index) {
                        final starValue = index + 1;
                        final filled = averageRating >= starValue;
                        final half = !filled && averageRating >= index + 0.5;
                        return Icon(
                          half
                              ? Icons.star_half_rounded
                              : (filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded),
                          size: 18,
                          color: filled || half
                              ? AppColors.accent
                              : colors.outlineVariant,
                        );
                      }),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$reviewCount verified ${reviewCount == 1 ? 'rating' : 'ratings'}',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_outlined,
                              size: 13, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            '100% verified',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (reviews.length < reviewCount)
          Text(
              reviews.isEmpty
                  ? 'Review details are unavailable in this view.'
                  : 'Latest ${reviews.length} of $reviewCount ratings',
              style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
        for (final review in reviews) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStacked) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.primaryTint,
                        child: Text(
                          review.memberName.isNotEmpty
                              ? review.memberName[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.memberName,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              _formatReviewDate(review.createdAt),
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index < review.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 16,
                        color: index < review.stars
                            ? AppColors.accent
                            : colors.outlineVariant,
                      );
                    }),
                  ),
                ] else ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundColor: AppColors.primaryTint,
                        child: Text(
                          review.memberName.isNotEmpty
                              ? review.memberName[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              review.memberName,
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            Text(
                              _formatReviewDate(review.createdAt),
                              style: text.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            size: 16,
                            color: index < review.stars
                                ? AppColors.accent
                                : colors.outlineVariant,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
                if (review.reviewText.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    review.reviewText,
                    style: text.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _formatReviewDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }
  }
}

List<CoachReview> _resolveReviews(
        Coach coach, PublishedCoachProfile? published) =>
    published != null
        ? published.statistics?.recentReviews ?? const []
        : coach.topReviews;
