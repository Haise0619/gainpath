import 'dart:async';
import 'recommendation_presentation_copy.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/member_recommendation_repository.dart';
import 'member_recommendation_sheet.dart';
import '../../application/published_recommendation_suggestion.dart';
import 'recommendation_content_card.dart';

/// The same delivered-only collection powers Home and the full history route.
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
      this.onSettings,
      this.onViewAll,
      this.compact = false,
      this.visible = true,
      this.loadDiscovery,
      this.onOpenDiscovery});

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
  final VoidCallback? onSettings, onViewAll;
  final bool compact, visible;

  @override
  State<MemberRecommendationsView> createState() => _RecommendationsState();
}

class _RecommendationsState extends State<MemberRecommendationsView> {
  final _records = <MemberRecommendationDetail>[];
  List<PublishedRecommendationSuggestion> _discovery = [];
  RecommendationKind? _filter;
  bool _discoveryLoading = false;
  int _discoveryGeneration = 0;
  bool _loading = true, _history = false, _enabled = true;
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

  void _refresh() {
    widget.onInvalidate?.call();
    _load();
    _loadDiscovery();
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
      final page = await widget.loadPage(
          history: _history, afterId: more ? _next : null);
      if (!_current || generation != _generation) return;
      // A prepared or cross-scope record must never become a consumer card.
      if (page.records.any((r) =>
          r.organizationId != widget.repository.scope.organizationId ||
          r.deliveredAt == null ||
          r.revision < 1 ||
          r.state == MemberRecommendationState.notDelivered)) {
        throw const MemberRecommendationUnavailable();
      }
      setState(() {
        _enabled = page.enabled;
        _next = page.nextAfterId;
        if (!more) {
          _records.clear();
        }
        for (final record in page.records) {
          if (_history ||
              record.available && record.expiresAt.isAfter(DateTime.now())) {
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
        scopedPhotoBuilder: widget.photoBuilder);
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

  Future<void> _dismiss(MemberRecommendationDetail detail) async {
    if (!_current || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.repository.act(detail, 'dismiss',
          'dismiss-${detail.recommendationId}-${detail.revision}');
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
    if (!widget.isCurrent()) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final filtered =
        _records.where((r) => _filter == null || r.kind == _filter).toList();
    final shown = widget.compact ? filtered.take(1) : filtered;
    final discovery =
        _discovery.where((r) => _filter == null || r.kind == _filter).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Text(
                widget.compact
                    ? 'Recommended for You'
                    : 'Personalized Recommendations',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        _headerAction(),
      ]),
      if (!widget.compact) ...[
        const SizedBox(height: 8),
        Text('Your next step, shaped by your goals and recent training.',
            style: text.bodyMedium),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _filterChip('For You', null),
          _filterChip('Routines', RecommendationKind.routine),
          _filterChip('Tutorials', RecommendationKind.content),
          _filterChip('Coaches', RecommendationKind.trainer),
        ]),
        const SizedBox(height: 8),
        Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _history = !_history);
                          _load();
                        },
                  child: Text(_history ? 'Recent recommendations' : 'History')),
              TextButton.icon(
                  onPressed: _loading || _discoveryLoading ? null : _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Refresh')),
            ]),
        const SizedBox(height: 12),
      ],
      if (_loading && _records.isEmpty) const _RecommendationSkeleton(),
      if (_error != null)
        _message(_error!,
            action: TextButton(
                onPressed: _loading ? null : _refresh,
                child: const Text('Try again'))),
      if (!_loading && filtered.isEmpty && (discovery.isEmpty || _history))
        _message(
            _history
                ? 'Your saved recommendation history will appear here.'
                : !_enabled
                    ? 'Explore published workouts while personalization becomes available for your account.'
                    : 'Ready for your next step? Explore published workouts or refresh after your next training session.',
            action: Wrap(spacing: 8, children: [
              if (widget.onSettings != null)
                TextButton(
                    onPressed: widget.onSettings,
                    child: const Text('Personalization settings')),
              if (_filter != null)
                TextButton(
                    onPressed: () => setState(() => _filter = null),
                    child: const Text('Explore all recommendations')),
            ])),
      for (final detail in shown) ...[
        RecommendationCard(
            detail: detail,
            busy: _loading,
            onOpen: () => detail.available ? _open(detail) : _detail(detail),
            onDetails: () => _detail(detail),
            onDismiss: detail.available ? () => _dismiss(detail) : null,
            photoBuilder: widget.photoBuilder),
        const SizedBox(height: 16),
      ],
      if (filtered.isEmpty && !_history && discovery.isNotEmpty) ...[
        if (!widget.compact) ...[
          Text('Explore your gym', style: text.titleMedium),
          const SizedBox(height: 4),
          Text('General discovery from published content.',
              style: text.bodyMedium),
          const SizedBox(height: 12),
        ],
        for (final item in widget.compact ? discovery.take(1) : discovery) ...[
          RecommendationContentCard(
              kind: item.kind,
              title: item.title,
              reason:
                  'Explore this published ${recommendationTypeLabel(item.kind).toLowerCase()} from your gym.',
              general: true,
              imageUrl: item.imageUrl,
              difficulty: item.difficulty,
              durationMinutes: item.durationMinutes,
              exerciseCount: item.exerciseCount,
              specialization: item.specialization,
              branchLabel: item.branchLabel,
              priceMinor: item.priceMinor,
              currency: item.currency,
              onOpen: () => _openDiscovery(item)),
          const SizedBox(height: 16),
        ],
      ],
      if (_discoveryLoading && _records.isEmpty)
        const LinearProgressIndicator(),
      if (!widget.compact && _next != null)
        TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Load more')),
    ]);
  }

  Widget _filterChip(String label, RecommendationKind? kind) => ChoiceChip(
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
      onSelected: (_) => setState(() => _filter = kind));

  Widget _headerAction() {
    if (widget.compact && widget.onViewAll != null) {
      return TextButton(
          onPressed: widget.onViewAll, child: const Text('View all'));
    }
    if (!widget.compact && widget.onSettings != null) {
      return IconButton(
          tooltip: 'Personalization settings',
          onPressed: widget.onSettings,
          icon: const Icon(Icons.tune_rounded));
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
      this.busy = false});
  final MemberRecommendationDetail detail;
  final VoidCallback onOpen;
  final VoidCallback? onDismiss, onDetails;
  final MemberRecommendationPhotoBuilder? photoBuilder;
  final bool busy;

  @override
  Widget build(BuildContext context) => RecommendationContentCard(
      kind: detail.kind,
      title: detail.targetLabel ?? detail.title,
      reason: detail.available
          ? recommendationFriendlyReason(detail)
          : recommendationStateLabel(detail.state),
      available: detail.available,
      busy: busy,
      newRecommendation: detail.readAt == null && detail.available,
      imageUrl: detail.imageUrl,
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
      onDetails: detail.available ? onDetails : null,
      onDismiss: onDismiss);
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
