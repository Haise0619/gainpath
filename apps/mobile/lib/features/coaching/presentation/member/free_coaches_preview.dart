import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import '../../../gamification/presentation/member/locked_rewards_preview.dart';
import '../shared/live_coach_directory_views.dart';
import '../shared/published_coach_presentation.dart';
import 'widgets/coach_card.dart';

/// Informational published directory; membership actions remain in the foreground.
class FreeCoachesPreview extends StatelessWidget {
  const FreeCoachesPreview(
      {super.key,
      required this.coaches,
      required this.onViewPlans,
      this.repository,
      this.isCurrent,
      this.loading = false,
      this.error = false});
  final List<PublishedCoachProfile> coaches;
  final CoachDirectoryRepository? repository;
  final bool Function()? isCurrent;
  final bool loading, error;
  final Future<void> Function() onViewPlans;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: LockedRewardsPreview(
          sectionTitle: 'Find your coach',
          title: 'Your next step, with expert support',
          description:
              'Unlock coach profiles and booking with Basic or Premium membership.',
          previewLabel:
              'Published coach preview. Profiles and booking require Basic or Premium membership.',
          onViewPlans: onViewPlans,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (coaches.isEmpty)
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    const Icon(Icons.people_outline_rounded, size: 40),
                    const SizedBox(height: 12),
                    Text(
                        loading
                            ? 'Finding your coaches…'
                            : error
                                ? 'Could not load coaches.'
                                : 'No published coaches available yet.',
                        textAlign: TextAlign.center),
                  ]))
            else
              for (final coach in coaches.take(2))
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: CoachCard(
                      coach: publishedCoachPresentation(coach),
                      published: coach,
                      photo: repository == null
                          ? const Icon(Icons.person_outline_rounded)
                          : PublishedCoachPhoto(
                              coach: coach,
                              repository: repository!,
                              isCurrent: isCurrent ?? () => false,
                              size: 56),
                      onTap: () {},
                    )),
          ]),
        ),
      );
}
