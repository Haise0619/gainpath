import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/member_recommendation_repository.dart';

typedef MemberRecommendationOpener = Future<void> Function(
    BuildContext context, MemberRecommendationDetail detail);
typedef MemberRecommendationPhotoBuilder = Widget Function(
    BuildContext context, MemberRecommendationDetail detail);

Future<void> showMemberRecommendationDetail(BuildContext context,
        {required String recommendationId,
        required MemberRecommendationRepository repository,
        required bool Function() isCurrent,
        MemberRecommendationOpener? onOpenTarget,
        MemberRecommendationPhotoBuilder? scopedPhotoBuilder,
        VoidCallback? onBrowseCoaches,
        VoidCallback? onChanged}) =>
    showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => MemberRecommendationSheet(
            recommendationId: recommendationId,
            repository: repository,
            isCurrent: isCurrent,
            onOpenTarget: onOpenTarget,
            scopedPhotoBuilder: scopedPhotoBuilder,
            onBrowseCoaches: onBrowseCoaches,
            onChanged: onChanged));

class MemberRecommendationSheet extends StatefulWidget {
  const MemberRecommendationSheet(
      {super.key,
      required this.recommendationId,
      required this.repository,
      required this.isCurrent,
      this.onOpenTarget,
      this.scopedPhotoBuilder,
      this.onBrowseCoaches,
      this.onChanged});
  final String recommendationId;
  final MemberRecommendationRepository repository;
  final bool Function() isCurrent;
  final MemberRecommendationOpener? onOpenTarget;
  final MemberRecommendationPhotoBuilder? scopedPhotoBuilder;
  final VoidCallback? onBrowseCoaches, onChanged;
  @override
  State<MemberRecommendationSheet> createState() =>
      _MemberRecommendationSheetState();
}

