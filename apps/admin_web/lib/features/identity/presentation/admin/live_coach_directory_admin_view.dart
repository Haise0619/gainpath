import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/coach_directory_admin_cubit.dart';
import 'coach_certification_review_panel.dart';
import 'coach_review_discard_guard.dart';

class LiveCoachDirectoryAdminView extends StatefulWidget {
  const LiveCoachDirectoryAdminView(
      {super.key,
      required this.repository,
      this.discardGuard,
      this.onOpenSchedule,
      this.onOpenBookings});
  final CoachProfileAdminRepository repository;
  final CoachReviewDiscardGuard? discardGuard;
  final void Function(String coachId)? onOpenSchedule;
  final void Function(String coachId)? onOpenBookings;
  @override
  State<LiveCoachDirectoryAdminView> createState() =>
      _LiveCoachDirectoryAdminViewState();
}

class _LiveCoachDirectoryAdminViewState
    extends State<LiveCoachDirectoryAdminView> {
  late final discardGuard = widget.discardGuard ?? CoachReviewDiscardGuard();
  Future<void> guarded(VoidCallback action) async {
    if (await discardGuard.canLeave() && mounted) action();
  }

  late final controller = CoachDirectoryAdminCubit(widget.repository)
    ..refresh();
  @override
  void dispose() {
    controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<CoachDirectoryAdminCubit,
          CoachDirectoryAdminState>(
      bloc: controller,
      builder: (context, state) {
        final names = {
          for (final p in state.publicProfiles) p.id: p.fields.displayName,
          for (final d in state.drafts) d.id: d.fields.displayName
        };
        final review = state.review;
        return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('Coach Directory',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold))),
                IconButton(
                    tooltip: 'Refresh Coaches',
                    onPressed:
                        state.busy ? null : () => guarded(controller.refresh),
                    icon: const Icon(Icons.refresh))
              ]),
              const Text(
                  'Review professional drafts and public directory listings. Publication is not certification verification.'),
              if (state.loading) const LinearProgressIndicator(),
              if (state.message != null) Text(state.message!),
              if (state.allowed) ...[
                Text(
                    'Loaded drafts: ${state.drafts.length} · Loaded public records: ${state.publicProfiles.length}'),
                if (names.isEmpty)
                  const Text('No Coach profiles are available.'),
                for (final entry in names.entries)
                  ListTile(
                      title: Text(entry.value),
                      subtitle: Text(entry.key),
                      trailing: TextButton(
                          onPressed: state.busy
                              ? null
                              : () =>
                                  guarded(() => controller.review(entry.key)),
                          child: const Text('Review'))),
                if (state.draftCursor != null)
                  TextButton(
                      onPressed: state.busy
                          ? null
                          : () => controller.loadMore(publicPage: false),
                      child: const Text('Load more drafts')),
                if (state.publicCursor != null)
                  TextButton(
                      onPressed: state.busy
                          ? null
                          : () => controller.loadMore(publicPage: true),
                      child: const Text('Load more public profiles')),
              ],
              if (review != null)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Review ${review.coachId}',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (review.draft != null) ...[
                        Text(review.draft!.fields.displayName),
                        Text(review.draft!.fields.specialty),
                        Text(review.draft!.fields.bio),
                        Text(review.draft!.fields.specializationTags
                            .join(' · ')),
                        if (review.draft!.fields.yearsExperience != null)
                          Text(
                              '${review.draft!.fields.yearsExperience} years (self-reported)')
                      ],
                      Text(
                          'Draft revision: ${review.draft?.revision ?? 'missing'} · Public revision: ${review.publicRevision}'),
                      Text(
                          'Directory: ${review.publication?.status ?? 'not published'} · Assigned branches: ${review.branchIds.join(', ')}'),
                      if (review.draft == null)
                        const Text(
                            'Draft missing. Existing public content can still be deactivated.'),
                      if (review.draft != null &&
                          !review.targetMembershipEligible)
                        const Text(
                            'Current Coach membership is unavailable; publication is blocked.'),
                      const Text(
                          'The server also checks current account and branch eligibility at publication.'),
                      const SizedBox(height: 12),
                      CoachCertificationReviewPanel(
                          key: ValueKey(review.coachId),
                          coachId: review.coachId,
                          discardGuard: discardGuard,
                          repository: widget.repository),
                      Wrap(spacing: 12, children: [
                        OutlinedButton(
                            onPressed:
                                !state.busy && widget.onOpenBookings != null
                                    ? () => guarded(() =>
                                        widget.onOpenBookings!(review.coachId))
                                    : null,
                            child: const Text('View bookings')),
                        OutlinedButton.icon(
                            onPressed:
                                !state.busy && widget.onOpenSchedule != null
                                    ? () => guarded(() =>
                                        widget.onOpenSchedule!(review.coachId))
                                    : null,
                            icon: const Icon(Icons.calendar_month_outlined),
                            label: const Text('View schedule')),
                        FilledButton(
                            onPressed: !state.busy &&
                                    !state.conflict &&
                                    review.canPublish
                                ? () => controller
                                    .setStatus(CoachDirectoryAction.publish)
                                : null,
                            child: const Text('Publish profile')),
                        OutlinedButton(
                            onPressed: !state.busy &&
                                    !state.conflict &&
                                    review.publication != null
                                ? () => controller
                                    .setStatus(CoachDirectoryAction.deactivate)
                                : null,
                            child: const Text('Deactivate directory profile')),
                        TextButton(
                            onPressed: state.busy
                                ? null
                                : () => guarded(
                                    () => controller.review(review.coachId)),
                            child: const Text('Discard and reload review')),
                      ]),
                    ])),
            ]));
      });
}
