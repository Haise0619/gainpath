import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../../infrastructure/firebase/firebase_function_transport.dart';
import '../../../../shared/admin_business_copy.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'user_action_dialogs.dart';
import '../../application/coach_directory_admin_cubit.dart';
import 'coach_certification_review_panel.dart';
import 'coach_review_discard_guard.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

Widget _networkHero(String url,
    {BoxFit fit = BoxFit.cover, WidgetBuilder? fallback}) {
  return Image.network(
    url,
    fit: fit,
    width: double.infinity,
    height: double.infinity,
    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
    loadingBuilder: (context, child, progress) =>
        progress == null ? child : Container(color: AppColors.surfaceAlt),
    errorBuilder: (context, error, stack) =>
        fallback?.call(context) ??
        const DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.heroGradient)),
  );
}

/// AD-M11.3 — Coach Management. Roster view with metrics, filtering, and
/// publication reviews.
class CoachesScreen extends StatefulWidget {
  const CoachesScreen(
      {super.key,
      this.live = false,
      this.onOpenSchedule,
      this.onOpenBookings,
      this.initialCoachId,
      this.initialCoachGeneration = 0,
      this.discardGuard,
      this.onReviewChanged});
  final String? initialCoachId;
  final int initialCoachGeneration;
  final CoachReviewDiscardGuard? discardGuard;
  final bool live;
  final void Function(String coachId)? onOpenSchedule;
  final void Function(String coachId)? onOpenBookings;
  final void Function(String? coachId)? onReviewChanged;

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  late final CoachReviewDiscardGuard _discardGuard;
  CoachDirectoryAdminCubit? _cubit;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSpecialty = 'Specialty';
  String _selectedStatus = 'Status';
  String _selectedBranch = 'Branch';
  int _activeReviewTab = 0;
  bool _showAllProfileFields = false;

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
          CoachDirectoryAdminCubit(context.read<CoachProfileAdminRepository>());
      _openInitialReview();
    }
  }

  @override
  void didUpdateWidget(covariant CoachesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCoachId != oldWidget.initialCoachId) {
      _activeReviewTab = 0;
      _showAllProfileFields = false;
      if (widget.initialCoachId != null) {
        _cubit?.review(widget.initialCoachId!);
      } else if (_cubit?.state.review != null) {
        _cubit?.clearReview();
      }
    }
  }

  Future<void> _openInitialReview() async {
    final cubit = _cubit!;
    await cubit.refresh();
    if (mounted && cubit.state.allowed && widget.initialCoachId != null) {
      _activeReviewTab = 0;
      _showAllProfileFields = false;
      await cubit.review(widget.initialCoachId!);
      if (mounted) widget.onReviewChanged?.call(cubit.state.review?.coachId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
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

  String? _resolveCoachAvatar(
      String id, String displayName, String? photoPath) {
    if (photoPath != null &&
        (photoPath.startsWith('http://') ||
            photoPath.startsWith('https://') ||
            photoPath.startsWith('data:'))) {
      return photoPath;
    }
    try {
      final repo = context.read<CoachRepository>();
      for (final c in repo.coaches) {
        if ((c.id == id ||
                c.name.toLowerCase() == displayName.toLowerCase()) &&
            c.imageUrl.isNotEmpty &&
            (c.imageUrl.startsWith('http://') ||
                c.imageUrl.startsWith('https://') ||
                c.imageUrl.startsWith('data:'))) {
          return c.imageUrl;
        }
      }
    } catch (_) {}
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
            imageUrl: _profileFor(user)?.imageUrl ??
                _resolveCoachAvatar(user.email, user.name, null),
            photoPath: null,
            rating: _profileFor(user)?.rating,
            sessionsCompleted: _profileFor(user)?.sessionsCompleted,
            feeLabel: _profileFor(user) != null && _profileFor(user)!.fee > 0
                ? 'RM ${_profileFor(user)!.fee.toStringAsFixed(2)} / session'
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
          id: id,
          actionLabel: 'Review',
          name: drafts[id]?.fields.displayName ??
              publications[id]?.fields.displayName ??
              '-',
          specialty: drafts[id]?.fields.specialty ??
              publications[id]?.fields.specialty ??
              '-',
          branchIds: state.review?.coachId == id
              ? state.review!.branchIds
              : publications[id]?.branchIds ?? const [],
          statusLabel: publications[id] == null
              ? 'Unpublished'
              : !publications[id]!.isPublished
                  ? 'Inactive'
                  : (drafts[id] != null &&
                          drafts[id]!.revision !=
                              publications[id]!.sourceRevision
                      ? 'Pending Review'
                      : 'Published'),
          pending: drafts[id] != null &&
              (publications[id] == null ||
                  drafts[id]!.revision != publications[id]!.sourceRevision),
          photoPath: drafts[id]?.fields.photoPath ??
              publications[id]?.fields.photoPath,
          imageUrl: _resolveCoachAvatar(
            id,
            drafts[id]?.fields.displayName ??
                publications[id]?.fields.displayName ??
                '',
            drafts[id]?.fields.photoPath ??
                publications[id]?.fields.photoPath,
          ),
          rating: publications[id]?.averageRating,
          reviewCount: publications[id]?.isPublished == true
              ? publications[id]!.reviewCount : null,
          feeLabel: publications[id]?.fields.consultationFeeMinor != null &&
                  publications[id]!.fields.consultationFeeMinor! > 0
              ? 'RM ${(publications[id]!.fields.consultationFeeMinor! / 100).toStringAsFixed(2)} / session'
              : (drafts[id]?.fields.consultationFeeMinor != null &&
                      drafts[id]!.fields.consultationFeeMinor! > 0
                  ? 'Draft: RM ${(drafts[id]!.fields.consultationFeeMinor! / 100).toStringAsFixed(2)} / session'
                  : '—'),
          note: drafts[id]?.fields.yearsExperience == null
              ? null
              : '${drafts[id]!.fields.yearsExperience} yrs experience',
          onTap: state.busy
              ? null
              : () => _guarded(() {
                    _cubit!.review(id);
                    widget.onReviewChanged?.call(id);
                  }),
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
    final pendingCount = coaches.where((coach) => coach.pending).length;
    final publishedCount = coaches
        .where((coach) => coach.statusLabel.toLowerCase() == 'published')
        .length;
    final inactiveCount = coaches
        .where((coach) =>
            coach.statusLabel.toLowerCase() == 'inactive' ||
            coach.statusLabel.toLowerCase() == 'unpublished')
        .length;

    var filtered = coaches.where((coach) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = coach.name.toLowerCase().contains(q);
        final matchSpecialty = coach.specialty.toLowerCase().contains(q);
        if (!matchName && !matchSpecialty) return false;
      }
      if (_selectedSpecialty != 'Specialty' && _selectedSpecialty != 'All') {
        if (!coach.specialty
            .toLowerCase()
            .contains(_selectedSpecialty.toLowerCase())) {
          return false;
        }
      }
      if (_selectedStatus != 'Status' && _selectedStatus != 'All') {
        if (coach.statusLabel.toLowerCase() != _selectedStatus.toLowerCase()) {
          return false;
        }
      }
      if (_selectedBranch != 'Branch' && _selectedBranch != 'All') {
        if (!coach.groups.contains(_selectedBranch)) return false;
      }
      return true;
    }).toList();

    final branchIds = <String>{for (final coach in filtered) ...coach.groups};

    final allBranches = <String>{
      for (final coach in coaches) ...coach.groups
    }.toList();

    final bool isReviewMode = state?.review != null;

    return Scaffold(
      key: const ValueKey('coaches-page'),
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isReviewMode) ...[
              _buildReviewView(context, state!),
              SizedBox(
                height: 0,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: 0,
                  child: Opacity(
                    opacity: 0,
                    child: FocusScope(
                      canRequestFocus: false,
                      child: IgnorePointer(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._buildDirectorySections(
                              context,
                              coaches,
                              filtered,
                              branchIds,
                              allBranches,
                              publishedCount: publishedCount,
                              pendingCount: pendingCount,
                              inactiveCount: inactiveCount,
                              state: state,
                              hideHeader: true,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              ..._buildDirectorySections(
                context,
                coaches,
                filtered,
                branchIds,
                allBranches,
                publishedCount: publishedCount,
                pendingCount: pendingCount,
                inactiveCount: inactiveCount,
                state: state,
                hideHeader: false,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDirectorySections(
    BuildContext context,
    List<_CoachEntry> coaches,
    List<_CoachEntry> filtered,
    Set<String> branchIds,
    List<String> allBranches, {
    required int publishedCount,
    required int pendingCount,
    required int inactiveCount,
    CoachDirectoryAdminState? state,
    required bool hideHeader,
  }) {
    return [
      if (!hideHeader) ...[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coach Management',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Manage coach profiles, verification, and publication status.',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
            if (state != null)
              IconButton(
                tooltip: 'Refresh Coaches',
                onPressed:
                    state.busy ? null : () => _guarded(_cubit!.refresh),
                icon: const Icon(Icons.refresh_rounded),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _StatChip(
                icon: Icons.sports_rounded,
                label: state == null
                    ? 'Total coaches'
                    : 'Total coaches (loaded)',
                value: '${coaches.length}',
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _KpiCard(
                icon: Icons.check_rounded,
                label: 'Published',
                value: '$publishedCount',
                color: AppColors.success,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _StatChip(
                icon: Icons.hourglass_top_rounded,
                label: state == null
                    ? 'Pending review'
                    : 'Pending review (loaded)',
                value: '$pendingCount',
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _KpiCard(
                icon: Icons.pause_rounded,
                label: 'Inactive',
                value: '$inactiveCount',
                color: AppColors.membershipFreeInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.hairline),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search_rounded,
                          size: 18, color: AppColors.inkSoft),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: const InputDecoration(
                            hintText:
                                'Search coaches by name or specialty...',
                            hintStyle: TextStyle(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                            filled: false,
                          ),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _selectedSpecialty = v),
                itemBuilder: (context) => [
                  'Specialty',
                  'All',
                  'Strength',
                  'Conditioning',
                  'Squat',
                  'Mobility'
                ]
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                child: _filterPill(_selectedSpecialty),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _selectedStatus = v),
                itemBuilder: (context) => [
                  'Status',
                  'All',
                  'Published',
                  'Pending Review',
                  'Inactive'
                ]
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                child: _filterPill(_selectedStatus),
              ),
              const SizedBox(width: 10),
              PopupMenuButton<String>(
                onSelected: (v) => setState(() => _selectedBranch = v),
                itemBuilder: (context) => ['Branch', 'All', ...allBranches]
                    .map((s) => PopupMenuItem(value: s, child: Text(s)))
                    .toList(),
                child: _filterPill(_selectedBranch),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: 'Reset filters',
                child: IconButton(
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.hairline),
                    ),
                  ),
                  icon: const Icon(Icons.tune_rounded,
                      size: 18, color: AppColors.inkSoft),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _selectedSpecialty = 'Specialty';
                      _selectedStatus = 'Status';
                      _selectedBranch = 'Branch';
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                key: const ValueKey('add-coach'),
                onPressed: state != null
                    ? null
                    : () => provisionCoachFlow(context, _refresh),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Coach'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (state?.loading == true) const LinearProgressIndicator(),
        if (state?.message != null) Text(state!.message!),
        if (state != null &&
            state.allowed &&
            !state.loading &&
            coaches.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('No Coach profiles are available.')),
          ),
      ],
      for (final branchId in branchIds)
        Padding(
          key: ValueKey('coach-branch-$branchId'),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (branchIds.length > 1 || branchId != 'Unassigned') ...[
                Row(
                  children: [
                    const Icon(Icons.storefront_outlined,
                        size: 15, color: AppColors.inkSoft),
                    const SizedBox(width: 6),
                    Text(
                      '$branchId  ·  ${filtered.where((coach) => coach.groups.contains(branchId)).length}',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : 1200.0;
                  final int columns;
                  if (availableWidth >= 880) {
                    columns = 4;
                  } else if (availableWidth >= 660) {
                    columns = 3;
                  } else if (availableWidth >= 440) {
                    columns = 2;
                  } else {
                    columns = 1;
                  }
                  const spacing = 16.0;
                  final cardWidth =
                      ((availableWidth - (columns - 1) * spacing) / columns)
                          .floorToDouble();
                  final branchCoaches = filtered
                      .where((coach) => coach.groups.contains(branchId))
                      .toList();

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (var i = 0; i < branchCoaches.length; i++)
                        _CoachCard(
                          key: ValueKey(
                              'coach-card-$branchId-${branchCoaches[i].id}'),
                          entry: branchCoaches[i],
                          index: i,
                          width: cardWidth,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      if (!hideHeader) ...[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Text(
                'Showing 1 – ${filtered.length} of ${coaches.length} coaches',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _paginationArrow(Icons.chevron_left_rounded, null),
              const SizedBox(width: 6),
              _paginationNumber('1', true),
              if (coaches.length > 8) ...[
                const SizedBox(width: 6),
                _paginationNumber('2', false),
              ],
              const SizedBox(width: 6),
              _paginationArrow(Icons.chevron_right_rounded, null),
            ],
          ),
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
      ],
    ];
  }

  Widget _buildReviewView(
      BuildContext context, CoachDirectoryAdminState state) {
    final review = state.review!;
    final draft = review.draft;
    final publication = review.publication;
    final displayName = draft?.fields.displayName ??
        publication?.fields.displayName ??
        'Coach ${review.coachId}';
    final specialty = draft?.fields.specialty ??
        publication?.fields.specialty ??
        'Coach';
    final photoPath = draft?.fields.photoPath ?? publication?.fields.photoPath;
    final avatarUrl =
        _resolveCoachAvatar(review.coachId, displayName, photoPath);
    final isPublished = publication?.isPublished ?? false;
    final isPending =
        draft != null && draft.revision > (publication?.sourceRevision ?? 0);
    final isVerified =
        review.certificationVerified && review.approvedCertificationCount > 0;

    // Calculate changed fields count for the Profile Changes tab badge
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Navigation bar above the header
        Row(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _guarded(() {
                _cubit?.clearReview();
                widget.onReviewChanged?.call(null);
              }),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.hairline),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back_rounded,
                        size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Back to Coaches',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh Coaches',
              onPressed:
                  state.busy ? null : () => _guarded(_cubit!.refresh),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // A. Coach Profile Header (Compact, informative summary)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _CoachAvatar(
                name: displayName,
                imageUrl: avatarUrl,
                photoPath: photoPath,
                id: review.coachId,
                width: 68,
                height: 68,
                index: 0,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          displayName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                                letterSpacing: -0.3,
                              ),
                        ),
                        Text(
                          'Review ${review.coachId}',
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.sports_rounded,
                                size: 15, color: AppColors.inkSoft),
                            const SizedBox(width: 5),
                            Text(
                              specialty,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (draft?.fields.yearsExperience != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.history_edu_rounded,
                                  size: 15, color: AppColors.inkSoft),
                              const SizedBox(width: 5),
                              Text(
                                '${draft!.fields.yearsExperience} yrs experience',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        if (review.branchIds.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.storefront_outlined,
                                  size: 15, color: AppColors.inkSoft),
                              const SizedBox(width: 5),
                              Text(
                                review.branchIds.join(', '),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Distinct publication, verification, and membership status badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _statusBadge(
                          icon: isPending
                              ? Icons.hourglass_top_rounded
                              : isPublished
                                  ? Icons.check_circle_rounded
                                  : Icons.pause_circle_rounded,
                          label: isPending
                              ? 'Pending Review'
                              : isPublished
                                  ? 'Published'
                                  : 'Inactive / Unpublished',
                          color: isPending
                              ? AppColors.warning
                              : isPublished
                                  ? AppColors.success
                                  : AppColors.inkSoft,
                        ),
                        _statusBadge(
                          icon: isVerified
                              ? Icons.verified_rounded
                              : Icons.pending_actions_rounded,
                          label: isVerified
                              ? 'Verified (${review.approvedCertificationCount} Approved)'
                              : 'Unverified (${review.approvedCertificationCount} Approved)',
                          color: isVerified
                              ? AppColors.primary
                              : AppColors.warning,
                        ),
                        _statusBadge(
                          icon: review.targetMembershipEligible
                              ? Icons.badge_outlined
                              : Icons.block_rounded,
                          label: review.targetMembershipEligible
                              ? 'Active Membership'
                              : 'Membership Ineligible',
                          color: review.targetMembershipEligible
                              ? AppColors.success
                              : Colors.red.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // B. Tab-Based Navigation
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _reviewTabItem(0, 'Overview', Icons.dashboard_outlined),
              _reviewTabItem(
                1,
                'Profile Changes',
                Icons.published_with_changes_outlined,
                badgeCount: changed.isNotEmpty ? changed.length : null,
              ),
              _reviewTabItem(
                2,
                'Certifications',
                Icons.verified_outlined,
                badgeCount: review.approvedCertificationCount > 0
                    ? review.approvedCertificationCount
                    : null,
              ),
              _reviewTabItem(3, 'Activity', Icons.history_rounded),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Active Tab Body
        if (_activeReviewTab == 0)
          _buildOverviewTab(context, review)
        else if (_activeReviewTab == 1)
          _buildProfileChangesTab(context, review, changed, proposed, published)
        else if (_activeReviewTab == 2)
          _buildCertificationsTab(context, review)
        else if (_activeReviewTab == 3)
          _buildActivityTab(context, review),

        const SizedBox(height: 16),

        // Persistent Management Actions Bar
        _buildManagementActionsBar(context, state, review),
      ],
    );
  }

  Widget _reviewTabItem(int index, String label, IconData icon,
      {int? badgeCount}) {
    final active = _activeReviewTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeReviewTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: active
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.inkSoft,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: active ? AppColors.primary : AppColors.inkSoft,
                  ),
                ),
              ),
              if (badgeCount != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primary : AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: active ? Colors.white : AppColors.inkSoft,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 3. Overview Tab: Responsive two-column layout
  Widget _buildOverviewTab(
      BuildContext context, CoachPublicationReview review) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 840;
        final leftColumn = _buildOverviewProfessionalProfile(context, review);
        final rightColumn = Column(
          children: [
            _buildOverviewPublicationEligibility(context, review),
            const SizedBox(height: 16),
            _buildOverviewRecordDetails(context, review),
          ],
        );

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: leftColumn),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: rightColumn),
            ],
          );
        } else {
          return Column(
            children: [
              leftColumn,
              const SizedBox(height: 16),
              rightColumn,
            ],
          );
        }
      },
    );
  }

  Widget _buildOverviewProfessionalProfile(
      BuildContext context, CoachPublicationReview review) {
    final draft = review.draft;
    final publication = review.publication;
    final fields = draft?.fields ?? publication?.fields;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Professional Profile',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Current profile information displayed to athletes and members',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 16),
          _overviewFieldRow(
              'Display name', fields?.displayName ?? 'Not provided'),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
              'Primary specialty', fields?.specialty ?? 'Not provided'),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
            'Experience',
            fields?.yearsExperience != null
                ? '${fields!.yearsExperience} years (self-reported)'
                : 'Not provided',
          ),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
            'Consultation fee',
            (fields?.consultationFeeMinor ?? 0) > 0
                ? 'RM ${(fields!.consultationFeeMinor! / 100).toStringAsFixed(2)} / session'
                : 'Not set — checkout unavailable',
          ),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
            'Specializations',
            (fields?.specializationTags ?? []).isNotEmpty
                ? fields!.specializationTags.join(' · ')
                : 'None provided',
          ),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
            'Assigned branches',
            review.branchIds.isNotEmpty
                ? review.branchIds.join(', ')
                : 'No branch assigned',
          ),
          const Divider(height: 18, color: AppColors.hairline),
          _overviewFieldRow(
            'Profile photo',
            fields?.photoPath != null ? 'Photo attached' : 'No photo attached',
          ),
          const SizedBox(height: 14),
          const Text(
            'Biography',
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppColors.inkSoft),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Text(
              (fields?.bio ?? '').isEmpty
                  ? 'No biography provided yet.'
                  : fields!.bio,
              style: const TextStyle(
                  fontSize: 13, height: 1.5, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPublicationEligibility(
      BuildContext context, CoachPublicationReview review) {
    final draft = review.draft;
    final publication = review.publication;
    final isPending =
        draft != null && draft.revision > (publication?.sourceRevision ?? 0);
    final isVerified =
        review.certificationVerified && review.approvedCertificationCount > 0;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rule_folder_outlined,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Publication Eligibility',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Business conditions required before publishing to directory',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.warning.withValues(alpha: 0.08)
                  : (publication?.isPublished ?? false)
                      ? AppColors.success.withValues(alpha: 0.08)
                      : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPending
                    ? AppColors.warning.withValues(alpha: 0.25)
                    : (publication?.isPublished ?? false)
                        ? AppColors.success.withValues(alpha: 0.25)
                        : AppColors.hairline,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPending
                      ? Icons.pending_actions_rounded
                      : (publication?.isPublished ?? false)
                          ? Icons.check_circle_outline
                          : Icons.info_outline,
                  size: 16,
                  color: isPending
                      ? AppColors.warning
                      : (publication?.isPublished ?? false)
                          ? AppColors.success
                          : AppColors.inkSoft,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isPending
                        ? 'Changes awaiting publication'
                        : (publication?.isPublished ?? false)
                            ? 'Published profile is up to date'
                            : 'Directory profile is inactive or unpublished',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isPending
                          ? AppColors.warning
                          : (publication?.isPublished ?? false)
                              ? AppColors.success
                              : AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _eligibilityCheckItem(
            satisfied: draft != null,
            title: 'Professional draft',
            description: draft != null
                ? 'Draft available (revision ${draft.revision})'
                : 'Draft missing. Existing public content can still be deactivated.',
          ),
          _eligibilityCheckItem(
            satisfied: review.targetMembershipEligible,
            title: 'Coach membership',
            description: review.targetMembershipEligible
                ? 'Active Coach membership with valid permissions'
                : 'Membership unavailable; publication is blocked.',
          ),
          _eligibilityCheckItem(
            satisfied: review.branchIds.isNotEmpty,
            title: 'Branch assignment',
            description: review.branchIds.isNotEmpty
                ? 'Assigned to: ${review.branchIds.join(', ')}'
                : 'No branch assigned. Required for member discovery.',
          ),
          _eligibilityCheckItem(
            satisfied: isVerified,
            title: 'Approved certifications (BR-5)',
            description: isVerified
                ? '${review.approvedCertificationCount} approved certification${review.approvedCertificationCount == 1 ? '' : 's'} · Verified (BR-5)'
                : 'Publication requires at least one approved certification (BR-5).',
            actionLabel: !isVerified ? 'Go to Certifications' : null,
            onAction:
                !isVerified ? () => setState(() => _activeReviewTab = 2) : null,
          ),
          if (draft != null && (draft.fields.consultationFeeMinor ?? 0) <= 0) ...[
            const SizedBox(height: 8),
            _eligibilityWarningBanner(
              'No valid consultation fee is set in the draft. Members will see no price and session checkout will be disabled.',
            ),
          ],
          if (draft != null &&
              publication != null &&
              draft.fields.consultationFeeMinor !=
                  publication.fields.consultationFeeMinor) ...[
            const SizedBox(height: 8),
            _eligibilityInfoBanner(
              'Publishing updates the public consultation fee. Existing bookings retain their snapshotted transaction prices.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOverviewRecordDetails(
      BuildContext context, CoachPublicationReview review) {
    final draft = review.draft;
    final publication = review.publication;

    return Panel(
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        initiallyExpanded: false,
        title: const Row(
          children: [
            Icon(Icons.terminal_outlined, size: 18, color: AppColors.inkSoft),
            SizedBox(width: 8),
            Text('Technical Record Details',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          ],
        ),
        subtitle: Text(
          'Public rev: ${review.publicRevision} · Draft rev: ${draft?.revision ?? 'none'}',
          style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
        ),
        children: [
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Coach ID: ',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w500)),
              Expanded(
                child: SelectableText(
                  review.coachId,
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded,
                    size: 16, color: AppColors.primary),
                tooltip: 'Copy ID',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: review.coachId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Coach ID "${review.coachId}" copied to clipboard.'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 12, color: AppColors.hairline),
          _detailRow('Draft revision', '${draft?.revision ?? 'missing'}'),
          _detailRow('Public revision', '${review.publicRevision}'),
          _detailRow('Published from draft',
              '${publication?.sourceRevision ?? 'Not published yet'}'),
          _detailRow(
              'Draft updated', _formatTimestamp(draft?.updatedAtMillis)),
          _detailRow('Last published',
              _formatTimestamp(publication?.publishedAtMillis)),
        ],
      ),
    );
  }

  // 4. Profile Changes Tab: Prioritizes modified fields with side-by-side comparison
  Widget _buildProfileChangesTab(
      BuildContext context,
      CoachPublicationReview review,
      Set<String> changed,
      Map<String, String>? proposed,
      Map<String, String>? published) {
    final draft = review.draft;
    final publication = review.publication;
    final bool hasUnpublishedChanges =
        changed.isNotEmpty || (draft != null && publication == null);

    if (!hasUnpublishedChanges && !_showAllProfileFields) {
      return Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded,
                      size: 36, color: AppColors.success),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your published profile is up to date. No unpublished changes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Members are viewing the latest approved information for this coach in the directory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showAllProfileFields = true),
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('Show All Fields'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final keysToDisplay = _showAllProfileFields
        ? (proposed?.keys.toList() ??
            published?.keys.toList() ??
            <String>[])
        : changed.toList();

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile Information Comparison',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasUnpublishedChanges
                          ? '${changed.length} field${changed.length == 1 ? '' : 's'} with unpublished modifications'
                          : 'All fields are currently identical',
                      style: const TextStyle(
                          color: AppColors.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(
                    () => _showAllProfileFields = !_showAllProfileFields),
                icon: Icon(
                    _showAllProfileFields
                        ? Icons.filter_alt_off_outlined
                        : Icons.filter_alt_outlined,
                    size: 15),
                label: Text(_showAllProfileFields
                    ? 'Show modified only'
                    : 'Show all fields'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final key in keysToDisplay) ...[
            _buildFieldComparisonCard(
              field: key,
              oldValue: published?[key],
              newValue: proposed?[key],
              isModified: changed.contains(key),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildFieldComparisonCard({
    required String field,
    required String? oldValue,
    required String? newValue,
    required bool isModified,
  }) {
    final isAdded = oldValue == null && newValue != null;
    final chipColor = isModified
        ? AppColors.primary
        : isAdded
            ? AppColors.success
            : AppColors.inkSoft;
    final chipLabel = isModified
        ? 'Modified'
        : isAdded
            ? 'Added'
            : 'Unchanged';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isModified
            ? AppColors.primary.withValues(alpha: 0.025)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isModified
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                field,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                  color: isModified ? AppColors.primary : AppColors.ink,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: chipColor.withValues(alpha: 0.25)),
                ),
                child: Text(
                  chipLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Published (Current)',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: Text(
                        oldValue ?? 'Not set',
                        style: TextStyle(
                          fontSize: 13,
                          color: oldValue == null
                              ? AppColors.inkSoft
                              : (isModified ? AppColors.inkSoft : AppColors.ink),
                          decoration: isModified && oldValue != null
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Draft (Proposed)',
                      style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isModified
                            ? AppColors.primary.withValues(alpha: 0.06)
                            : AppColors.surfaceAlt.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isModified
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.hairline,
                        ),
                      ),
                      child: Text(
                        newValue ?? 'Not set',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isModified ? FontWeight.w600 : FontWeight.normal,
                          color: isModified
                              ? AppColors.ink
                              : (newValue == null
                                  ? AppColors.inkSoft
                                  : AppColors.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 5. Certifications Tab: Individual credential cards with review actions
  Widget _buildCertificationsTab(
      BuildContext context, CoachPublicationReview review) {
    return Panel(
      child: CoachCertificationReviewPanel(
        key: ValueKey(review.coachId),
        coachId: review.coachId,
        discardGuard: _discardGuard,
        repository: context.read<CoachProfileAdminRepository>(),
        onReviewed: () => _cubit!.review(review.coachId),
      ),
    );
  }

  // 6. Activity Tab: Chronological log of real administrative and publication events
  Widget _buildActivityTab(
      BuildContext context, CoachPublicationReview review) {
    final draft = review.draft;
    final publication = review.publication;

    final events = <_ActivityEvent>[];

    if (publication?.publishedAtMillis != null) {
      events.add(_ActivityEvent(
        title: 'Profile Published to Directory',
        subtitle:
            'Public revision ${review.publicRevision} active for members (source revision ${publication!.sourceRevision})',
        timestamp: publication.publishedAtMillis,
        icon: Icons.public_rounded,
        color: AppColors.success,
      ));
    }

    if (publication?.updatedAtMillis != null &&
        publication!.updatedAtMillis != publication.publishedAtMillis) {
      events.add(_ActivityEvent(
        title: 'Publication Record Updated',
        subtitle: 'Directory listing status updated to "${publication.status}"',
        timestamp: publication.updatedAtMillis,
        icon: Icons.sync_alt_rounded,
        color: AppColors.primary,
      ));
    }

    if (draft?.updatedAtMillis != null) {
      events.add(_ActivityEvent(
        title: 'Draft Profile Revised',
        subtitle: 'Draft changes updated to revision ${draft!.revision}',
        timestamp: draft.updatedAtMillis,
        icon: Icons.edit_note_rounded,
        color: AppColors.warning,
      ));
    }

    if (draft?.createdAtMillis != null) {
      events.add(_ActivityEvent(
        title: 'Professional Draft Created',
        subtitle: 'Initial profile setup completed by coach',
        timestamp: draft!.createdAtMillis,
        icon: Icons.person_add_outlined,
        color: AppColors.inkSoft,
      ));
    }

    events.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    if (events.isEmpty) {
      return Panel(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceAlt,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.history_toggle_off_rounded,
                      size: 36, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No administrative activity recorded yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Historical timestamps will appear here as reviews and publication actions are taken.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded,
                  size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Activity & Publication History',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Chronological log of administrative decisions, publication updates, and profile revisions',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < events.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: events[i].color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: events[i].color.withValues(alpha: 0.3)),
                      ),
                      child: Icon(events[i].icon,
                          size: 16, color: events[i].color),
                    ),
                    if (i < events.length - 1)
                      Container(
                        width: 2,
                        height: 36,
                        color: AppColors.hairline,
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              events[i].title,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                  color: AppColors.ink),
                            ),
                            Text(
                              _formatTimestamp(events[i].timestamp),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          events[i].subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (review.operationalSummary.isNotEmpty) ...[
            const Divider(height: 24, color: AppColors.hairline),
            const Text(
              'Operational Notes',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.inkSoft),
            ),
            const SizedBox(height: 8),
            for (final summary in review.operationalSummary)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${adminBusinessDetail(summary)}',
                  style:
                      const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // 7. Management Actions Bar: Distinct routine, publishing, and high-risk groupings
  Widget _buildManagementActionsBar(BuildContext context,
      CoachDirectoryAdminState state, CoachPublicationReview review) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.conflict) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This review is out of date. Discard and reload before making another publication change.',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (review.readOnly) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Read-only profile. Credential records are supplied for educational review and do not establish external professional verification.',
                style: TextStyle(
                    color: AppColors.inkSoft, fontStyle: FontStyle.italic),
              ),
            ),
          ],
          if (state.message != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                borderRadius: BorderRadius.circular(8),
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
                        color: state.message!
                                    .toLowerCase()
                                    .contains('failed') ||
                                state.message!
                                    .toLowerCase()
                                    .contains('error') ||
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
          Wrap(
            spacing: 12,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                onPressed: !state.busy && widget.onOpenBookings != null
                    ? () => _guarded(
                        () => widget.onOpenBookings!(review.coachId))
                    : null,
                child: const Text('View bookings'),
              ),
              OutlinedButton.icon(
                onPressed: !state.busy && widget.onOpenSchedule != null
                    ? () => _guarded(
                        () => widget.onOpenSchedule!(review.coachId))
                    : null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('View schedule'),
              ),
              TextButton(
                onPressed: state.busy
                    ? null
                    : () => _guarded(
                        () => _cubit!.review(review.coachId)),
                child: const Text('Discard and reload review'),
              ),
              OutlinedButton(
                onPressed: !review.readOnly &&
                        !state.busy &&
                        !state.conflict &&
                        review.publication != null
                    ? () => _guarded(() => _cubit!
                        .setStatus(CoachDirectoryAction.deactivate))
                    : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
                child: const Text('Deactivate directory profile'),
              ),
              Tooltip(
                message: review.canPublish &&
                        !review.hasPublishableChanges
                    ? 'Published profile is already up to date'
                    : !review.canPublish
                        ? 'Publication requires draft and at least one approved certification (BR-5)'
                        : '',
                child: FilledButton(
                  onPressed: !state.busy &&
                          !state.conflict &&
                          review.canPublish &&
                          review.hasPublishableChanges
                      ? () => _guarded(() => _cubit!
                          .setStatus(CoachDirectoryAction.publish))
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  child: state.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Publish profile'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewFieldRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.inkSoft,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _eligibilityCheckItem({
    required bool satisfied,
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: satisfied
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              satisfied
                  ? Icons.check_circle_rounded
                  : Icons.warning_amber_rounded,
              size: 18,
              color: satisfied ? AppColors.success : AppColors.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: satisfied ? AppColors.ink : AppColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onAction,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded,
                              size: 12, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _eligibilityWarningBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.warning, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eligibilityInfoBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(int? value) {
    if (value == null) return 'Not available';
    final dt = DateTime.fromMillisecondsSinceEpoch(value).toLocal();
    final y = dt.year;
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  static Map<String, String> _fields(CoachProfessionalFields value) => {
        'Display name': value.displayName,
        'Primary specialty': value.specialty,
        'Biography': value.bio.isEmpty ? 'Not provided' : value.bio,
        'Specializations': value.specializationTags.isEmpty
            ? 'None provided'
            : value.specializationTags.join(' · '),
        'Experience': value.yearsExperience == null
            ? 'Not provided'
            : '${value.yearsExperience} years (self-reported)',
        'Consultation fee': (value.consultationFeeMinor ?? 0) > 0
            ? 'RM ${(value.consultationFeeMinor! / 100).toStringAsFixed(2)} / session'
            : 'Not set — checkout unavailable',
        'Profile photo':
            value.photoPath == null ? 'No photo attached' : 'Photo attached',
      };

  Widget _statusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterPill(String text) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.keyboard_arrow_down_rounded,
              size: 16, color: AppColors.inkSoft),
        ],
      ),
    );
  }

  Widget _paginationArrow(IconData icon, VoidCallback? onTap) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Icon(icon, size: 16, color: AppColors.inkSoft),
    );
  }

  Widget _paginationNumber(String text, bool active) {
    return Container(
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? AppColors.primary : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: active ? AppColors.primary : AppColors.hairline),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: active ? Colors.white : AppColors.ink,
        ),
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
      this.photoPath,
      this.rating,
      this.reviewCount,
      this.sessionsCompleted,
      this.feeLabel,
      this.note,
      this.onTap,
      this.actionLabel});
  final String id, name, specialty, statusLabel;
  final List<String> branchIds;
  final bool pending;
  final String? imageUrl, photoPath, note, actionLabel, feeLabel;
  final double? rating;
  final int? reviewCount;
  final int? sessionsCompleted;
  final VoidCallback? onTap;
  List<String> get groups =>
      branchIds.isEmpty ? const ['Unassigned'] : branchIds;
}