class _MemberRecommendationSheetState extends State<MemberRecommendationSheet> {
  StreamSubscription<AuthState>? _authChanges;
  MemberRecommendationDetail? _detail;
  bool _busy = true;
  String? _error;
  ({String action, int revision})? _pendingResponse;
  final Map<String, String> _commands = {};
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authChanges != null) return;
    // Explicit widget fixtures may omit AuthBloc; signed-in composition supplies it.
    AuthBloc? auth;
    try {
      auth = context.read<AuthBloc>();
    } catch (_) {
      return;
    }
    _authChanges = auth.stream.listen((_) {
      if (mounted && !widget.isCurrent()) {
        setState(() {
          _detail = null;
          _error = null;
          _busy = false;
        });
      }
    });
  }

  @override
  void dispose() {
    unawaited(_authChanges?.cancel());
    super.dispose();
  }

  bool get _current =>
      mounted && widget.isCurrent() && widget.repository.isCurrent;
  String _command(String action) => _commands.putIfAbsent(
      action, () => 'member-${DateTime.now().microsecondsSinceEpoch}-$action');
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
    });
    try {
      var detail = await widget.repository.get(widget.recommendationId);
      if (!_current) return;
      if (detail.available && detail.readAt == null) {
        detail = await widget.repository.act(detail, 'read', _command('read'));
      }
      if (!_current) return;
      setState(() {
        _detail = detail;
        _busy = false;
      });
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not open this recommendation. Please try again.';
        });
      }
    }
  }

  Future<void> _act(String action) async {
    final detail = _detail;
    if (detail == null || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result =
          await widget.repository.act(detail, action, _command(action));
      if (!_current) return;
      setState(() {
        _detail = result;
        _busy = false;
        _pendingResponse = null;
      });
      _commands.remove(action);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _detail = null;
          _pendingResponse = (action: action, revision: detail.revision);
          _error =
              'Your choice was not confirmed. Retry when you are connected.';
        });
      }
    }
  }

  Future<void> _retryResponse() async {
    final pending = _pendingResponse;
    if (pending == null || !_current) return;
    setState(() {
      _busy = true;
      _error = null;
      _detail = null;
    });
    try {
      final current = await widget.repository.get(widget.recommendationId);
      if (!_current) return;
      // A lost response is retried with its original revision and command ID,
      // after current authorization has been checked without showing cached data.
      if (!current.available && pending.action != 'dismiss') {
        setState(() {
          _detail = current;
          _busy = false;
          _pendingResponse = null;
        });
        return;
      }
      final command = MemberRecommendationDetail(
          organizationId: current.organizationId,
          recommendationId: current.recommendationId,
          kind: current.kind,
          revision: pending.revision,
          state: current.state,
          title: 'Recommendation',
          summary: 'Pending response',
          explanations: const [],
          createdAt: current.createdAt,
          expiresAt: current.expiresAt);
      final result = await widget.repository
          .act(command, pending.action, _command(pending.action));
      if (!_current) return;
      setState(() {
        _detail = result;
        _busy = false;
        _pendingResponse = null;
      });
      _commands.remove(pending.action);
      widget.onChanged?.call();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _detail = null;
          _error =
              'Your choice was not confirmed. Retry when you are connected.';
        });
      }
    }
  }

  Future<void> _open() async {
    final detail = _detail;
    if (detail == null || !_current || widget.onOpenTarget == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // The navigation helper resolves consent and current publication again.
      await widget.onOpenTarget!(context, detail);
      if (_current) setState(() => _busy = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _detail = null;
          _error =
              'This recommendation is currently unavailable. Refresh to check again.';
        });
      }
    }
  }

  Widget _image(MemberRecommendationDetail detail) {
    final target = detail.target;
    final photoPath = detail.photoPath;
    if (target is TrainerRecommendationTarget &&
        photoPath != null &&
        photoPath.startsWith(
            'orgs/${detail.organizationId}/coachProfilePhotos/${target.coachId}/') &&
        !photoPath.contains('..') &&
        widget.scopedPhotoBuilder != null) {
      return widget.scopedPhotoBuilder!(context, detail);
    }
    final uri = Uri.tryParse(detail.imageUrl ?? '');
    final valid = uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasFragment;
    final fallback = Container(
        color: AppColors.primaryTint,
        alignment: Alignment.center,
        child: Icon(
            detail.kind == RecommendationKind.trainer
                ? Icons.person_outline_rounded
                : Icons.fitness_center_rounded,
            size: 48,
            color: AppColors.primary));
    return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
            height: 144,
            width: double.infinity,
            child: valid
                ? Image.network(uri.toString(),
                    fit: BoxFit.cover,
                    excludeFromSemantics: true,
                    errorBuilder: (_, __, ___) => fallback,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : fallback)
                : fallback));
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return FractionallySizedBox(
        heightFactor: 0.9,
        child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: double.infinity),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text('Recommendation',
                                style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                            tooltip: 'Close recommendation',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded))
                      ]),
                      if (widget.repository.fixtureOnly)
                        const Padding(
                            padding: EdgeInsets.only(bottom: 12),
                            child: Text('Synthetic local preview',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700))),
                      if (!widget.isCurrent() || !widget.repository.isCurrent)
                        const Text('Your session changed. Return to sign in.')
                      else ...[
                        if (_busy) const LinearProgressIndicator(),
                        if (_error != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Semantics(
                                  liveRegion: true,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(_error!),
                                        if (_pendingResponse != null)
                                          TextButton(
                                              onPressed:
                                                  _busy ? null : _retryResponse,
                                              child:
                                                  const Text('Retry response')),
                                        TextButton(
                                            onPressed: _busy ? null : _load,
                                            child: const Text(
                                                'Refresh recommendation'))
                                      ]))),
                        if (detail != null) ...[
                          const SizedBox(height: 16),
                          _image(detail),
                          const SizedBox(height: 16),
                          Text(
                              detail.kind == RecommendationKind.trainer
                                  ? 'COACH GUIDANCE'
                                  : 'EXERCISE TUTORIAL',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(color: AppColors.primary)),
                          const SizedBox(height: 8),
                          Text(detail.targetLabel ?? detail.title,
                              style: Theme.of(context).textTheme.headlineSmall),
                          if (detail.specialization != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(detail.specialization!,
                                    style: const TextStyle(
                                        color: AppColors.inkSoft))),
                          const SizedBox(height: 12),
                          Text(detail.summary),
                          if (detail.exerciseLabel != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(detail.exerciseLabel!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                          if (detail.objective != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child:
                                    Text(_objectiveLabel(detail.objective!))),
                          for (final reason in detail.explanations)
                            Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(reason)),
                          const SizedBox(height: 20),
                          if (!detail.available) ...[
                            Semantics(
                                liveRegion: true,
                                child: Text(_unavailable(detail.state),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            if (detail.kind == RecommendationKind.trainer &&
                                widget.onBrowseCoaches != null)
                              TextButton(
                                  onPressed: widget.onBrowseCoaches,
                                  child: const Text('Browse Coaches')),
                          ] else ...[
                            SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size(48, 48)),
                                    onPressed:
                                        _busy || widget.onOpenTarget == null
                                            ? null
                                            : _open,
                                    icon: Icon(detail.kind ==
                                            RecommendationKind.trainer
                                        ? Icons.person_search_rounded
                                        : Icons.play_circle_outline_rounded),
                                    label: Text(detail.kind ==
                                            RecommendationKind.trainer
                                        ? 'View Coach'
                                        : 'View Tutorial'))),
                            if (detail.kind == RecommendationKind.trainer)
                              const Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Text(
                                      'Availability and fees are checked when you choose to book.')),
                            const SizedBox(height: 12),
                            if (detail.acknowledgedAt != null)
                              Semantics(
                                  liveRegion: true,
                                  child: Text('Acknowledged',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700)))
                            else
                              SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _act('acknowledge'),
                                      child: const Text('Acknowledge'))),
                            const Text(
                                'Acknowledging saves your response. You decide whether to use this suggestion.',
                                style: TextStyle(color: AppColors.inkSoft)),
                          ],
                          if (detail.deliveredAt != null &&
                              detail.revision >= 1 &&
                              detail.dismissedAt == null &&
                              detail.state !=
                                  MemberRecommendationState.dismissed)
                            SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                    onPressed:
                                        _busy ? null : () => _act('dismiss'),
                                    child:
                                        const Text('Dismiss recommendation'))),
                        ],
                      ],
                    ]))));
  }
}

String _objectiveLabel(String value) => switch (value) {
      'technique' => 'Focus: technique',
      'consistency' => 'Focus: consistency',
      'progression' => 'Focus: progression',
      _ => 'Learning objective: ${value.replaceAll('_', ' ')}'
    };
String _unavailable(MemberRecommendationState state) => switch (state) {
      MemberRecommendationState.expired => 'This recommendation has expired.',
      MemberRecommendationState.dismissed => 'Recommendation dismissed.',
      MemberRecommendationState.notDelivered =>
        'This recommendation has not been delivered.',
      MemberRecommendationState.withdrawn =>
        'This recommendation is no longer available.',
      _ => 'This recommendation is currently unavailable.'
    };
