import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Presentation only. Publication and credential authority remain server-owned.
class CoachReviewOverview extends StatelessWidget {
  const CoachReviewOverview({super.key, required this.review});
  final CoachPublicationReview review;

  Map<String, String> _fields(CoachProfessionalFields value) => {
        'Display name': value.displayName,
        'Primary specialty': value.specialty,
        'Biography': value.bio.isEmpty ? 'Not provided' : value.bio,
        'Specializations': value.specializationTags.join(' · '),
        'Experience': value.yearsExperience == null
            ? 'Not provided'
            : '${value.yearsExperience} years (self-reported)',
        'Consultation fee': (value.consultationFeeMinor ?? 0) > 0
            ? 'RM ${(value.consultationFeeMinor! / 100).toStringAsFixed(2)} / session'
            : 'Not set — checkout unavailable',
        'Profile photo':
            value.photoPath == null ? 'No photo attached' : 'Photo attached',
      };

  @override
  Widget build(BuildContext context) {
    final draft = review.draft, publication = review.publication;
    final pending =
        draft != null && draft.revision > (publication?.sourceRevision ?? 0);
    final verified =
        review.certificationVerified && review.approvedCertificationCount > 0;
    final proposed = draft == null ? null : _fields(draft.fields);
    final published = publication == null ? null : _fields(publication.fields);
    final changed = <String>{
      if (proposed != null)
        for (final key in proposed.keys)
          if (published?[key] != proposed[key] ||
              key == 'Profile photo' &&
                  draft?.fields.photoPath != publication?.fields.photoPath)
            key
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.fact_check_outlined,
                    color: AppColors.primary, size: 28)),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Coach profile review',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text('Review ${review.coachId}',
                      style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                  pending
                      ? 'Changes awaiting publication'
                      : publication?.status == 'published'
                          ? 'Published profile is up to date'
                          : 'Directory profile is inactive or unpublished',
                  style: const TextStyle(color: AppColors.inkSoft)),
            ]),
          ]),
      const SizedBox(height: 20),
      _Section(
          title: '1. Compare profile information',
          subtitle:
              'Draft changes stay private until you explicitly publish them. Changed fields are marked below.',
          child: LayoutBuilder(builder: (context, constraints) {
            final left =
                _profile(context, 'Draft profile', proposed, changed, true);
            final right = _profile(
                context, 'Published profile', published, changed, false);
            return constraints.maxWidth >= 760
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: left),
                    const SizedBox(width: 16),
                    Expanded(child: right)
                  ])
                : Column(children: [left, const SizedBox(height: 16), right]);
          })),
      const SizedBox(height: 20),
      _Section(
          title: '2. Check publication eligibility',
          subtitle:
              'Approval does not publish the profile. Review the credentials below, then use Publish profile.',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _check(
                draft != null,
                draft == null
                    ? 'Draft missing. Existing public content can still be deactivated.'
                    : 'Professional draft available'),
            _check(
                review.targetMembershipEligible,
                review.targetMembershipEligible
                    ? 'Active Coach membership with valid branch assignments'
                    : 'Membership unavailable; publication is blocked.'),
            _check(
                verified,
                verified
                    ? '${review.approvedCertificationCount} approved certification${review.approvedCertificationCount == 1 ? '' : 's'} · Verified (BR-5)'
                    : 'Publication requires at least one approved certification (BR-5).'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              const Text('Assigned branches:',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              if (review.branchIds.isEmpty)
                const Text('None available')
              else
                for (final id in review.branchIds) Chip(label: Text(id))
            ]),
            if (draft != null && (draft.fields.consultationFeeMinor ?? 0) <= 0)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'No valid consultation fee is set in the draft. Members will see no price and session checkout will be disabled.')),
            if (draft != null &&
                publication != null &&
                draft.fields.consultationFeeMinor !=
                    publication.fields.consultationFeeMinor)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                      'Publishing updates the public consultation fee. Existing bookings retain their snapshotted transaction prices.')),
            const SizedBox(height: 12),
            const Text(
                'The server also checks current account and branch eligibility at publication.',
                style: TextStyle(color: AppColors.inkSoft)),
          ])),
      const SizedBox(height: 12),
      ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Record details',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text(
              'Directory: ${publication?.status ?? 'not published'} · Draft revision: ${draft?.revision ?? 'missing'} · Public revision: ${review.publicRevision}'),
          childrenPadding: const EdgeInsets.only(bottom: 16),
          children: [
            _detail('Coach ID', review.coachId),
            _detail('Published from draft revision',
                '${publication?.sourceRevision ?? 'Not published yet'}'),
            _detail(
                'Draft updated (local time)', _time(draft?.updatedAtMillis)),
            _detail('Last published (local time)',
                _time(publication?.publishedAtMillis)),
          ]),
    ]);
  }

  String _time(int? value) => value == null
      ? 'Not available'
      : DateTime.fromMillisecondsSinceEpoch(value)
          .toLocal()
          .toString()
          .substring(0, 16);

  Widget _profile(BuildContext context, String title,
          Map<String, String>? values, Set<String> changed, bool isDraft) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: isDraft
                ? AppColors.primary.withValues(alpha: .035)
                : AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(isDraft ? 'Proposed information' : 'What Members currently see',
              style: const TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 18),
          if (values == null)
            Text(isDraft ? 'No draft available' : 'Not published yet')
          else
            for (final entry in values.entries)
              Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(entry.key,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.inkSoft)),
                              if (isDraft && changed.contains(entry.key))
                                const Text('Changed',
                                    style: TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700))
                            ]),
                        const SizedBox(height: 6),
                        SelectableText(entry.value,
                            style: const TextStyle(fontSize: 14, height: 1.5)),
                      ])),
        ]),
      );
  Widget _check(bool valid, String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(valid ? Icons.check_circle_outline : Icons.info_outline,
            color: valid ? AppColors.success : AppColors.warning, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.5)))
      ]));
  Widget _detail(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Align(
          alignment: Alignment.centerLeft,
          child: SelectableText('$label: $value',
              style: const TextStyle(height: 1.5))));
}

class _Section extends StatelessWidget {
  const _Section(
      {required this.title, required this.subtitle, required this.child});
  final String title, subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle,
            style: const TextStyle(color: AppColors.inkSoft, height: 1.5)),
        const SizedBox(height: 16),
        child,
      ]);
}
