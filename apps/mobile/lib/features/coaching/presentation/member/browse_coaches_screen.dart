import 'package:gainpath_domain/membership.dart';
import '../../../../navigation/membership_access_gate.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'booking_schedule_screen.dart';
import '../../../../presentation/shared/coach_profile_screen.dart';
import '../shared/live_coach_directory_views.dart';
import '../../../../presentation/shared/published_coach_presentation.dart';
import '../shared/member_coach_presentation.dart';
import '../../application/coach_directory_cubit.dart';
import 'widgets/coach_card.dart';
import 'free_coaches_preview.dart';

enum _SortBy { rating, priceLow, experience }

class BrowseCoachesScreen extends StatefulWidget {
  const BrowseCoachesScreen(
      {super.key,
      this.live = false,
      this.liveRepository,
      this.isCurrent,
      this.onOpenPublished,
      this.bookingsBuilder,
      this.onMessages,
      this.enforceMembership = false,
      this.membershipAccessRepository,
      this.loadSelectedBranch,
      this.loadBranches,
      this.onOpenGroupClasses});
  final bool live;
  final CoachDirectoryRepository? liveRepository;
  final bool Function()? isCurrent;
  final void Function(String)? onOpenPublished;
  final WidgetBuilder? bookingsBuilder;
  final bool enforceMembership;
  final MembershipAccessRepository? membershipAccessRepository;
  final VoidCallback? onMessages;
  final Future<String?> Function()? loadSelectedBranch;
  final Future<Map<String, String>> Function()? loadBranches;
  final VoidCallback? onOpenGroupClasses;
  @override
  State<BrowseCoachesScreen> createState() => _BrowseCoachesScreenState();
}

