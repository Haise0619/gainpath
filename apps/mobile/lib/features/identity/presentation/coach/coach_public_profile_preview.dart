import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'coach_account_presentation.dart' show CoachAccountData;

/// Original Coach profile layout, backed by the selected owner/public snapshot.
class CoachPublicProfilePreview extends StatelessWidget {
  const CoachPublicProfilePreview(
      {super.key,
      required this.profile,
      required this.data,
      required this.header});
  final PublishedCoachProfile profile;
  final CoachAccountData data;
  final Widget header;

  @override
  Widget build(BuildContext context) {
    final fields = profile.fields;
    final body = Theme.of(context).textTheme.bodyMedium!;
    final rating = data.reviews == null
        ? 'Rating unavailable'
        : profile.reviewCount == 0
            ? 'Not yet rated'
            : '${profile.averageRating!.toStringAsFixed(1)} · ${profile.reviewCount} ${profile.reviewCount == 1 ? 'review' : 'reviews'}';
    final location = profile.branchIds
        .map((id) => data.branchNames[id])
        .whereType<String>()
        .join(' · ');
    Widget section(String label, Widget child) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 22),
          Text(label.toUpperCase(),
              style: body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .8,
                  color: AppColors.inkSoft)),
          const SizedBox(height: 10),
          child
        ]);
    Widget detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(label, style: body)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(value,
                  style: body.copyWith(fontWeight: FontWeight.w600)))
        ]));
    return Scaffold(
      appBar: AppBar(title: Text(fields.displayName)),
      body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            header,
            const SizedBox(height: 16),
            Container(
                key: const Key('coach-preview-hero'),
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: SizedBox(
                          width: 88,
                          height: 88,
                          child: data.photo == null
                              ? const Icon(Icons.person,
                                  color: Colors.white70, size: 42)
                              : Image(
                                  image: data.photo!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, stack) => const Icon(
                                      Icons.person,
                                      color: Colors.white70,
                                      size: 42)))),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Flexible(
                        child: Text(fields.displayName,
                            textAlign: TextAlign.center,
                            style: body.copyWith(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white))),
                    if (data.verified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 20)
                    ]
                  ]),
                  const SizedBox(height: 6),
                  Text(fields.specialty,
                      textAlign: TextAlign.center,
                      style: body.copyWith(color: Colors.white70)),
                  const SizedBox(height: 12),
                  Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        const Icon(Icons.star_rounded,
                            color: AppColors.accent, size: 20),
                        Text(rating,
                            textAlign: TextAlign.center,
                            style: body.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600))
                      ]),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(location,
                        textAlign: TextAlign.center,
                        style: body.copyWith(color: Colors.white70))
                  ],
                ])),
            const SizedBox(height: 18),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                  child: CoachProfileStat(
                      value: fields.yearsExperience == null
                          ? 'Not provided'
                          : '${fields.yearsExperience}y',
                      label: 'Experience')),
              const SizedBox(width: 10),
              Expanded(
                  child: CoachProfileStat(
                      value: data.sessions ?? 'Unavailable',
                      label: 'Sessions',
                      semanticLabel: 'Completed sessions')),
              const SizedBox(width: 10),
              Expanded(
                  child: CoachProfileStat(
                      value: data.reviews ?? 'Unavailable', label: 'Reviews')),
            ]),
            section(
                'Specializes in',
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final tag in fields.specializationTags)
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(999)),
                        child: Text(tag,
                            style: body.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600)))
                ])),
            section(
                'About',
                Panel(
                    child: Text(
                        fields.bio.trim().isEmpty
                            ? 'No biography provided.'
                            : fields.bio,
                        style: body.copyWith(height: 1.5)))),
            section(
                'Session',
                Panel(
                    child: Column(children: [
                  detail('Duration', 'Choose when booking'),
                  const Divider(height: 1, color: AppColors.hairline),
                  detail(
                      'Fee',
                      (fields.consultationFeeMinor ?? 0) <= 0
                          ? 'Price unavailable'
                          : 'RM ${(fields.consultationFeeMinor! / 100).toStringAsFixed(2)}'),
                  const Divider(height: 1, color: AppColors.hairline),
                  detail('Location',
                      location.isEmpty ? 'Confirmed when booking' : location)
                ]))),
            section(
                'What members say',
                Panel(
                    child: Text(
                        data.reviews == null
                            ? 'Ratings unavailable. Refresh your profile to retry.'
                            : profile.reviewCount == 0
                                ? 'No reviews yet.'
                                : 'Written reviews are not available in this preview.',
                        style: body))),
            const SizedBox(height: 24),
            const FilledButton(onPressed: null, child: Text('Book a session')),
            const SizedBox(height: 8),
            Text('Preview only — booking actions are disabled.',
                style: body.copyWith(fontSize: 12, color: AppColors.inkSoft)),
          ]),
    );
  }
}

/// Explicit body font/color avoids missing small-text slots and shrink-to-fit.
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? AppColors.ink)),
            const SizedBox(height: 6),
            Text(label,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontSize: 12.5, height: 1.3, color: AppColors.inkSoft)),
          ])));
}
