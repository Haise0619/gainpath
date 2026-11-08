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
      this.branchNames = const {}});
  final Coach coach;
  final PublishedCoachProfile? published;
  final Widget? photo;
  final VoidCallback? onOpenBooking, onOpenSchedule, onRefresh;
  final Map<String, String> branchNames;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);
    final fee = memberCoachFeeMinor(coach, published);
    final experience = published != null
        ? published!.fields.yearsExperience
        : coach.yearsExperience;
    final bio = (published?.fields.bio ?? coach.bio).trim();
    final canBook = fee != null && (published == null || onOpenBooking != null);
    final location = memberCoachLocation(published?.branchIds ?? const [],
        branchNames: branchNames);
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
      appBar: AppBar(title: const Text('Coach profile'), actions: [
        if (onRefresh != null)
          IconButton(
              tooltip: 'Refresh profile',
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: colors.primary.withValues(
                        alpha:
                            colors.brightness == Brightness.dark ? .18 : .07),
                    borderRadius: BorderRadius.circular(22)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final avatar = ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                                width: 68,
                                height: 68,
                                child: photo ?? networkAvatar(coach.imageUrl)));
                        final identity = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(coach.name,
                                  style: text.titleLarge?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 5),
                              Text(coach.specialty,
                                  style: text.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant)),
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
                                    const SizedBox(width: 14),
                                    Expanded(child: identity)
                                  ]);
                      }),
                      const SizedBox(height: 16),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.star_rounded,
                                size: 20,
                                color: colors.brightness == Brightness.dark
                                    ? AppColors.accent
                                    : AppColors.accentDark),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(memberCoachRating(coach, published),
                                    style: text.bodyMedium?.copyWith(
                                        color: colors.onSurface,
                                        fontWeight: FontWeight.w700))),
                          ]),
                      if (experience != null) ...[
                        const SizedBox(height: 10),
                        Text(
                            '$experience ${experience == 1 ? 'year' : 'years'} of experience · Self-reported',
                            style: text.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant)),
                      ],
                    ])),
            const SizedBox(height: 20),
            if (coach.verified)
              Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.verified_rounded,
                            color: colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Verified coach',
                                  style: text.titleSmall?.copyWith(
                                      color: colors.onSurface,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(
                                  'At least one certification has been approved by GainPath.',
                                  style: text.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant)),
                            ])),
                      ])),
            if (coach.specializationTags.isNotEmpty)
              section(
                  'Specializations',
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: coach.specializationTags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                    color: colors.primary.withValues(
                                        alpha:
                                            colors.brightness == Brightness.dark
                                                ? .18
                                                : .07),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(tag,
                                    style: text.bodyMedium
                                        ?.copyWith(color: colors.onSurface)),
                              ))
                          .toList())),
            section(
                'About ${coach.name}',
                Text(
                    bio.isEmpty || bio == '-'
                        ? 'Biography not provided yet.'
                        : bio,
                    style: text.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant, height: 1.6))),
            section(
                'Your session',
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(location,
                      style:
                          text.bodyMedium?.copyWith(color: colors.onSurface)),
                  const SizedBox(height: 10),
                  Text(
                      'Choose your duration and time in booking. Availability, eligibility and the final price are checked there.',
                      style: text.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant)),
                  if (onOpenSchedule != null) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                            onPressed: onOpenSchedule,
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48)),
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('View schedule'))),
                  ],
                ])),
          ]),
      bottomNavigationBar: Container(
          key: const ValueKey('coach-booking-bar'),
          decoration: BoxDecoration(
              color: colors.surface,
              border: Border(top: BorderSide(color: colors.outlineVariant))),
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
                      Text(memberCoachPrice(fee),
                          style: text.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w800)),
                      if (fee != null)
                        Text('per session',
                            style: text.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant)),
                    ]);
                final button = FilledButton(
                    onPressed: canBook ? book : null,
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 48)),
                    child: const Text('Book a session'));
                final reason = fee == null
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
                        SizedBox(width: double.infinity, child: button)
                      ] else
                        Row(children: [
                          Expanded(child: price),
                          const SizedBox(width: 14),
                          button
                        ]),
                      if (reason != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(reason,
                                style: text.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant))),
                    ]);
              }))),
    );
  }
}
