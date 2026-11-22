import 'dart:async';
import 'recommendation_presentation_copy.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/member_recommendation_repository.dart';
import 'member_recommendation_sheet.dart';
import '../../application/published_recommendation_suggestion.dart';
import 'recommendation_content_card.dart';

/// The same delivered-only collection powers Home and the full recommendation page.
class MemberRecommendationsView extends StatefulWidget {
  const MemberRecommendationsView(
      {super.key,
      required this.repository,
      required this.loadPage,
      required this.isCurrent,
      required this.onOpenTarget,
      this.updates,
      this.onInvalidate,
      this.photoBuilder,
      this.onViewAll,
      this.compact = false,
      this.visible = true,
      this.pageScrollable = false,
      this.loadDiscovery,
      this.loadRoutineCovers,
      this.onOpenDiscovery});

  final Future<Map<String, String>> Function(List<String>)? loadRoutineCovers;
  final PublishedRecommendationLoader? loadDiscovery;
  final Future<void> Function(BuildContext, PublishedRecommendationSuggestion)?
      onOpenDiscovery;
  final Stream<void>? updates;
  final VoidCallback? onInvalidate;
  final MemberRecommendationRepository repository;
  final MemberRecommendationPageLoader loadPage;
  final bool Function() isCurrent;
  final MemberRecommendationOpener onOpenTarget;
  final MemberRecommendationPhotoBuilder? photoBuilder;
  final VoidCallback? onViewAll;
  final bool compact, visible, pageScrollable;

  @override
  State<MemberRecommendationsView> createState() => _RecommendationsState();
}

class _RecommendationsState extends State<MemberRecommendationsView> {
  final _tabKeys = <RecommendationKind?, GlobalKey>{
    null: GlobalKey(),
    RecommendationKind.routine: GlobalKey(),
    RecommendationKind.content: GlobalKey(),
    RecommendationKind.trainer: GlobalKey(),
  };
  Map<String, String> _routineCovers = {};
  final _records = <MemberRecommendationDetail>[];
  List<PublishedRecommendationSuggestion> _discovery = [];
  RecommendationKind? _filter;
  bool _discoveryLoading = false;
  int _discoveryGeneration = 0;
  bool _loading = true, _enabled = true;
  String? _error, _next;
  int _generation = 0;
  Timer? _afterWorkoutRefresh;
  Timer? _signalDebounce;
  StreamSubscription<void>? _updates;
  bool _fetching = false, _refreshPending = false;
  bool get _current =>
      mounted && widget.isCurrent() && widget.repository.isCurrent;

  @override
  void initState() {
    super.initState();
    _load();
    _loadDiscovery();
    _listen();
  }

  void _listen() {
    _updates?.cancel();
    _updates = widget.updates?.listen((_) {
      widget.onInvalidate?.call();
      _signalDebounce?.cancel();
      _signalDebounce = Timer(const Duration(milliseconds: 250), () {
        if (!_current || !widget.visible) return;
        if (_fetching) {
          _refreshPending = true;
          return;
        }
        _load(quiet: true);
      });
    }, onError: (_) {/* Pull to refresh remains available. */});
  }

  Future<void> _refresh() async {
    widget.onInvalidate?.call();
    await Future.wait([_load(), _loadDiscovery()]);
  }