class _BrowseCoachesScreenState extends State<BrowseCoachesScreen> {
  String _specialtyFilter = 'All';
  _SortBy _sortBy = _SortBy.rating;
  final _searchController = TextEditingController();
  String _query = '';
  String? _selectedBranch;
  Map<String, String> _branchNames = {};
  bool _filterBranch = false;
  int _branchRead = 0;
  CoachDirectoryCubit? _directory;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    final read = ++_branchRead;
    _loadBranches(read);
    final loader = widget.loadSelectedBranch;
    if (loader != null) {
      _loadBranch(loader, read);
    }
    if (widget.liveRepository != null) {
      _directory = CoachDirectoryCubit(
          repository: widget.liveRepository!,
          loadAllPages: widget.loadBranches != null,
          isCurrent: () => widget.isCurrent?.call() == true)
        ..refresh();
    }
  }

  Future<void> _loadBranches(int read) async {
    try {
      final names = await widget.loadBranches?.call();
      if (names != null &&
          mounted &&
          read == _branchRead &&
          widget.isCurrent?.call() == true) {
        setState(() => _branchNames = names);
      }
    } catch (_) {/* Keep the directory usable. */}
  }

  Future<void> _loadBranch(Future<String?> Function() loader, int read) async {
    try {
      final branch = await loader();
      if (mounted && read == _branchRead && widget.isCurrent?.call() == true) {
        setState(() {
          _selectedBranch = branch;
          _filterBranch = branch != null;
        });
      }
    } catch (_) {
      // Directory remains usable if the branch preference cannot load.
    }
  }

  @override
  void didUpdateWidget(covariant BrowseCoachesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The normal composition may create a new adapter during an inherited
    // rebuild. Scope changes invalidate private state; adapter identity does not.
    if (widget.liveRepository?.scope != oldWidget.liveRepository?.scope ||
        widget.live != oldWidget.live) {
      _directory?.invalidate();
      _directory?.close();
      _directory = null;
      _searchController.clear();
      _query = '';
      _selectedBranch = null;
      _branchNames = {};
      _filterBranch = false;
      _specialtyFilter = 'All';
      _bind();
    }
  }

  @override
  void dispose() {
    _directory?.close();
    _searchController.dispose();
    super.dispose();
  }

  void _clear() => setState(() {
        _query = '';
        _searchController.clear();
        _specialtyFilter = 'All';
        _sortBy = _SortBy.rating;
        _filterBranch = false;
        _selectedBranch = '';
      });

  void _openMyBookings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (routeContext) {
          final isDark = Theme.of(routeContext).brightness == Brightness.dark;
          final colors = Theme.of(routeContext).colorScheme;
          final validSession = !widget.live || widget.isCurrent?.call() == true;
          final content = widget.bookingsBuilder?.call(routeContext) ??
              (widget.live
                  ? const Center(
                      child: Text('Bookings unavailable in this view.'))
                  : BookingScheduleScreen(
                      embedded: true,
                      onFindCoach: () => Navigator.of(routeContext).maybePop(),
                    ));
          return Scaffold(
            backgroundColor: isDark ? colors.surface : const Color(0xFFF8F7FC),
            appBar: AppBar(
              backgroundColor: isDark ? colors.surface : AppColors.surface,
              foregroundColor: isDark ? colors.onSurface : AppColors.ink,
              elevation: 0,
              scrolledUnderElevation: 0,
              title: const Text('My Bookings'),
            ),
            body: SafeArea(
              top: false,
              child: !validSession
                  ? const Center(
                      child: Text('Bookings unavailable for this session.'))
                  : NotificationListener<SwitchToFindCoachNotification>(
                      onNotification: (_) {
                        Navigator.of(routeContext).maybePop();
                        return true;
                      },
                      child: content,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickAccess(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);
    final border = colors.brightness == Brightness.dark
        ? colors.outlineVariant
        : AppColors.hairline;
    Widget tile(String label, IconData icon, Key key, VoidCallback action) =>
        Expanded(
          child: Semantics(
            button: true,
            child: InkWell(
              key: key,
              onTap: action,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 15),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: colors.primary, size: 24),
                    const SizedBox(height: 8),
                    Text(label,
                        textAlign: TextAlign.center,
                        style: text.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colors.onSurface)),
                  ],
                ),
              ),
            ),
          ),
        );
    final classes = widget.onOpenGroupClasses;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          tile('My Bookings', Icons.calendar_today_outlined,
              const Key('coaches-my-bookings-button'), _openMyBookings),
          if (classes != null) ...[
            VerticalDivider(width: 1, indent: 12, endIndent: 12, color: border),
            tile('Group Classes', Icons.groups_outlined,
                const Key('coaches-group-classes-entry'), classes),
          ],
        ]),
      ),
    );
  }

  Future<void> _filters(List<String> specialties) async {
    var selectedBranch = _filterBranch ? (_selectedBranch ?? '') : '';
    var filterBranch = _filterBranch;
    var specialty = _specialtyFilter;
    var sort = _sortBy;
    final result = await showModalBottomSheet<
            ({
              String? branch,
              bool filterBranch,
              String specialty,
              _SortBy sort
            })>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (context) => StatefulBuilder(builder: (context, update) {
              final colors = Theme.of(context).colorScheme;
              final text = memberCoachTypography(context);
              final isLocActive = filterBranch && selectedBranch.isNotEmpty;
              final isSpecActive = specialty != 'All';
              final isSortActive = sort != _SortBy.rating;
              final activeCount = (isLocActive ? 1 : 0) +
                  (isSpecActive ? 1 : 0) +
                  (isSortActive ? 1 : 0);
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.85,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    'Filter and sort',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: colors.onSurface,
                                    ),
                                  ),
                                  if (activeCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colors.primary
                                            .withValues(alpha: .12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$activeCount active',
                                        style: TextStyle(
                                          color: colors.primary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close filters',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, thickness: 1),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_branchNames.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 18, color: colors.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Training location',
                                        style: text.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Select your preferred gym branch',
                                  style: text.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('All branches'),
                                      selected: !filterBranch ||
                                          selectedBranch.isEmpty,
                                      onSelected: (_) => update(() {
                                        selectedBranch = '';
                                        filterBranch = false;
                                      }),
                                      selectedColor: colors.primary,
                                      checkmarkColor: colors.onPrimary,
                                      backgroundColor: colors
                                          .surfaceContainerHighest
                                          .withValues(alpha: .35),
                                      side: BorderSide(
                                        color: (!filterBranch ||
                                                selectedBranch.isEmpty)
                                            ? colors.primary
                                            : colors.outlineVariant
                                                .withValues(alpha: .5),
                                      ),
                                      labelStyle: text.labelLarge?.copyWith(
                                        fontWeight: (!filterBranch ||
                                                selectedBranch.isEmpty)
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: (!filterBranch ||
                                                selectedBranch.isEmpty)
                                            ? colors.onPrimary
                                            : colors.onSurface,
                                      ),
                                    ),
                                    for (final branch in _branchNames.entries)
                                      ChoiceChip(
                                        label: Text(branch.value),
                                        selected: filterBranch &&
                                            selectedBranch == branch.key,
                                        onSelected: (_) => update(() {
                                          if (filterBranch &&
                                              selectedBranch == branch.key) {
                                            selectedBranch = '';
                                            filterBranch = false;
                                          } else {
                                            selectedBranch = branch.key;
                                            filterBranch = true;
                                          }
                                        }),
                                        selectedColor: colors.primary,
                                        checkmarkColor: colors.onPrimary,
                                        backgroundColor: colors
                                            .surfaceContainerHighest
                                            .withValues(alpha: .35),
                                        side: BorderSide(
                                          color: (filterBranch &&
                                                  selectedBranch == branch.key)
                                              ? colors.primary
                                              : colors.outlineVariant
                                                  .withValues(alpha: .5),
                                        ),
                                        labelStyle: text.labelLarge?.copyWith(
                                          fontWeight: (filterBranch &&
                                                  selectedBranch == branch.key)
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: (filterBranch &&
                                                  selectedBranch == branch.key)
                                              ? colors.onPrimary
                                              : colors.onSurface,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                              ],
                              Row(
                                children: [
                                  Icon(Icons.category_outlined,
                                      size: 18, color: colors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Specialty',
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Filter by coaching focus area',
                                style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: specialties.map((s) {
                                  final isSelected = specialty == s;
                                  return ChoiceChip(
                                    label: Text(s),
                                    selected: isSelected,
                                    onSelected: (_) => update(() {
                                      specialty = (isSelected && s != 'All')
                                          ? 'All'
                                          : s;
                                    }),
                                    selectedColor: colors.primary,
                                    checkmarkColor: colors.onPrimary,
                                    backgroundColor: colors
                                        .surfaceContainerHighest
                                        .withValues(alpha: .35),
                                    side: BorderSide(
                                      color: isSelected
                                          ? colors.primary
                                          : colors.outlineVariant
                                              .withValues(alpha: .5),
                                    ),
                                    labelStyle: text.labelLarge?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? colors.onPrimary
                                          : colors.onSurface,
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 24),
                              Row(
                                children: [
                                  Icon(Icons.sort_rounded,
                                      size: 18, color: colors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Sort by',
                                      style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Choose how coaches are ordered in the directory',
                                style: text.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 12),
                              RadioGroup<_SortBy>(
                                groupValue: sort,
                                onChanged: (val) {
                                  if (val != null) {
                                    update(() => sort = val);
                                  }
                                },
                                child: Column(
                                  children: _SortBy.values.map((option) {
                                    final isSelected = sort == option;
                                    final (title, subtitle, icon) =
                                        switch (option) {
                                      _SortBy.rating => (
                                          'Highest rated',
                                          'Top rated coaches first',
                                          Icons.star_rounded,
                                        ),
                                      _SortBy.priceLow => (
                                          'Price: low to high',
                                          'Most affordable session fees first',
                                          Icons.payments_outlined,
                                        ),
                                      _SortBy.experience => (
                                          'Most experienced',
                                          'Coaches with highest years in practice',
                                          Icons.workspace_premium_outlined,
                                        ),
                                    };
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: InkWell(
                                        onTap: () =>
                                            update(() => sort = option),
                                        borderRadius: BorderRadius.circular(14),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? colors.primary
                                                    .withValues(alpha: .06)
                                                : colors.surface,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: isSelected
                                                  ? colors.primary
                                                  : colors.outlineVariant
                                                      .withValues(alpha: .4),
                                              width: isSelected ? 1.5 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? colors.primary
                                                          .withValues(
                                                              alpha: .12)
                                                      : colors
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                              alpha: .5),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  icon,
                                                  size: 20,
                                                  color: isSelected
                                                      ? colors.primary
                                                      : colors.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      title,
                                                      style: text.bodyMedium
                                                          ?.copyWith(
                                                        fontWeight: isSelected
                                                            ? FontWeight.w700
                                                            : FontWeight.w600,
                                                        color: isSelected
                                                            ? colors.primary
                                                            : colors.onSurface,
                                                      ),
                                                    ),
                                                    Text(
                                                      subtitle,
                                                      style: text.bodySmall
                                                          ?.copyWith(
                                                        color: colors
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Radio<_SortBy>(
                                                value: option,
                                                activeColor: colors.primary,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.primary.withValues(alpha: .05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        colors.primary.withValues(alpha: .12),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(Icons.info_outline_rounded,
                                        size: 18, color: colors.primary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        'Search and sorting apply to loaded coaches. Load more results to include more coaches.',
                                        style: text.bodySmall?.copyWith(
                                          color: colors.onSurfaceVariant,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          border: Border(
                            top: BorderSide(
                              color:
                                  colors.outlineVariant.withValues(alpha: .3),
                            ),
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final textScale =
                                MediaQuery.textScalerOf(context).scale(14);
                            final isNarrowOrLargeText =
                                constraints.maxWidth < 280 || textScale > 18;
                            if (isNarrowOrLargeText) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      (
                                        branch: selectedBranch,
                                        filterBranch: filterBranch,
                                        specialty: specialty,
                                        sort: sort,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Apply Filters'),
                                  ),
                                  const SizedBox(height: 8),
                                  OutlinedButton(
                                    onPressed: () => update(() {
                                      selectedBranch = '';
                                      filterBranch = false;
                                      specialty = 'All';
                                      sort = _SortBy.rating;
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Reset All'),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => update(() {
                                      selectedBranch = '';
                                      filterBranch = false;
                                      specialty = 'All';
                                      sort = _SortBy.rating;
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Reset All'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => Navigator.pop(
                                      context,
                                      (
                                        branch: selectedBranch,
                                        filterBranch: filterBranch,
                                        specialty: specialty,
                                        sort: sort,
                                      ),
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: colors.primary,
                                      foregroundColor: colors.onPrimary,
                                      minimumSize: const Size(0, 48),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('Apply Filters'),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }));
    if (result != null && mounted) {
      setState(() {
        _selectedBranch = result.branch;
        _filterBranch = result.filterBranch;
        _specialtyFilter = result.specialty;
        _sortBy = result.sort;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_directory != null) {
      return BlocBuilder<CoachDirectoryCubit, CoachDirectoryState>(
          bloc: _directory,
          builder: (context, state) => _content(
              context,
              widget.isCurrent?.call() == true
                  ? state.items.map(publishedCoachPresentation).toList()
                  : [],
              state));
    }
    return _content(context,
        widget.live ? [] : context.read<CoachRepository>().coaches, null);
  }

  Widget _content(
      BuildContext context, List<Coach> coaches, CoachDirectoryState? state) {
    final colors = Theme.of(context).colorScheme;
    final text = memberCoachTypography(context);
    final current = (!widget.live || widget.isCurrent?.call() == true) &&
        state?.message != 'Coach directory unavailable for this session.';
    final published = {
      for (final p in state?.items ?? <PublishedCoachProfile>[]) p.id: p
    };
    final specialties = [
      'All',
      ...{for (final c in coaches) c.specialty}
    ];
    final isBranchActive =
        _filterBranch && _selectedBranch != null && _selectedBranch!.isNotEmpty;
    final isSpecialtyActive = _specialtyFilter != 'All';
    final isSortActive = _sortBy != _SortBy.rating;
    final activeFilterCount = (isBranchActive ? 1 : 0) +
        (isSpecialtyActive ? 1 : 0) +
        (isSortActive ? 1 : 0);
    final hasNarrowingFilters =
        _query.trim().isNotEmpty || isSpecialtyActive || isBranchActive;
    final visible = coaches.where((c) {
      final q = _query.trim().toLowerCase();
      return (!_filterBranch ||
              published[c.id]?.branchIds.contains(_selectedBranch) == true) &&
          (_specialtyFilter == 'All' || c.specialty == _specialtyFilter) &&
          (q.isEmpty ||
              c.name.toLowerCase().contains(q) ||
              c.specialty.toLowerCase().contains(q) ||
              c.specializationTags.any((t) => t.toLowerCase().contains(q)));
    }).toList();
    int compareUnknownLast(num? a, num? b, {bool descending = false}) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return descending ? b.compareTo(a) : a.compareTo(b);
    }

    visible.sort((a, b) {
      final int result;
      switch (_sortBy) {
        case _SortBy.rating:
          result = compareUnknownLast(
              published[a.id]?.averageRating ??
                  (a.reviews > 0 ? a.rating : null),
              published[b.id]?.averageRating ??
                  (b.reviews > 0 ? b.rating : null),
              descending: true);
        case _SortBy.priceLow:
          result = compareUnknownLast(memberCoachFeeMinor(a, published[a.id]),
              memberCoachFeeMinor(b, published[b.id]));
        case _SortBy.experience:
          result = compareUnknownLast(
              published.containsKey(a.id)
                  ? published[a.id]!.fields.yearsExperience
                  : a.yearsExperience,
              published.containsKey(b.id)
                  ? published[b.id]!.fields.yearsExperience
                  : b.yearsExperience,
              descending: true);
      }
      if (result != 0) return result;
      final nameOrder = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return nameOrder != 0 ? nameOrder : a.id.compareTo(b.id);
    });
    Widget status(IconData icon, String title, String description,
            {bool retry = false, bool clear = false}) =>
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, size: 40, color: colors.primary),
              const SizedBox(height: 14),
              Text(title,
                  textAlign: TextAlign.center,
                  style: text.titleMedium?.copyWith(color: colors.onSurface)),
              const SizedBox(height: 8),
              Text(description,
                  textAlign: TextAlign.center,
                  style: text.bodyMedium
                      ?.copyWith(color: colors.onSurfaceVariant)),
              if (retry)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: OutlinedButton(
                        onPressed: _directory?.refresh,
                        child: const Text('Try again'))),
              if (clear)
                Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: OutlinedButton(
                        onPressed: _clear, child: const Text('Clear filters'))),
            ]));
    Widget discovery(Widget child) => MembershipAccessGate(
        enabled: widget.enforceMembership,
        repository: widget.membershipAccessRepository,
        freePreviewBuilder: (_, viewPlans) => FreeCoachesPreview(
            coaches: current ? published.values.toList() : const [],
            repository: widget.liveRepository,
            isCurrent: widget.isCurrent,
            loading: state?.loading == true,
            error: state?.message != null || !current,
            onViewPlans: viewPlans),
        feature: MembershipAccessFeature.coach,
        resourceId: 'coach-directory',
        child: child);
    final error = state?.message != null;
    final loading = state?.loading == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? colors.surface : const Color(0xFFF8F7FC),
      appBar: AppBar(
        backgroundColor: isDark ? colors.surface : AppColors.surface,
        foregroundColor: isDark ? colors.onSurface : const Color(0xFF211A31),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Coaches'),
        actions: [
          if (widget.onMessages != null)
            IconButton(
              tooltip: 'Messages',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: widget.onMessages,
              icon: const Icon(Icons.chat_bubble_outline_rounded),
            )
          else
            const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          headerSliverBuilder: (_, __) => [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              sliver: SliverToBoxAdapter(child: _quickAccess(context)),
            ),
          ],
          body: discovery(RefreshIndicator(
              onRefresh: () async {
                await _directory?.refresh();
              },
              child: CustomScrollView(
                  key: const PageStorageKey('member-coaches-list'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 26),
                        sliver: SliverToBoxAdapter(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: (value) =>
                                            setState(() => _query = value),
                                        style: text.bodyMedium?.copyWith(
                                          fontSize: 14,
                                          color: isDark
                                              ? colors.onSurface
                                              : const Color(0xFF211A31),
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Search coaches…',
                                          hintStyle: text.bodyMedium?.copyWith(
                                            color: (isDark
                                                    ? colors.onSurfaceVariant
                                                    : const Color(0xFF766D87))
                                                .withValues(alpha: .75),
                                            fontSize: 13,
                                          ),
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark
                                              ? colors.surfaceContainerHighest
                                                  .withValues(alpha: .35)
                                              : Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 13),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? colors.outlineVariant
                                                      .withValues(alpha: .5)
                                                  : const Color(0xFFE7E3EF),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? colors.outlineVariant
                                                      .withValues(alpha: .5)
                                                  : const Color(0xFFE7E3EF),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            borderSide: BorderSide(
                                              color: isDark
                                                  ? colors.primary
                                                  : const Color(0xFF7027DC),
                                              width: 1.5,
                                            ),
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            size: 20,
                                            color: isDark
                                                ? colors.onSurfaceVariant
                                                : const Color(0xFF766D87),
                                          ),
                                          suffixIcon: _query.isNotEmpty
                                              ? IconButton(
                                                  tooltip: 'Clear search query',
                                                  icon: const Icon(
                                                      Icons.close_rounded,
                                                      size: 18),
                                                  color: isDark
                                                      ? colors.onSurfaceVariant
                                                      : const Color(0xFF766D87),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() => _query = '');
                                                  },
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Tooltip(
                                    message: 'Filter and sort coaches',
                                    child: Material(
                                      color:
                                          colors.primary.withValues(alpha: .09),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                        side: BorderSide(
                                          color: activeFilterCount > 0
                                              ? (isDark
                                                  ? colors.primary
                                                  : const Color(0xFF7027DC))
                                              : (isDark
                                                  ? colors.outlineVariant
                                                      .withValues(alpha: .5)
                                                  : const Color(0xFFE7E3EF)),
                                        ),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: InkWell(
                                        onTap: () => _filters(specialties),
                                        child: SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Icon(
                                                Icons.tune_rounded,
                                                size: 21,
                                                color: colors.primary,
                                              ),
                                              if (activeFilterCount > 0)
                                                Positioned(
                                                  key: const Key(
                                                      'coach-active-filter-indicator'),
                                                  top: 8,
                                                  right: 8,
                                                  child: Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: isDark
                                                          ? colors.primary
                                                          : const Color(
                                                              0xFF7027DC),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!loading &&
                                  (!error || coaches.isNotEmpty) &&
                                  current)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Text(
                                        '${visible.length} ${visible.length == 1 ? "coach" : "coaches"} available',
                                        style: text.bodySmall?.copyWith(
                                          color: colors.onSurface,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )),
                                      const SizedBox(width: 12),
                                      Expanded(
                                          child: Text(
                                        isBranchActive
                                            ? _branchNames[_selectedBranch] ??
                                                'Selected branch'
                                            : 'All branches',
                                        textAlign: TextAlign.end,
                                        style: text.bodySmall?.copyWith(
                                            color: colors.onSurfaceVariant),
                                      )),
                                    ],
                                  ),
                                ),
                              if (isSpecialtyActive || isSortActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                      [
                                        if (isSpecialtyActive) _specialtyFilter,
                                        if (isSortActive)
                                          _sortBy == _SortBy.priceLow
                                              ? 'Sorted by price'
                                              : 'Sorted by experience',
                                      ].join(' · '),
                                      style: text.bodySmall
                                          ?.copyWith(color: colors.primary)),
                                ),
                            ]))),
                    if (!current)
                      SliverToBoxAdapter(
                          child: status(
                              Icons.lock_outline,
                              'Coaches unavailable',
                              'Your session has changed. Return and sign in again.'))
                    else if (loading)
                      SliverToBoxAdapter(
                        child: Semantics(
                          label: 'Loading coaches',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(children: [
                              for (var i = 0; i < 2; i++)
                                Container(
                                  height: 88,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest
                                        .withValues(alpha: .48),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      )
                    else if (error && coaches.isEmpty)
                      SliverToBoxAdapter(
                          child: status(
                              Icons.cloud_off_outlined,
                              'Could not load coaches',
                              'Check your connection and try again.',
                              retry: true))
                    else if (visible.isEmpty)
                      SliverToBoxAdapter(
                          child: hasNarrowingFilters
                              ? status(
                                  Icons.search_off_rounded,
                                  'No matching coaches',
                                  'Try another name or specialty, or clear your filters.',
                                  clear: true)
                              : status(
                                  Icons.people_outline,
                                  'No coaches available',
                                  'Pull down to refresh.'))
                    else
                      SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList.builder(
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final c = visible[index], p = published[c.id];
                                return Padding(
                                    key: ValueKey(c.id),
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: CoachCard(
                                        key: ValueKey('member-coach-${c.id}'),
                                        coach: c,
                                        published: p,
                                        branchNames: _branchNames,
                                        photo: p == null
                                            ? null
                                            : PublishedCoachPhoto(
                                                coach: p,
                                                repository:
                                                    widget.liveRepository!,
                                                isCurrent: widget.isCurrent!,
                                                size: 56),
                                        onTap: () {
                                          if (widget.live &&
                                              widget.isCurrent?.call() !=
                                                  true) {
                                            _directory?.invalidate();
                                            return;
                                          }
                                          if (p != null) {
                                            widget.onOpenPublished?.call(c.id);
                                          } else {
                                            Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        CoachProfileScreen(
                                                            coach: c)));
                                          }
                                        }));
                              })),
                    if (current && !loading && state?.nextCursor != null)
                      SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          sliver: SliverToBoxAdapter(
                              child: Column(children: [
                            if (error)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                      'Could not load more coaches. Try again.',
                                      style: text.bodyMedium?.copyWith(
                                          color: colors.onSurfaceVariant))),
                            SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                    onPressed: state!.loadingMore
                                        ? null
                                        : _directory!.loadMore,
                                    style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 48)),
                                    child: Text(state.loadingMore
                                        ? 'Loading…'
                                        : error
                                            ? 'Retry loading more'
                                            : 'Load more coaches'))),
                          ]))),
                    const SliverToBoxAdapter(child: SizedBox(height: 26)),
                  ]))),
        ),
      ),
    );
  }
}
