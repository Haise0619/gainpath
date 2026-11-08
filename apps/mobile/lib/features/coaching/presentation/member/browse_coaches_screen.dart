import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'booking_schedule_screen.dart';
import '../shared/coach_profile_screen.dart';
import '../shared/live_coach_directory_views.dart';
import '../shared/published_coach_presentation.dart';
import '../shared/member_coach_presentation.dart';
import '../../application/coach_directory_cubit.dart';
import 'widgets/coach_card.dart';

enum _SortBy { rating, priceLow, experience }

class BrowseCoachesScreen extends StatefulWidget {
  const BrowseCoachesScreen(
      {super.key,
      this.live = false,
      this.liveRepository,
      this.isCurrent,
      this.onOpenPublished,
      this.bookingsBuilder});
  final bool live;
  final CoachDirectoryRepository? liveRepository;
  final bool Function()? isCurrent;
  final void Function(String)? onOpenPublished;
  final WidgetBuilder? bookingsBuilder;
  @override
  State<BrowseCoachesScreen> createState() => _BrowseCoachesScreenState();
}

class _BrowseCoachesScreenState extends State<BrowseCoachesScreen> {
  String _specialtyFilter = 'All';
  _SortBy _sortBy = _SortBy.rating;
  final _searchController = TextEditingController();
  String _query = '';
  CoachDirectoryCubit? _directory;
  int _tab = 0;
  Widget? _bookings;
  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() {
    if (widget.liveRepository != null) {
      _directory = CoachDirectoryCubit(
          repository: widget.liveRepository!,
          isCurrent: () => widget.isCurrent?.call() == true)
        ..refresh();
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
      _specialtyFilter = 'All';
      _tab = 0;
      _bookings = null;
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
      });
  Widget _tabs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          for (var index = 0; index < 2; index++)
            Expanded(
                child: Padding(
                    padding: EdgeInsets.only(left: index == 1 ? 4 : 0),
                    child: Semantics(
                        selected: _tab == index,
                        child: TextButton(
                            onPressed: () => setState(() {
                                  _tab = index;
                                  if (index == 1 && _bookings == null) {
                                    _bookings = widget.bookingsBuilder
                                            ?.call(context) ??
                                        (widget.live
                                            ? const Center(
                                                child: Text(
                                                    'Bookings unavailable in this view.'))
                                            : const BookingScheduleScreen(
                                                embedded: true));
                                  }
                                }),
                            style: TextButton.styleFrom(
                                backgroundColor: _tab == index
                                    ? colors.primary
                                    : Colors.transparent,
                                foregroundColor: _tab == index
                                    ? colors.onPrimary
                                    : colors.onSurface,
                                minimumSize: const Size(0, 48),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 10),
                                textStyle: memberCoachTypography(context)
                                    .titleSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            child: Text(
                                index == 0 ? 'Find Coach' : 'My Bookings',
                                textAlign: TextAlign.center))))),
        ]));
  }

  Future<void> _filters(List<String> specialties) async {
    var specialty = _specialtyFilter;
    var sort = _sortBy;
    final result = await showModalBottomSheet<
            ({String specialty, _SortBy sort})>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
            heightFactor: .8,
            child: StatefulBuilder(builder: (context, update) {
              final text = memberCoachTypography(context);
              return SafeArea(
                  top: false,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: Text('Filter and sort',
                                      style: text.titleLarge)),
                              IconButton(
                                  tooltip: 'Close filters',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(Icons.close_rounded))
                            ]),
                            const SizedBox(height: 8),
                            Expanded(
                                child: SingleChildScrollView(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                  Text('Specialty', style: text.titleSmall),
                                  const SizedBox(height: 8),
                                  Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: specialties
                                          .map((s) => ChoiceChip(
                                              label: Text(s),
                                              selected: specialty == s,
                                              selectedColor: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              checkmarkColor: Theme.of(context)
                                                  .colorScheme
                                                  .onPrimary,
                                              labelStyle: text.labelLarge
                                                  ?.copyWith(
                                                      color: specialty == s
                                                          ? Theme.of(context)
                                                              .colorScheme
                                                              .onPrimary
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurface),
                                              onSelected: (_) =>
                                                  update(() => specialty = s)))
                                          .toList()),
                                  const SizedBox(height: 20),
                                  Text('Sort by', style: text.titleSmall),
                                  RadioGroup<_SortBy>(
                                      groupValue: sort,
                                      onChanged: (value) {
                                        if (value != null) {
                                          update(() => sort = value);
                                        }
                                      },
                                      child: Column(children: [
                                        for (final option in _SortBy.values)
                                          RadioListTile<_SortBy>(
                                              contentPadding: EdgeInsets.zero,
                                              value: option,
                                              title: Text(switch (option) {
                                                _SortBy.rating =>
                                                  'Highest rated',
                                                _SortBy.priceLow =>
                                                  'Price: low to high',
                                                _SortBy.experience =>
                                                  'Most experienced'
                                              })),
                                      ])),
                                  const SizedBox(height: 12),
                                  Text(
                                      'Search and sorting apply to loaded coaches. Load more results to include more coaches.',
                                      style: text.bodySmall),
                                ]))),
                            const SizedBox(height: 12),
                            Wrap(spacing: 12, runSpacing: 8, children: [
                              OutlinedButton(
                                  onPressed: () => update(() {
                                        specialty = 'All';
                                        sort = _SortBy.rating;
                                      }),
                                  child: const Text('Reset')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(context,
                                      (specialty: specialty, sort: sort)),
                                  child: const Text('Apply')),
                            ]),
                          ])));
            })));
    if (result != null && mounted) {
      setState(() {
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
    final filtered = _query.trim().isNotEmpty || _specialtyFilter != 'All';
    final visible = coaches.where((c) {
      final q = _query.trim().toLowerCase();
      return (_specialtyFilter == 'All' || c.specialty == _specialtyFilter) &&
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
    final error = state?.message != null;
    final loading = state?.loading == true;
    return Scaffold(
      appBar: AppBar(title: const Text('Coaches')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _tabs(context)),
        Expanded(
            child: IndexedStack(index: _tab, children: [
          TickerMode(
              enabled: _tab == 0,
              child: RefreshIndicator(
                  onRefresh: () async {
                    await _directory?.refresh();
                  },
                  child: CustomScrollView(
                      key: const PageStorageKey('member-coaches-list'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            sliver: SliverToBoxAdapter(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                            child: TextField(
                                                controller: _searchController,
                                                onChanged: (value) => setState(
                                                    () => _query = value),
                                                decoration: InputDecoration(
                                                    hintText: MediaQuery.textScalerOf(
                                                                    context)
                                                                .scale(14) >
                                                            19
                                                        ? 'Search…'
                                                        : 'Search coaches…',
                                                    isDense: true,
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 13),
                                                    prefixIcon: const Icon(
                                                        Icons.search_rounded,
                                                        size: 20),
                                                    suffixIcon: _query.isEmpty
                                                        ? null
                                                        : IconButton(
                                                            tooltip:
                                                                'Clear search',
                                                            icon: const Icon(
                                                                Icons.close_rounded,
                                                                size: 18),
                                                            onPressed: () => setState(() {
                                                                  _query = '';
                                                                  _searchController
                                                                      .clear();
                                                                }))))),
                                        const SizedBox(width: 8),
                                        Badge(
                                            isLabelVisible:
                                                _specialtyFilter != 'All' ||
                                                    _sortBy != _SortBy.rating,
                                            label: Text(((_specialtyFilter == 'All'
                                                        ? 0
                                                        : 1) +
                                                    (_sortBy == _SortBy.rating
                                                        ? 0
                                                        : 1))
                                                .toString()),
                                            child: IconButton.filledTonal(
                                                tooltip:
                                                    'Filter and sort coaches',
                                                onPressed: () =>
                                                    _filters(specialties),
                                                style: IconButton.styleFrom(
                                                    backgroundColor: colors
                                                        .primary
                                                        .withValues(alpha: .08),
                                                    foregroundColor:
                                                        colors.primary,
                                                    minimumSize: const Size(48, 48),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                                icon: const Icon(Icons.tune_rounded, size: 22))),
                                      ]),
                                  const SizedBox(height: 12),
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                          children: specialties
                                              .map((s) => Padding(
                                                  padding: const EdgeInsets.only(
                                                      right: 8),
                                                  child: ChoiceChip(
                                                      label: Text(s),
                                                      selected:
                                                          s == _specialtyFilter,
                                                      onSelected: (_) => setState(() =>
                                                          _specialtyFilter = s),
                                                      selectedColor:
                                                          colors.primary,
                                                      checkmarkColor:
                                                          colors.onPrimary,
                                                      labelStyle: text.labelLarge?.copyWith(
                                                          color: s == _specialtyFilter
                                                              ? colors.onPrimary
                                                              : colors
                                                                  .onSurface),
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .padded)))
                                              .toList())),
                                  if (filtered)
                                    Align(
                                        alignment: Alignment.centerLeft,
                                        child: TextButton(
                                            onPressed: _clear,
                                            child:
                                                const Text('Clear filters'))),
                                ]))),
                        if (!current)
                          SliverToBoxAdapter(
                              child: status(
                                  Icons.lock_outline,
                                  'Coaches unavailable',
                                  'Your session has changed. Return and sign in again.'))
                        else if (loading)
                          const SliverToBoxAdapter(
                              child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Column(children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 16),
                                    Text('Finding your coaches…')
                                  ])))
                        else if (error && coaches.isEmpty)
                          SliverToBoxAdapter(
                              child: status(
                                  Icons.cloud_off_outlined,
                                  'Could not load coaches',
                                  'Check your connection and try again.',
                                  retry: true))
                        else if (visible.isEmpty)
                          SliverToBoxAdapter(
                              child: filtered
                                  ? status(
                                      Icons.search_off_rounded,
                                      'No matching coaches',
                                      'Try another name or specialty, or clear your filters.',
                                      clear: true)
                                  : status(
                                      Icons.people_outline,
                                      'No coaches available yet.',
                                      'Published coaches will appear here. Pull down to refresh.'))
                        else
                          SliverPadding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              sliver: SliverList.builder(
                                  itemCount: visible.length,
                                  itemBuilder: (context, index) {
                                    final c = visible[index],
                                        p = published[c.id];
                                    return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: CoachCard(
                                            key: ValueKey(
                                                'member-coach-${c.id}'),
                                            coach: c,
                                            published: p,
                                            photo: p == null
                                                ? null
                                                : PublishedCoachPhoto(
                                                    coach: p,
                                                    repository:
                                                        widget.liveRepository!,
                                                    isCurrent:
                                                        widget.isCurrent!,
                                                    size: 56),
                                            onTap: () {
                                              if (widget.live &&
                                                  widget.isCurrent?.call() !=
                                                      true) {
                                                _directory?.invalidate();
                                                return;
                                              }
                                              if (p != null) {
                                                widget.onOpenPublished
                                                    ?.call(c.id);
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
                        const SliverToBoxAdapter(child: SizedBox(height: 24)),
                      ]))),
          TickerMode(
              enabled: _tab == 1,
              child: !current
                  ? const Center(
                      child: Text('Bookings unavailable for this session.'))
                  : _bookings ?? const SizedBox.shrink()),
        ])),
      ]),
    );
  }
}