  @override
  void didUpdateWidget(covariant MemberRecommendationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.updates != widget.updates) _listen();
    if (oldWidget.repository != widget.repository) {
      _records.clear();
      _discovery = [];
      _loadDiscovery();
      _next = null;
      _load();
    } else if (!oldWidget.visible && widget.visible) {
      _load();
      _afterWorkoutRefresh?.cancel();
      if (widget.updates == null) _refreshAfterReturn(0);
    } else if (!widget.visible) {
      _afterWorkoutRefresh?.cancel();
    }
  }

  void _refreshAfterReturn(int attempt) {
    const delays = [5, 10, 20, 30];
    if (attempt >= delays.length) {
      return;
    }
    _afterWorkoutRefresh = Timer(Duration(seconds: delays[attempt]), () async {
      if (!_current || !widget.visible) {
        return;
      }
      if (!_loading) {
        await _load(quiet: true);
      }
      if (_current && widget.visible) {
        _refreshAfterReturn(attempt + 1);
      }
    });
  }

  @override
  void dispose() {
    _discoveryGeneration++;
    _afterWorkoutRefresh?.cancel();
    _signalDebounce?.cancel();
    _updates?.cancel();
    super.dispose();
  }

  Future<void> _loadDiscovery() async {
    final generation = ++_discoveryGeneration;
    final loader = widget.loadDiscovery;
    if (loader == null || !widget.isCurrent()) return;
    setState(() => _discoveryLoading = true);
    try {
      final items = await loader();
      if (!mounted ||
          !widget.isCurrent() ||
          generation != _discoveryGeneration) {
        return;
      }
      setState(() => _discovery = items);
    } catch (_) {
      // Published catalog failure leaves refresh and personalization available.
    } finally {
      if (mounted && generation == _discoveryGeneration) {
        setState(() => _discoveryLoading = false);
      }
    }
  }

  Future<void> _openDiscovery(PublishedRecommendationSuggestion item) async {
    if (!widget.isCurrent() || widget.onOpenDiscovery == null) return;
    try {
      await widget.onOpenDiscovery!(context, item);
    } catch (_) {
      if (mounted && widget.isCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'This published item has changed. Refresh to explore available content.')));
      }
    }
  }

  Future<void> _load({bool more = false, bool quiet = false}) async {
    _fetching = true;
    final generation = ++_generation;
    if (!widget.repository.enabled || !widget.isCurrent()) {
      setState(() {
        _records.clear();
        _enabled = false;
        _loading = false;
      });
      _fetching = false;
      return;
    }
    setState(() {
      _loading = !quiet;
      _error = null;
    });
    try {
      var page =
          await widget.loadPage(history: false, afterId: more ? _next : null);
      final allRecords = [...page.records];
      final cursors = <String>{};
      while (page.nextAfterId != null) {
        if (!_current || generation != _generation) return;
        if (!cursors.add(page.nextAfterId!)) {
          throw const MemberRecommendationUnavailable();
        }
        page = await widget.loadPage(history: false, afterId: page.nextAfterId);
        allRecords.addAll(page.records);
      }
      page =
          MemberRecommendationPage(records: allRecords, enabled: page.enabled);
      if (!_current || generation != _generation) return;
      // A prepared or cross-scope record must never become a consumer card.
      if (page.records.any((r) =>
          r.organizationId != widget.repository.scope.organizationId ||
          r.deliveredAt == null ||
          r.revision < 1 ||
          r.state == MemberRecommendationState.notDelivered)) {
        throw const MemberRecommendationUnavailable();
      }
      final ids = page.records
          .where((r) => r.available)
          .map((r) => r.target)
          .whereType<RoutineRecommendationTarget>()
          .map((r) => r.routineId)
          .toSet()
          .toList();
      var covers = <String, String>{};
      if (ids.isNotEmpty && widget.loadRoutineCovers != null) {
        try {
          covers = await widget.loadRoutineCovers!(ids);
        } catch (_) {}
      }
      if (!_current || generation != _generation) return;
      setState(() {
        _routineCovers = {if (more) ..._routineCovers, ...covers};
        _enabled = page.enabled;
        _next = page.nextAfterId;
        if (!more) {
          _records.clear();
        }
        for (final record in page.records) {
          if (record.available && record.expiresAt.isAfter(DateTime.now())) {
            _records.removeWhere(
                (r) => r.recommendationId == record.recommendationId);
            _records.add(record);
          }
        }
        _loading = false;
      });
    } catch (_) {
      if (!_current || generation != _generation) return;
      setState(() {
        _loading = false;
        if (!quiet) {
          _error = 'We could not load your recommendations.';
        }
      });
    } finally {
      if (generation == _generation) {
        _fetching = false;
        if (_refreshPending && _current && widget.visible) {
          _refreshPending = false;
          _load(quiet: true);
        }
      }
    }
  }

  Future<void> _detail(MemberRecommendationDetail detail) async {
    if (!_current) return;
    await showMemberRecommendationDetail(context,
        recommendationId: detail.recommendationId,
        repository: widget.repository,
        isCurrent: widget.isCurrent,
        onOpenTarget: widget.onOpenTarget,
        scopedPhotoBuilder: widget.photoBuilder,
        relatedRecommendations: _group(detail));
    if (_current) {
      widget.onInvalidate?.call();
      await _load(quiet: true);
    }
  }

  Future<void> _open(MemberRecommendationDetail previous) async {
    if (!_current || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var detail = await widget.repository.resolve(previous.recommendationId);
      if (!_current || !detail.available || detail.deliveredAt == null) {
        throw const MemberRecommendationUnavailable();
      }
      if (detail.readAt == null) {
        detail = await widget.repository.act(detail, 'read',
            'read-${detail.recommendationId}-${detail.revision}');
      }
      if (!_current) return;
      await widget.onOpenTarget(context, detail);
      if (_current) {
        widget.onInvalidate?.call();
        await _load(quiet: true);
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _loading = false;
          _error =
              'This suggestion has changed. Reload to see what is available.';
        });
      }
    }
  }

  List<MemberRecommendationDetail> _group(MemberRecommendationDetail detail) =>
      mergeAvailableMemberRecommendations(_records, DateTime.now()).firstWhere(
          (g) =>
              memberRecommendationTargetKey(g.first) ==
              memberRecommendationTargetKey(detail),
          orElse: () => [detail]);
  Future<void> _dismiss(MemberRecommendationDetail detail) async {
    if (!_current || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await dismissMemberRecommendationGroup(
          widget.repository, _group(detail), () => _current);
      if (_current) {
        widget.onInvalidate?.call();
        await _load(quiet: true);
      }
    } catch (_) {
      if (_current) {
        setState(() {
          _loading = false;
          _error = 'Your choice was not confirmed. Reload and try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent(context);
    if (!widget.pageScrollable) return content;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [content],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (!widget.isCurrent()) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final filtered =
        mergeAvailableMemberRecommendations(_records, DateTime.now())
            .map((g) => g.first)
            .where((r) => _filter == null || r.kind == _filter)
            .toList();
    final kinds = [
      _filter ?? RecommendationKind.routine,
      if (_filter == null) ...[
        RecommendationKind.content,
        RecommendationKind.trainer
      ]
    ];
    var slots = widget.compact ? 2 : filtered.length + _discovery.length;
    final groups = <Widget>[];
    for (final kind in kinds) {
      if (slots == 0) break;
      final records = filtered
          .where((r) => r.kind == kind)
          .take(widget.compact ? 1 : slots)
          .toList();
      final published = records.isEmpty
          ? _discovery
              .where((r) => r.kind == kind)
              .take(widget.compact ? 1 : slots)
              .toList()
          : <PublishedRecommendationSuggestion>[];
      if (records.isEmpty && published.isEmpty) continue;
      slots -= records.length + published.length;
      if (!widget.compact || published.isNotEmpty) {
        groups.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
              switch (kind) {
                RecommendationKind.routine => published.isEmpty
                    ? 'Recommended routines'
                    : 'Explore routines',
                RecommendationKind.content => published.isEmpty
                    ? 'Recommended tutorials'
                    : 'Explore tutorials',
                RecommendationKind.trainer => 'Recommended coaches',
              },
              style: text.titleMedium),
        ));
      }
      for (final detail in records) {
        final target = detail.target;
        groups.add(RecommendationCard(
          detail: detail,
          busy: _loading,
          routineCover: target is RoutineRecommendationTarget
              ? widget.loadRoutineCovers == null
                  ? detail.imageUrl
                  : (_routineCovers[target.routineId] ?? detail.imageUrl)
              : null,
          compact: widget.compact,
          onOpen: () => detail.available ? _open(detail) : _detail(detail),
          onDetails: () => _detail(detail),
          onDismiss: detail.available ? () => _dismiss(detail) : null,
          photoBuilder: widget.photoBuilder,
        ));
        groups.add(const SizedBox(height: 12));
      }
      for (final item in published) {
        groups.add(RecommendationContentCard(
          kind: item.kind,
          useTallRoutineCover:
              widget.compact && item.kind == RecommendationKind.routine,
          title: item.title,
          reason: '',
          imageUrl: item.imageUrl,
          difficulty: item.difficulty,
          durationMinutes: item.durationMinutes,
          exerciseCount: item.exerciseCount,
          specialization: item.specialization,
          branchLabel: item.branchLabel,
          priceMinor: item.priceMinor,
          currency: item.currency,
          onOpen: () => _openDiscovery(item),
        ));
        groups.add(const SizedBox(height: 12));
      }
    }
    final discovery =
        _discovery.where((r) => _filter == null || r.kind == _filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.compact)
        Row(children: [
          Expanded(child: Text('Recommended for You', style: text.titleLarge)),
          _headerAction(),
        ]),
      if (!widget.compact) ...[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(children: [
            _filterChip('For You', null),
            _filterChip('Routines', RecommendationKind.routine),
            _filterChip('Tutorials', RecommendationKind.content),
            _filterChip('Coaches', RecommendationKind.trainer),
          ]),
        ),
        const SizedBox(height: 16),
      ],
      if (_loading && _records.isEmpty) const _RecommendationSkeleton(),
      if (_error != null)
        _message(_error!,
            action: TextButton(
                onPressed: _loading ? null : _refresh,
                child: const Text('Try again'))),
      if (!_loading && filtered.isEmpty && discovery.isEmpty)
        _message(
            _filter == RecommendationKind.trainer
                ? 'No coach recommendations yet.'
                : !_enabled
                    ? 'Explore published workouts while personalization becomes available for your account.'
                    : 'Ready for your next step? Explore published workouts or refresh after your next training session.',
            action: Wrap(spacing: 8, children: [
              if (_filter != null)
                TextButton(
                    onPressed: () => setState(() => _filter = null),
                    child: const Text('Explore all recommendations')),
            ])),
      ...groups,
      if (_discoveryLoading && _records.isEmpty)
        const LinearProgressIndicator(),
      if (!widget.compact && _next != null)
        TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Load more')),
    ]);
  }

  Widget _filterChip(String label, RecommendationKind? kind) {
    final key = _tabKeys[kind] ??= GlobalKey();
    return Padding(
      key: key,
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
          label: Text(label),
          selected: _filter == kind,
          selectedColor: AppColors.primary,
          backgroundColor: AppColors.surface,
          checkmarkColor: AppColors.surface,
          side: BorderSide(
              color: _filter == kind ? AppColors.primary : AppColors.hairline),
          labelStyle: TextStyle(
              color: _filter == kind ? AppColors.surface : AppColors.ink,
              fontWeight: FontWeight.w600),
          onSelected: (_) {
            setState(() => _filter = kind);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (key.currentContext != null) {
                Scrollable.ensureVisible(
                  key.currentContext!,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: 0.5,
                );
              }
            });
          }),
    );
  }

  Widget _headerAction() {
    if (widget.compact && widget.onViewAll != null) {
      return TextButton(
          onPressed: widget.onViewAll, child: const Text('View all'));
    }
    return const SizedBox.shrink();
  }

  Widget _message(String text, {Widget? action}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
          if (action != null) action,
        ]),
      );
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard(
      {super.key,
      required this.detail,
      required this.onOpen,
      this.onDismiss,
      this.onDetails,
      this.photoBuilder,
      this.routineCover,
      this.compact = false,
      this.busy = false});
  final MemberRecommendationDetail detail;
  final VoidCallback onOpen;
  final VoidCallback? onDismiss, onDetails;
  final MemberRecommendationPhotoBuilder? photoBuilder;
  final bool busy, compact;
  final String? routineCover;

  @override
  Widget build(BuildContext context) => RecommendationContentCard(
      kind: detail.kind,
      title: detail.targetLabel ?? detail.title,
      reason: compact
          ? ''
          : detail.available
              ? recommendationFriendlyReason(detail)
              : recommendationStateLabel(detail.state),
      available: detail.available,
      busy: busy,
      imageUrl: detail.kind == RecommendationKind.routine
          ? (routineCover ?? detail.imageUrl)
          : detail.imageUrl,
      photo: detail.available &&
              detail.kind == RecommendationKind.trainer &&
              detail.photoPath != null
          ? photoBuilder?.call(context, detail)
          : null,
      difficulty: detail.difficulty,
      durationMinutes: detail.durationMinutes,
      exerciseCount: detail.exerciseCount,
      specialization: detail.specialization,
      branchLabel: detail.branchLabel,
      priceMinor: detail.priceMinor,
      currency: detail.currency,
      onOpen: onOpen,
      onDetails: detail.available && !compact ? onDetails : null,
      onDismiss: compact ? null : onDismiss);
}

String recommendationFriendlyReason(MemberRecommendationDetail detail) =>
    recommendationPresentationReason(detail.summary, detail.exerciseLabel);

String recommendationStateLabel(MemberRecommendationState state) =>
    switch (state) {
      MemberRecommendationState.expired => 'This recommendation has expired.',
      MemberRecommendationState.dismissed =>
        'You dismissed this recommendation.',
      MemberRecommendationState.withdrawn =>
        'This recommendation has been withdrawn.',
      _ => 'This recommendation is currently unavailable.',
    };

class _RecommendationSkeleton extends StatelessWidget {
  const _RecommendationSkeleton();
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Loading recommendations',
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 144,
                decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(16))),
            const SizedBox(height: 16),
            Container(height: 14, width: 160, color: AppColors.surfaceAlt),
            const SizedBox(height: 12),
            Container(height: 12, color: AppColors.surfaceAlt),
            const SizedBox(height: 12),
            Container(height: 12, width: 200, color: AppColors.surfaceAlt),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ])));
}
