import 'recommendation_presentation_copy.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/member_recommendation_repository.dart';
import 'member_recommendation_sheet.dart';

/// The same delivered-only collection powers Home and the full history route.
class MemberRecommendationsView extends StatefulWidget {
  const MemberRecommendationsView(
      {super.key,
      required this.repository,
      required this.loadPage,
      required this.isCurrent,
      required this.onOpenTarget,
      this.photoBuilder,
      this.onSettings,
      this.onViewAll,
      this.compact = false});

  final MemberRecommendationRepository repository;
  final MemberRecommendationPageLoader loadPage;
  final bool Function() isCurrent;
  final MemberRecommendationOpener onOpenTarget;
  final MemberRecommendationPhotoBuilder? photoBuilder;
  final VoidCallback? onSettings, onViewAll;
  final bool compact;

  @override
  State<MemberRecommendationsView> createState() => _RecommendationsState();
}

class _RecommendationsState extends State<MemberRecommendationsView> {
  final _records = <MemberRecommendationDetail>[];
  bool _loading = true, _history = false, _enabled = true;
  String? _error, _next;
  int _generation = 0;
  bool get _current =>
      mounted && widget.isCurrent() && widget.repository.isCurrent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MemberRecommendationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _records.clear();
      _next = null;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    if (!widget.repository.enabled || !widget.isCurrent()) {
      setState(() {
        _records.clear();
        _enabled = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      if (!more) _records.clear();
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
        _error = 'We could not load your recommendations.';
      });
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
    if (_current) await _load();
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
      if (_current) await _load();
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
      if (_current) await _load();
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
    final shown = widget.compact ? _records.take(1) : _records;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (MediaQuery.textScalerOf(context).scale(18) > 25) ...[
        Text(widget.compact ? 'Recommended for You' : 'Recommendations',
            style: text.titleLarge),
        Align(
            alignment: AlignmentDirectional.centerEnd, child: _headerAction()),
      ] else
        Row(children: [
          Expanded(
              child: Text(
                  widget.compact ? 'Recommended for You' : 'Recommendations',
                  style: text.titleLarge)),
          _headerAction(),
        ]),
      if (!widget.compact) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: const Text('For you'),
              selected: !_history,
              onSelected: _loading
                  ? null
                  : (_) {
                      setState(() => _history = false);
                      _load();
                    }),
          ChoiceChip(
              label: const Text('History'),
              selected: _history,
              onSelected: _loading
                  ? null
                  : (_) {
                      setState(() => _history = true);
                      _load();
                    }),
        ]),
        const SizedBox(height: 12),
      ],
      if (_loading && _records.isEmpty)
        const _RecommendationSkeleton()
      else if (_error != null)
        _message(_error!,
            action: TextButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Try again')))
      else if (_records.isEmpty)
        _message(
            !_enabled
                ? 'Personalized suggestions will appear here when Recommendations is available for your account.'
                : _history
                    ? 'You have no recommendation history yet.'
                    : 'You’re up to date. Helpful suggestions from your gym will appear here.',
            action: widget.onSettings == null
                ? null
                : TextButton(
                    onPressed: widget.onSettings,
                    child: const Text('Personalization settings'))),
      for (final detail in shown) ...[
        RecommendationCard(
            detail: detail,
            busy: _loading,
            onOpen: () => detail.available ? _open(detail) : _detail(detail),
            onDetails: () => _detail(detail),
            onDismiss: detail.available ? () => _dismiss(detail) : null,
            photoBuilder: widget.photoBuilder),
        const SizedBox(height: 12),
      ],
      if (!widget.compact && _next != null)
        TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('Load more')),
    ]);
  }

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
  Widget build(BuildContext context) {
    final trainer = detail.kind == RecommendationKind.trainer;
    final theme = Theme.of(context).textTheme;
    final uri = Uri.tryParse(detail.imageUrl ?? '');
    final image = detail.available &&
        uri?.scheme == 'https' &&
        uri!.host.isNotEmpty &&
        uri.userInfo.isEmpty;
    final fallback = ColoredBox(
        color: AppColors.primaryTint,
        child: Center(
            child: Icon(
                trainer
                    ? Icons.person_outline_rounded
                    : Icons.play_circle_outline_rounded,
                color: AppColors.primary,
                size: 28)));
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.hairline)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                      width: 56,
                      height: 56,
                      child: trainer &&
                              detail.photoPath != null &&
                              photoBuilder != null &&
                              detail.available
                          ? photoBuilder!(context, detail)
                          : image
                              ? Image.network(uri.toString(),
                                  fit: BoxFit.cover,
                                  excludeFromSemantics: true,
                                  errorBuilder: (_, __, ___) => fallback)
                              : fallback)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(trainer ? 'Coach guidance' : 'Exercise tutorial',
                        style: theme.labelLarge
                            ?.copyWith(color: AppColors.primary)),
                    const SizedBox(height: 4),
                    Text(detail.targetLabel ?? detail.title,
                        style: theme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ])),
            ]),
            const SizedBox(height: 12),
            Text(
                detail.available
                    ? recommendationFriendlyReason(detail)
                    : recommendationStateLabel(detail.state),
                style: theme.bodyMedium),
            if (detail.exerciseLabel != null) ...[
              const SizedBox(height: 8),
              Text(detail.exerciseLabel!, style: theme.labelLarge),
            ],
            const SizedBox(height: 12),
            FilledButton(
                onPressed: busy ? null : onOpen,
                child: Text(
                    detail.available
                        ? trainer
                            ? 'View Coach'
                            : 'Watch Tutorial'
                        : 'View details',
                    textAlign: TextAlign.center)),
            if (onDetails != null && detail.available)
              TextButton(
                  onPressed: busy ? null : onDetails,
                  child: const Text('Why this recommendation?')),
            if (onDismiss != null)
              TextButton(
                  onPressed: busy ? null : onDismiss,
                  child: const Text('Dismiss')),
          ])),
    );
  }
}

String recommendationFriendlyReason(MemberRecommendationDetail detail) =>
    recommendationPresentationReason(
        detail.explanations.isNotEmpty
            ? detail.explanations.first
            : detail.summary,
        detail.exerciseLabel);

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
            Container(height: 14, width: 160, color: AppColors.surfaceAlt),
            const SizedBox(height: 12),
            Container(height: 12, color: AppColors.surfaceAlt),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ])));
}
