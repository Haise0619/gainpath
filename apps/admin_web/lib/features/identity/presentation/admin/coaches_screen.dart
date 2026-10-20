import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'user_action_dialogs.dart';
import '../../application/coach_directory_admin_cubit.dart';
import 'coach_certification_review_panel.dart';
import 'coach_review_discard_guard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Widget _networkHero(String url, {BoxFit fit = BoxFit.cover}) {
  return Image.network(
    url,
    fit: fit,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.3 — the Coach half of Manage User Accounts. Coaches are few
/// (a handful per branch) and organised by which physical location they
/// work out of, so this reads as branch sections of roster cards rather
/// than the dense searchable table Members uses.
class CoachesScreen extends StatefulWidget {
  const CoachesScreen(
      {super.key,
      this.live = false,
      this.onOpenSchedule,
      this.onOpenBookings,
      this.discardGuard});
  final CoachReviewDiscardGuard? discardGuard;
  final bool live;
  final void Function(String coachId)? onOpenSchedule;
  final void Function(String coachId)? onOpenBookings;

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  late final CoachReviewDiscardGuard _discardGuard;
  CoachDirectoryAdminCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _discardGuard = widget.discardGuard ?? CoachReviewDiscardGuard();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live && _cubit == null) {
      _cubit =
          CoachDirectoryAdminCubit(context.read<CoachProfileAdminRepository>())
            ..refresh();
    }
  }

  @override
  void dispose() {
    _cubit?.close();
    super.dispose();
  }

  Future<void> _guarded(VoidCallback action) async {
    if (await _discardGuard.canLeave() && mounted) action();
  }

  void _refresh() => setState(() {});

  List<UserAccount> get _coaches => context
      .read<UserAccountRepository>()
      .users
      .where((u) => u.role == 'Coach')
      .toList();

  Coach? _profileFor(UserAccount user) {
    for (final c in context.read<CoachRepository>().coaches) {
      if (c.name == user.name) return c;
    }
    return null;
  }

  List<_CoachEntry> _sampleEntries() => [
        for (final user in _coaches)
          _CoachEntry(
            id: user.email,
            name: user.name,
            specialty: user.specialty ?? '-',
            branchIds: [if (user.branch?.isNotEmpty == true) user.branch!],
            statusLabel: user.status.label,
            pending: user.status == AccountStatus.pending,
            imageUrl: _profileFor(user)?.imageUrl,
            rating: _profileFor(user)?.rating,
            sessionsCompleted: _profileFor(user)?.sessionsCompleted,
            feeLabel: _profileFor(user) != null && _profileFor(user)!.fee > 0
                ? 'RM ${_profileFor(user)!.fee.toStringAsFixed(2)}'
                : '—',
            note: _profileFor(user) == null
                ? 'Not yet onboarded — no public profile'
                : null,
            onTap: () => _manage(context, user),
          ),
      ];

  List<_CoachEntry> _liveEntries(CoachDirectoryAdminState state) {
    if (!state.allowed) return [];
    final drafts = {for (final draft in state.drafts) draft.id: draft};
    final publications = {
      for (final profile in state.publicProfiles) profile.id: profile
    };
    return [
      for (final id in <String>{...drafts.keys, ...publications.keys})
        _CoachEntry(
          id: id, actionLabel: 'Review',
          name: drafts[id]?.fields.displayName ??
              publications[id]?.fields.displayName ??
              '-',
          specialty: drafts[id]?.fields.specialty ??
              publications[id]?.fields.specialty ??
              '-',
          // A private draft has no branch field. Only server review/public data can supply one.
          branchIds: state.review?.coachId == id
              ? state.review!.branchIds
              : publications[id]?.branchIds ?? const [],
          statusLabel: publications[id] == null
              ? 'Draft'
              : drafts[id] == null
                  ? (publications[id]!.isPublished ? 'Published' : 'Inactive')
                  : (publications[id]!.isPublished
                      ? 'Draft & Published'
                      : 'Draft & Inactive'),
          pending: drafts[id] != null &&
              (publications[id] == null ||
                  drafts[id]!.revision != publications[id]!.sourceRevision),
          feeLabel: publications[id]?.fields.consultationFeeMinor != null &&
                  publications[id]!.fields.consultationFeeMinor! > 0
              ? 'RM ${(publications[id]!.fields.consultationFeeMinor! / 100).toStringAsFixed(2)}'
              : (drafts[id]?.fields.consultationFeeMinor != null &&
                      drafts[id]!.fields.consultationFeeMinor! > 0
                  ? 'Draft: RM ${(drafts[id]!.fields.consultationFeeMinor! / 100).toStringAsFixed(2)}'
                  : '—'),
          note: drafts[id]?.fields.yearsExperience == null
              ? null
              : '${drafts[id]!.fields.yearsExperience} yrs experience',
          onTap: state.busy ? null : () => _guarded(() => _cubit!.review(id)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit != null) {
      return BlocBuilder<CoachDirectoryAdminCubit, CoachDirectoryAdminState>(
        bloc: cubit,
        builder: (context, state) =>
            _page(context, _liveEntries(state), state: state),
      );
    }
    return _page(context, _sampleEntries());
  }

  Widget _page(BuildContext context, List<_CoachEntry> coaches,
      {CoachDirectoryAdminState? state}) {
    final branchIds = <String>{for (final coach in coaches) ...coach.groups};
    final pendingCount = coaches.where((coach) => coach.pending).length;
    return Scaffold(
      key: const ValueKey('coaches-page'),
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _StatChip(
                icon: Icons.sports_rounded,
                label:
                    state == null ? 'Total coaches' : 'Total coaches (loaded)',
                value: '${coaches.length}'),
            const SizedBox(width: 12),
            _StatChip(
                icon: Icons.hourglass_top_rounded,
                label: state == null
                    ? 'Pending review'
                    : 'Pending review (loaded)',
                value: '$pendingCount',
                color: AppColors.warning),
            const Spacer(),
            if (state != null)
              IconButton(
                  tooltip: 'Refresh Coaches',
                  onPressed:
                      state.busy ? null : () => _guarded(_cubit!.refresh),
                  icon: const Icon(Icons.refresh)),
            FilledButton.icon(
              key: const ValueKey('add-coach'),
              onPressed: state != null
                  ? null
                  : () => provisionCoachFlow(context, _refresh),
              icon: const Icon(Icons.person_add_alt_rounded, size: 17),
              label: const Text('Add a coach'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ]),
          const SizedBox(height: 22),
          if (state?.loading == true) const LinearProgressIndicator(),
          if (state?.message != null) Text(state!.message!),
          if (state != null &&
              state.allowed &&
              !state.loading &&
              coaches.isEmpty)
            const Text('No Coach profiles are available.'),
          for (final branchId in branchIds)
            Padding(
              key: ValueKey('coach-branch-$branchId'),
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.storefront_outlined,
                          size: 15, color: AppColors.inkSoft),
                      const SizedBox(width: 6),
                      Text(
                          '$branchId  ·  ${coaches.where((coach) => coach.groups.contains(branchId)).length}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 13.5)),
                    ]),
                    const SizedBox(height: 10),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      for (final coach in coaches
                          .where((coach) => coach.groups.contains(branchId)))
                        _CoachCard(
                          key: ValueKey('coach-card-$branchId-${coach.id}'),
                          entry: coach,
                        ),
                    ]),
                  ]),
            ),
          if (state != null && state.allowed)
            Wrap(spacing: 12, children: [
              if (state.draftCursor != null)
                TextButton(
                    onPressed: state.busy
                        ? null
                        : () => _cubit!.loadMore(publicPage: false),
                    child: const Text('Load more drafts')),
              if (state.publicCursor != null)
                TextButton(
                    onPressed: state.busy
                        ? null
                        : () => _cubit!.loadMore(publicPage: true),
                    child: const Text('Load more public profiles')),
            ]),
          if (state?.review != null) ...[
            const SizedBox(height: 24),
            _reviewDetails(context, state!)
          ],
        ]),
      ),
    );
  }

  Widget _reviewDetails(BuildContext context, CoachDirectoryAdminState state) {
    final review = state.review!;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review ${review.coachId}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (review.draft != null) ...[
            Text(review.draft!.fields.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(review.draft!.fields.specialty),
            Text(review.draft!.fields.bio),
            Text(review.draft!.fields.specializationTags.join(' · ')),
            if (review.draft!.fields.yearsExperience != null)
              Text(
                '${review.draft!.fields.yearsExperience} years (self-reported)',
              ),
            const SizedBox(height: 8),
          ],
          Builder(builder: (context) {
            final draftFeeMinor = review.draft?.fields.consultationFeeMinor;
            final draftFeeText = draftFeeMinor != null && draftFeeMinor > 0
                ? 'RM ${(draftFeeMinor / 100).toStringAsFixed(2)} / session'
                : '— (no fee set)';
            final pubFeeMinor = review.publication?.fields.consultationFeeMinor;
            final pubFeeText = pubFeeMinor != null && pubFeeMinor > 0
                ? 'RM ${(pubFeeMinor / 100).toStringAsFixed(2)} / session'
                : '— (no fee published)';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Proposed fee (draft): $draftFeeText',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('Published fee: $pubFeeText'),
                if (review.draft != null &&
                    (draftFeeMinor == null || draftFeeMinor <= 0))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Note: No valid consultation fee is set in draft. If published, members will see "—" and session checkout will be disabled.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                if (review.draft != null &&
                    review.publication != null &&
                    draftFeeMinor != null &&
                    draftFeeMinor > 0 &&
                    draftFeeMinor != pubFeeMinor)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Publishing will update public consultation fee from $pubFeeText to $draftFeeText. Existing bookings retain their snapshotted transaction prices.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.blue.shade900),
                    ),
                  ),
                const SizedBox(height: 6),
              ],
            );
          }),
          Text(
            'Draft revision: ${review.draft?.revision ?? 'missing'} · Public revision: ${review.publicRevision}',
          ),
          Text(
            'Directory: ${review.publication?.status ?? 'not published'} · Assigned branches: ${review.branchIds.join(', ')}',
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                review.certificationVerified &&
                        review.approvedCertificationCount > 0
                    ? Icons.verified
                    : Icons.gpp_maybe_outlined,
                size: 16,
                color: review.certificationVerified &&
                        review.approvedCertificationCount > 0
                    ? Colors.green.shade700
                    : Colors.amber.shade900,
              ),
              const SizedBox(width: 6),
              Text(
                'Certification verification (BR-5): ${review.certificationVerified && review.approvedCertificationCount > 0 ? "Verified (${review.approvedCertificationCount} approved)" : "Unverified (0 approved)"}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: review.certificationVerified &&
                          review.approvedCertificationCount > 0
                      ? Colors.green.shade800
                      : Colors.amber.shade900,
                ),
              ),
            ],
          ),
          if (!review.certificationVerified ||
              review.approvedCertificationCount <= 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  border: Border.all(color: Colors.amber.shade300),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.amber.shade900),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Publication requires at least one approved certification (BR-5). Approve a submitted certification below to enable publication.',
                        style: TextStyle(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (review.draft == null)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Draft missing. Existing public content can still be deactivated.',
              ),
            ),
          if (review.draft != null && !review.targetMembershipEligible)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Current Coach membership is unavailable; publication is blocked.',
              ),
            ),
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'The server also checks current account and branch eligibility at publication.',
            ),
          ),
          const SizedBox(height: 12),
          CoachCertificationReviewPanel(
            key: ValueKey(review.coachId),
            coachId: review.coachId,
            discardGuard: _discardGuard,
            repository: context.read<CoachProfileAdminRepository>(),
            onReviewed: () => _cubit!.review(review.coachId),
          ),
          if (state.message != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: state.message!.toLowerCase().contains('failed') ||
                        state.message!.toLowerCase().contains('error') ||
                        state.message!.toLowerCase().contains('review')
                    ? Colors.red.shade50
                    : Colors.green.shade50,
                border: Border.all(
                  color: state.message!.toLowerCase().contains('failed') ||
                          state.message!.toLowerCase().contains('error') ||
                          state.message!.toLowerCase().contains('review')
                      ? Colors.red.shade200
                      : Colors.green.shade200,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    state.message!.toLowerCase().contains('failed') ||
                            state.message!.toLowerCase().contains('error') ||
                            state.message!.toLowerCase().contains('review')
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    size: 16,
                    color: state.message!.toLowerCase().contains('failed') ||
                            state.message!.toLowerCase().contains('error') ||
                            state.message!.toLowerCase().contains('review')
                        ? Colors.red.shade800
                        : Colors.green.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.message!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color:
                            state.message!.toLowerCase().contains('failed') ||
                                    state.message!.toLowerCase().contains('error') ||
                                    state.message!.toLowerCase().contains('review')
                                ? Colors.red.shade900
                                : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: !state.busy && widget.onOpenBookings != null
                    ? () =>
                        _guarded(() => widget.onOpenBookings!(review.coachId))
                    : null,
                child: const Text('View bookings'),
              ),
              OutlinedButton.icon(
                onPressed: !state.busy && widget.onOpenSchedule != null
                    ? () =>
                        _guarded(() => widget.onOpenSchedule!(review.coachId))
                    : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('View schedule'),
              ),
              FilledButton(
                onPressed: !state.busy && !state.conflict && review.canPublish
                    ? () => _guarded(
                        () => _cubit!.setStatus(CoachDirectoryAction.publish))
                    : null,
                child: state.busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Publish profile'),
              ),
              OutlinedButton(
                onPressed:
                    !state.busy && !state.conflict && review.publication != null
                        ? () => _guarded(() =>
                            _cubit!.setStatus(CoachDirectoryAction.deactivate))
                        : null,
                child: const Text('Deactivate directory profile'),
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => _guarded(() => _cubit!.review(review.coachId)),
                child: const Text('Discard and reload review'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _manage(BuildContext context, UserAccount user) {
    showRecordActionsDialog(
      context,
      title: user.name,
      subtitle: user.email,
      actions: [
        if (user.status == AccountStatus.pending)
          RecordActionItem(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            label: 'Review certifications',
            onTap: () {
              Navigator.pop(context);
              verifyCoachFlow(context, user, _refresh);
            },
          ),
        RecordActionItem(
          icon: Icons.lock_reset_rounded,
          color: AppColors.primary,
          label: 'Reset password',
          onTap: () {
            Navigator.pop(context);
            resetPasswordFlow(context, user);
          },
        ),
        if (user.status != AccountStatus.deactivated)
          RecordActionItem(
            icon: Icons.person_off_rounded,
            color: AppColors.danger,
            label: 'Deactivate coach',
            onTap: () {
              Navigator.pop(context);
              deactivateCoachFlow(context, user, _refresh);
            },
          ),
      ],
    );
  }
}

class _CoachEntry {
  const _CoachEntry(
      {required this.id,
      required this.name,
      required this.specialty,
      required this.branchIds,
      required this.statusLabel,
      required this.pending,
      this.imageUrl,
      this.rating,
      this.sessionsCompleted,
      this.feeLabel,
      this.note,
      this.onTap,
      this.actionLabel});
  final String id, name, specialty, statusLabel;
  final List<String> branchIds;
  final bool pending;
  final String? imageUrl, note, actionLabel, feeLabel;
  final double? rating;
  final int? sessionsCompleted;
  final VoidCallback? onTap;
  List<String> get groups =>
      branchIds.isEmpty ? const ['Unassigned'] : branchIds;
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({super.key, required this.entry});
  final _CoachEntry entry;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: Panel(
        onTap: entry.onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: entry.imageUrl != null && entry.imageUrl!.isNotEmpty
                        ? _networkHero(entry.imageUrl!)
                        : Container(
                            color: AppColors.accentTint,
                            child: const Icon(Icons.sports_rounded,
                                size: 18, color: AppColors.warning),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontSize: 13.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(entry.specialty,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
              const SizedBox(width: 3),
              Text(entry.rating?.toString() ?? '-',
                  style: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              Text('${entry.sessionsCompleted ?? '-'} sessions',
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft)),
            ]),
            const SizedBox(height: 4),
            Text('Fee: ${entry.feeLabel ?? '—'}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
            if (entry.note != null)
              Text(entry.note!,
                  style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.inkSoft,
                      fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                statusPill(entry.statusLabel),
                if (entry.actionLabel != null)
                  TextButton(
                      onPressed: entry.onTap, child: Text(entry.actionLabel!)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _StatChip(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