List<String> _tagsForSpecialty(String specialty) {
  final s = specialty.toLowerCase();
  final tags = <String>[];
  if (s.contains('strength')) tags.add('Strength');
  if (s.contains('conditioning') || s.contains('hiit')) tags.add('HIIT');
  if (s.contains('squat') || s.contains('leg') || s.contains('lower')) {
    tags.add('Lower Body');
  }
  if (s.contains('push-up') ||
      s.contains('curl') ||
      s.contains('arm') ||
      s.contains('upper')) {
    tags.add('Upper Body');
  }
  if (s.contains('mobility') || s.contains('flexibility')) tags.add('Mobility');
  if (s.contains('beginner') || s.contains('foundation')) {
    tags.add('Foundations');
  }
  if (s.contains('technique') || s.contains('control')) tags.add('Technique');
  if (tags.isEmpty) {
    final parts = specialty
        .split(RegExp(r'[,&/]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '-');
    tags.addAll(parts.take(2));
  }
  if (tags.isEmpty) tags.add('General');
  return tags.take(2).toList();
}

class _CoachAvatar extends StatefulWidget {
  const _CoachAvatar({
    required this.name,
    required this.id,
    this.imageUrl,
    this.photoPath,
    this.index = 0,
    this.width = 78,
    this.height = 130,
  });

  final String name;
  final String id;
  final String? imageUrl;
  final String? photoPath;
  final int index;
  final double width;
  final double height;

  @override
  State<_CoachAvatar> createState() => _CoachAvatarState();
}

class _CoachAvatarState extends State<_CoachAvatar> {
  static final Map<String, String> _urlCache = {};
  String? _effectiveUrl;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _CoachAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl ||
        oldWidget.photoPath != widget.photoPath ||
        oldWidget.id != widget.id) {
      _resolve();
    }
  }

  void _resolve() {
    final direct = widget.imageUrl;
    if (direct != null &&
        direct.isNotEmpty &&
        (direct.startsWith('http://') ||
            direct.startsWith('https://') ||
            direct.startsWith('data:'))) {
      _effectiveUrl = direct;
      return;
    }

    final path = widget.photoPath;
    if (path != null &&
        (path.startsWith('http://') ||
            path.startsWith('https://') ||
            path.startsWith('data:'))) {
      _effectiveUrl = path;
      return;
    }

    final cacheKey = (path != null && path.isNotEmpty) ? path : widget.id;
    if (_urlCache.containsKey(cacheKey)) {
      _effectiveUrl = _urlCache[cacheKey];
      return;
    }

    _loadFromFirebase(path, widget.id, cacheKey);
  }

  Future<void> _loadFromFirebase(
      String? path, String coachId, String cacheKey) async {
    String? resolved;

    // 1. Resolve photo from Firebase Storage if path is provided
    if (path != null && path.isNotEmpty) {
      try {
        resolved = await FirebaseStorage.instance.ref(path).getDownloadURL();
      } catch (_) {}
    }

    // 2. Fallback to getCoachPublishedPhotoCommand callable
    if (resolved == null && coachId.isNotEmpty) {
      try {
        final result =
            await firebaseCallable('getCoachPublishedPhotoCommand').call({
          'schemaVersion': 1,
          'organizationId': 'gainpath',
          'coachId': coachId,
        });
        final data = Map<String, dynamic>.from(result.data as Map);
        final encoded = data['bytesBase64'];
        final contentType = data['contentType'] ?? 'image/jpeg';
        if (encoded is String && encoded.isNotEmpty) {
          resolved = 'data:$contentType;base64,$encoded';
        }
      } catch (_) {}
    }

    if (resolved != null) {
      _urlCache[cacheKey] = resolved;
      if (mounted) {
        setState(() => _effectiveUrl = resolved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const pastelBgs = [
      Color(0xFFEDE9FE), // Soft purple
      Color(0xFFFEF3C7), // Warm amber/yellow
      Color(0xFFE0F2FE), // Sky blue
      Color(0xFFDCFCE7), // Mint green
      Color(0xFFFCE7F3), // Soft pink
      Color(0xFFF3E8FF), // Lavender
    ];
    final bg = pastelBgs[widget.index % pastelBgs.length];
    final initial = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : 'C';

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: _effectiveUrl != null && _effectiveUrl!.isNotEmpty
            ? _networkHero(_effectiveUrl!, fallback: (_) => _fallback(initial))
            : _fallback(initial),
      ),
    );
  }

  Widget _fallback(String initial) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Icon(
            Icons.fitness_center_rounded,
            size: 12,
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({
    super.key,
    required this.entry,
    this.index = 0,
    this.width,
  });
  final _CoachEntry entry;
  final int index;
  final double? width;

  Widget _statusBadge(String rawStatus) {
    final status = rawStatus.toLowerCase();
    Color bg;
    Color fg;
    Color border;
    IconData icon;
    String label;

    if (status == 'published') {
      bg = const Color(0xFFEBFDF2);
      fg = const Color(0xFF16A34A);
      border = const Color(0xFFBBF7D0);
      icon = Icons.check_rounded;
      label = 'Published';
    } else if (status == 'inactive') {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      border = const Color(0xFFE2E8F0);
      icon = Icons.pause_rounded;
      label = 'Inactive';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
      border = const Color(0xFFFDE68A);
      icon = Icons.hourglass_top_rounded;
      label = 'Pending Review';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3.5),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tags = _tagsForSpecialty(entry.specialty);

    return Container(
      width: width ?? 328,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CoachAvatar(
                  name: entry.name,
                  id: entry.id,
                  imageUrl: entry.imageUrl,
                  photoPath: entry.photoPath,
                  index: index,
                  width: 78,
                  height: 130,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.specialty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final tag in tags.take(2))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(5),
                                    border:
                                        Border.all(color: AppColors.hairline),
                                  ),
                                  child: Text(
                                    tag,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded,
                                  size: 12.5, color: AppColors.accent),
                              const SizedBox(width: 2),
                              Text(
                                entry.rating?.toStringAsFixed(1) ?? '—',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  entry.reviewCount != null
                                      ? '(${entry.reviewCount} ${entry.reviewCount == 1 ? 'review' : 'reviews'})'
                                      : entry.sessionsCompleted != null
                                          ? '${entry.sessionsCompleted} sessions'
                                          : 'No rating',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.calendar_today_outlined,
                                  size: 11, color: AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.note ?? '— yrs experience',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined,
                                  size: 11.5, color: AppColors.inkSoft),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  entry.feeLabel ?? '—',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.hairline),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              _statusBadge(entry.statusLabel),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(
                          color: AppColors.hairline, width: 1.1),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    onPressed: () => _showCoachProfileDialog(context, entry),
                    child: const Text(
                      'View Profile',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 28),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                    onPressed: entry.onTap,
                    child: Text(
                      entry.actionLabel ?? 'Manage',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showCoachProfileDialog(BuildContext context, _CoachEntry coach) {
  showDialog(
    context: context,
    builder: (dialogCtx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CoachAvatar(
                    name: coach.name,
                    id: coach.id,
                    imageUrl: coach.imageUrl,
                    photoPath: coach.photoPath,
                    width: 80,
                    height: 100,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          coach.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          coach.specialty,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            for (final tag in _tagsForSpecialty(coach.specialty))
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.inkSoft,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1, color: AppColors.hairline),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogInfoTile(
                      label: 'Experience',
                      value: coach.note ?? '—',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogInfoTile(
                      label: 'Rate / Session',
                      value: coach.feeLabel ?? '—',
                      icon: Icons.payments_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DialogInfoTile(
                      label: 'Rating',
                      value: '★ ${coach.rating ?? 5.0}',
                      icon: Icons.star_rounded,
                      iconColor: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DialogInfoTile(
                label: 'Branches',
                value: coach.groups.join(', '),
                icon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.hairline),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Close'),
                  ),
                  if (coach.onTap != null) ...[
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        coach.onTap!();
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(coach.actionLabel ?? 'Manage'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DialogInfoTile extends StatelessWidget {
  const _DialogInfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor ?? AppColors.inkSoft),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _KpiCard(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: c),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEvent {
  const _ActivityEvent({
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final int timestamp;
  final IconData icon;
  final Color color;
}
