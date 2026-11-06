import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/recommendation_queue.dart';
import '../../application/recommendation_queue_repository.dart';

class RecommendationQueuePanel extends StatefulWidget {
  const RecommendationQueuePanel(
      {super.key, required this.trainer, this.repository, this.clock});
  final bool trainer;
  final RecommendationQueueRepository? repository;
  final DateTime Function()? clock;
  @override
  State<RecommendationQueuePanel> createState() =>
      _RecommendationQueuePanelState();
}

class _RecommendationQueuePanelState extends State<RecommendationQueuePanel> {
  bool get _readOnly=>_repo is RecommendationReadOnlyPresentation&&(_repo as RecommendationReadOnlyPresentation).readOnly;
  RecommendationQueueRepository get _repo =>
      widget.repository ?? const UnavailableRecommendationQueueRepository();
  String get _kind => widget.trainer ? 'trainer' : 'content';
  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();
  late RecommendationQueueQuery _query;
  RecommendationQueuePage? _page, _facets;
  final _choiceLabels = <String, String>{};
  final _leads = <RecommendationLead>[];
  QueueGenerationSummary? _generationSummary;
  int _generation = 0, _days = 30, _commandSequence = 0;
  bool _loading = false,
      _working = false,
      _checkingDetail = false,
      _refreshing = false,
      _refreshFailed = false;
  String? _error, _notice, _refreshCommand, _continuation;
  bool get _busy => _loading || _working;
  bool get _available => _repo.enabled && _repo.isCurrent;
  bool get _sendsToFictionalInbox => _repo is RecommendationDeliveryPresentation &&
      (_repo as RecommendationDeliveryPresentation).sendsToFictionalInbox;
  @override
  void initState() {
    super.initState();
    _resetQuery();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecommendationQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.trainer != widget.trainer) {
      _working = false;
      _checkingDetail = false;
      _refreshing = false;
      _facets = null;
      _choiceLabels.clear();
      _refreshCommand = null;
      _continuation = null;
      _generationSummary = null;
      _notice = null;
      _days = 30;
      _resetQuery();
      _load();
    }
  }

  void _resetQuery() {
    _query = RecommendationQueueQuery.recent(
        _repo.organizationId, _kind, _now, _days);
  }

  String _command() =>
      'admin-${DateTime.now().microsecondsSinceEpoch}-${++_commandSequence}';
  bool _current(RecommendationQueueRepository repo, int generation) =>
      mounted &&
      generation == _generation &&
      identical(repo, _repo) &&
      repo.isCurrent &&
      repo.organizationId == _query.organizationId;
  void _sessionChanged() {
    if (!mounted) return;
    setState(() {
      _leads.clear();
      _page = null;
      _facets = null;
      _choiceLabels.clear();
      _loading = false;
      _working = false;
      _checkingDetail = false;
      _refreshing = false;
      _error = 'Your Admin session changed. Reopen Recommendations.';
      _notice = null;
    });
  }

  Future<void> _load({bool append = false}) async {
    if (!append && _days > 0) {
      _query = RecommendationQueueQuery.recent(
              _repo.organizationId, _kind, _now, _days)
          .filtered(
              status: _query.status,
              exerciseId: _query.exerciseId,
              category: _query.category,
              specialization: _query.specialization);
    }
    final repo = _repo, generation = ++_generation;
    final query = _query.filtered(
        status: _query.status,
        exerciseId: _query.exerciseId,
        category: _query.category,
        specialization: _query.specialization,
        afterLeadId: append ? _page?.nextAfterLeadId : null);
    setState(() {
      _loading = repo.enabled && repo.isCurrent;
      _error = null;
      if (!append) {
        _page = null;
        _leads.clear();
      }
    });
    if (!repo.isCurrent) {
      _sessionChanged();
      return;
    }
    if (!repo.enabled) return;
    try {
      final page = await repo.list(query);
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!_current(repo, generation)) {
        _sessionChanged();
        return;
      }
      if (append &&
          page.leads.any((l) => _leads.any((old) => old.id == l.id))) {
        throw const FormatException('Repeated queue page.');
      }
      setState(() {
        _page = page;
        _facets = page;
        for (final e in page.exercises) {
          _choiceLabels[e.id] = e.label;
        }
        _leads.addAll(page.leads);
        _loading = false;
        _generationSummary = page.generation ?? _generationSummary;
        if (page.generation?.status == 'failed') {
          _refreshCommand = null;
          _continuation = null;
          _refreshFailed = false;
          _notice =
              'The previous refresh stopped. You can start a new refresh.';
        }
      });
    } catch (_) {
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!repo.isCurrent) {
        _sessionChanged();
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Recommendation queue could not be loaded. Retry.';
        if (!append) {
          _page = null;
          _leads.clear();
        }
      });
    }
  }

  void _filters(
      {String? status,
      String? exerciseId,
      String? category,
      String? specialization,
      bool resetExercise = false,
      bool resetCategory = false,
      bool resetSpecialization = false}) {
    if (_busy) return;
    _query = _query.filtered(
        status: status ?? _query.status,
        exerciseId: resetExercise ? null : exerciseId ?? _query.exerciseId,
        category: resetCategory ? null : category ?? _query.category,
        specialization: resetSpecialization
            ? null
            : specialization ?? _query.specialization);
    _notice = null;
    _load();
  }

  void _range(int days) {
    if (_busy) return;
    _days = days;
    _resetQuery();
    _notice = null;
    _load();
  }

  Future<void> _calendar() async {
    final repo = _repo, generation = _generation;
    final local = _now.add(const Duration(hours: 8));
    final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(local.year, local.month, local.day),
        helpText: 'Malaysia dates · maximum 90 days');
    if (!_current(repo, generation) || range == null) return;
    try {
      _query = RecommendationQueueQuery.calendar(
          repo.organizationId, _kind, _now, range.start, range.end);
      _days = 0;
      _notice = null;
      _load();
    } on FormatException {
      setState(() => _error = 'Choose a valid range of at most 90 days.');
    }
  }

  Future<void> _refresh() async {
    if (_busy || !_available) return;
    final repo = _repo, generation = _generation;
    _refreshCommand ??= _command();
    final command = _refreshCommand!;
    setState(() {
      _working = true;
      _refreshing = true;
      _error = null;
      _notice = null;
    });
    try {
      final summary =
          await repo.refresh(_kind, command, continuation: _continuation);
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!_current(repo, generation)) {
        _sessionChanged();
        return;
      }
      setState(() {
        _working = false;
        _refreshing = false;
        _refreshFailed = false;
        _generationSummary = summary;
        _continuation = summary.nextCursor;
        if (_continuation == null) _refreshCommand = null;
        _notice = summary.status == 'failed'
            ? 'Refresh stopped. Review the queue and retry later.'
            : _continuation != null
                ? 'Refresh paused at a safe batch boundary. Continue to finish.'
                : 'Queue refresh completed locally.';
      });
      await _load();
    } catch (_) {
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!repo.isCurrent) {
        _sessionChanged();
        return;
      }
      setState(() {
        _working = false;
        _refreshing = false;
        _refreshFailed = true;
        _error = 'Queue refresh could not be completed. Retry refresh.';
      });
    }
  }

  Future<void> _details(RecommendationLead cachedLead) async {
    if (_busy || !_available) {
      if (!_repo.isCurrent) _sessionChanged();
      return;
    }
    final repo = _repo, generation = _generation;
    setState(() {
      _working = true;
      _checkingDetail = true;
      _error = null;
    });
    late RecommendationLead lead;
    try {
      // A list row is a cached observation. Revalidate current consent/source
      // eligibility before presenting the sensitive evidence/detail projection.
      lead = await repo.detail(cachedLead);
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!_current(repo, generation)) {
        _sessionChanged();
        return;
      }
      setState(() {
        _working = false;
        _checkingDetail = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation || !identical(repo, _repo)) {
        return;
      }
      if (!_current(repo, generation)) {
        _sessionChanged();
        return;
      }
      setState(() {
        _working = false;
        _checkingDetail = false;
        _leads.clear();
        _page = null;
        _facets = null;
        _choiceLabels.clear();
        _error =
            'Recommendation details could not be verified. Reload records before reviewing again.';
      });
      return;
    }
    await showDialog<void>(
        context: context,
        builder: (ctx) => AdminDialog(
            width: 650,
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(ctx).height * .8),
                child: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Recommendation details',
                          style: Theme.of(ctx).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      Text(lead.memberLabel,
                          style: Theme.of(ctx).textTheme.titleMedium),
                      Text('${lead.exerciseLabel} · ${lead.category}'),
                      const SizedBox(height: 12),
                      Text(
                          'Suggested ${widget.trainer ? 'Coach' : 'tutorial'}: ${lead.targetLabel}'),
                      Text(
                          'Learning objective: ${queueObjectiveLabel(lead.objective)}'),
                      Text(
                          'Level: ${lead.level[0].toUpperCase()}${lead.level.substring(1)}'),
                      if (lead.specialization != null)
                        Text('Specialization: ${lead.specialization}'),
                      if (lead.target.kind == 'trainer') ...[
                        Text('Branch: ${lead.branchLabel ?? 'Not provided'}'),
                        Text(
                            'Observed option: ${malaysiaTime(lead.target.observedStart!)} – ${malaysiaTime(lead.target.observedEnd!)} MYT'),
                        const Text(
                            'Availability is an observation, not reserved. Current eligibility is checked again when you confirm Send.'),
                      ] else ...[
                        Text(
                            'Published routine tutorial · Day ${lead.target.dayNumber} · Exercise ${lead.target.exerciseIndex! + 1}'),
                        const Text(
                            'The current authorized publication is checked again when you confirm Send.'),
                      ],
                      const Divider(height: 28),
                      Text('Evidence summary',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      Text(lead.evidenceSummary),
                      Text(
                          'Scored sessions: ${lead.scoredSessions ?? 'Unknown'}'),
                      Text(
                          'Estimated Form Score: ${lead.score == null ? 'Unknown' : '${lead.score!.toStringAsFixed(1)}%'}'),
                      Text(
                          'Tracking coverage: ${lead.coverage == null ? 'Unknown' : '${(lead.coverage! * 100).toStringAsFixed(1)}%'}'),
                      const Text(
                          'Estimated Form Score is not a clinical injury-risk measurement.'),
                      const Divider(height: 28),
                      Text('Why this suggestion',
                          style: Theme.of(ctx).textTheme.titleMedium),
                      ...lead.explanations.map((e) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(e))),
                      const SizedBox(height: 12),
                      Text(_origin(lead)),
                      if (lead.origin == 'deterministic_fallback')
                        const Text(
                            'AI ranking was unavailable or not accepted. The eligible deterministic order was retained.'),
                      ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Provenance and review history'),
                          children: [
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                    'Algorithm: ${lead.algorithmVersion}\nPrompt: ${lead.promptVersion}\nModel: ${lead.model ?? 'Not used'}\nEvidence version: ${lead.sourceVersion}\nConfiguration: ${lead.configVersion}\nCreated: ${malaysiaTime(lead.createdAt)} MYT\nExpires: ${malaysiaTime(lead.expiresAt)} MYT\nStatus: ${queueStatusLabel(lead.status)}${lead.dismissReason == null ? '' : '\nDismissal reason: ${lead.dismissReason}'}')),
                          ]),
                      const SizedBox(height: 12),
                      Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Close'))),
                    ])))));
  }

  Future<void> _decide(RecommendationLead lead, String action) async {
    if (_busy || !_available || !lead.actionable(_now)) {
      if (!_repo.isCurrent) _sessionChanged();
      return;
    }
    final repo = _repo, generation = _generation, command = _command();
    var reason = '';
    setState(() => _working = true);
    final receipt = await showDialog<RecommendationDecisionReceipt>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          bool saving = false;
          String? error;
          return StatefulBuilder(
              builder: (context, update) => PopScope(
                  canPop: !saving,
                  child: AdminDialog(
                      width: 520,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                action == 'send'
                                    ? 'Send this recommendation?'
                                    : 'Dismiss this suggestion?',
                                style: Theme.of(ctx).textTheme.titleLarge),
                            const SizedBox(height: 12),
                            Text('${lead.memberLabel} · ${lead.targetLabel}'),
                            const SizedBox(height: 12),
                            Text(action == 'send'
                                ? _sendsToFictionalInbox
                                    ? 'Confirm Send prepares and delivers this recommendation to the fictional Member inbox through the protected dataset service.'
                                    : 'Confirm Send prepares this recommendation. No notification is sent by this confirmation; delivery is a separate checked operation.'
                                : 'Record a meaningful reason for this Admin decision. It will be retained in the local queue history.'),
                            if (action == 'dismiss')
                              Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: TextField(
                                      key: const ValueKey(
                                          'queue-dismiss-reason'),
                                      onChanged: (value) => reason = value,
                                      enabled: !saving,
                                      maxLines: 3,
                                      maxLength: 300,
                                      autofocus: true,
                                      decoration: InputDecoration(
                                          labelText: 'Reason for dismissal',
                                          helperText: 'Use 8–300 characters.',
                                          errorText: error))),
                            if (error != null && action == 'send')
                              Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Semantics(
                                      liveRegion: true,
                                      child: Text(error!,
                                          style: const TextStyle(
                                              color: AppColors.danger)))),
                            if (saving)
                              const Padding(
                                  padding: EdgeInsets.only(top: 12),
                                  child: LinearProgressIndicator(
                                      semanticsLabel: 'Saving Admin decision')),
                            const SizedBox(height: 20),
                            Wrap(
                                alignment: WrapAlignment.end,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                      onPressed: saving
                                          ? null
                                          : () => Navigator.pop(ctx),
                                      child: const Text('Cancel')),
                                  FilledButton(
                                      onPressed: saving
                                          ? null
                                          : () async {
                                              if (!_current(repo, generation)) {
                                                Navigator.pop(ctx);
                                                _sessionChanged();
                                                return;
                                              }
                                              final text = reason.trim();
                                              if (action == 'dismiss' &&
                                                  text.length < 8) {
                                                update(() => error =
                                                    'Use at least 8 characters to explain the decision.');
                                                return;
                                              }
                                              update(() {
                                                saving = true;
                                                error = null;
                                              });
                                              try {
                                                final result =
                                                    await repo.decide(
                                                        lead, action, command,
                                                        reason:
                                                            action == 'dismiss'
                                                                ? text
                                                                : null);
                                                if (!_current(
                                                    repo, generation)) {
                                                  if (ctx.mounted) {
                                                    Navigator.pop(ctx);
                                                  }
                                                  _sessionChanged();
                                                  return;
                                                }
                                                if (ctx.mounted) {
                                                  Navigator.pop(ctx, result);
                                                }
                                              } catch (_) {
                                                if (!ctx.mounted) return;
                                                if (!_current(
                                                    repo, generation)) {
                                                  Navigator.pop(ctx);
                                                  _sessionChanged();
                                                  return;
                                                }
                                                update(() {
                                                  saving = false;
                                                  error =
                                                      'Decision could not be saved. Retry or cancel.';
                                                });
                                              }
                                            },
                                      child: Text(action == 'send'
                                          ? 'Confirm Send'
                                          : 'Confirm dismissal')),
                                ]),
                          ])))));
        });

    if (!mounted || generation != _generation || !identical(repo, _repo)) {
      return;
    }
    if (!repo.isCurrent) {
      _sessionChanged();
      return;
    }
    setState(() {
      _working = false;
      _refreshing = false;
      if (receipt != null) {
        _notice = receipt.outcome == 'prepared'
            ? _sendsToFictionalInbox
                ? 'Sent to the fictional Member inbox.'
                : 'Prepared locally. No notification or Member inbox delivery occurred.'
            : receipt.outcome == 'dismissed'
                ? 'Dismissed. The decision is retained in local queue history.'
                : 'This suggestion is no longer eligible. The queue has been updated.';
      }
    });
    if (receipt != null) await _load();
  }

  String _origin(RecommendationLead lead) =>
      lead.model == 'gainpath-demo-structured-mock-v1'
          ? 'Rule-based relevance · educational review'
          : switch (lead.origin) {
        'ai_reranked' => 'AI-assisted ranking · reviewed eligible candidates',
        'deterministic_single_candidate' =>
          'One eligible candidate · AI ranking not needed',
        _ => 'Deterministic fallback · eligible candidate order'
      };
  Widget _select(
          String key,
          String label,
          String? value,
          List<DropdownMenuItem<String>> items,
          ValueChanged<String?> changed) =>
      SizedBox(
          width: 230,
          child: DropdownButtonFormField<String>(
              key: ValueKey(key),
              initialValue: value ?? '',
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: [
                ...items,
                if (value != null &&
                    value.isNotEmpty &&
                    !items.any((item) => item.value == value))
                  DropdownMenuItem(
                      value: value, child: Text(_choiceLabels[value] ?? value))
              ],
              onChanged: _busy || !_available ? null : changed));
  Widget _banner(String message, {bool error = false}) => Semantics(
      liveRegion: true,
      child: Panel(
          background: error ? null : AppColors.primaryTint,
          child: Text(message,
              style:
                  TextStyle(color: error ? AppColors.danger : AppColors.ink))));
  Widget _leadCard(BuildContext context, RecommendationLead lead) => Panel(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lead.memberLabel,
                    style: Theme.of(context).textTheme.titleMedium),
                Text('${lead.exerciseLabel} · ${lead.category}'),
              ])),
          const SizedBox(width: 8),
          if (lead.score != null)
            Tooltip(
                message: 'Estimated Form Score, not clinical risk',
                child: Text('${lead.score!.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 12),
        Container(
            key: ValueKey('queue-target-${lead.id}'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Icon(
                  widget.trainer
                      ? Icons.person_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 18,
                  color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(lead.targetLabel,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w600))),
            ])),
        const SizedBox(height: 10),
        Text(queueObjectiveLabel(lead.objective),
            style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(_origin(lead), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: Text(
                  lead.status == 'pending' && !lead.expiresAt.isAfter(_now)
                      ? 'Expired'
                      : queueStatusLabel(lead.status),
                  style: Theme.of(context).textTheme.bodySmall)),
          TextButton(
              onPressed: _busy ? null : () => _details(lead),
              child: const Text('View details')),
        ]),
        if (!_readOnly && lead.actionable(_now)) ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: FilledButton(
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                    onPressed: _busy ? null : () => _decide(lead, 'send'),
                    child: const Text('Send'))),
            const SizedBox(width: 8),
            Expanded(
                child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42)),
                    onPressed: _busy ? null : () => _decide(lead, 'dismiss'),
                    child: const Text('Dismiss'))),
          ]),
        ],
      ]));
  @override
  Widget build(BuildContext context) {
    final current = _repo.isCurrent;
    final page = current ? _page : null;
    return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(constraints.maxWidth < 600 ? 16 : 28,
                20, constraints.maxWidth < 600 ? 16 : 28, 40),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Text(
                          widget.trainer
                              ? 'Trainer Matching Leads'
                              : 'Content Recommendation Leads',
                          style: Theme.of(context).textTheme.titleLarge),
                      if (_repo.fixtureOnly)
                        const Chip(
                            label:
                                Text('Educational review')),
                    ]),
                const SizedBox(height: 8),
                Text(
                    _readOnly?'Review suggestions and delivery history. This view is read-only.':'Review pending suggestions and recorded Admin decisions. Send prepares a recommendation for checked delivery.'),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final entry in [
                    ('Pending', page?.pending),
                    ('Processed', page?.processed),
                    ('Stale / unavailable', page?.unavailable)
                  ])
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${entry.$1}: ${entry.$2 ?? '—'}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary)))
                ]),
                const SizedBox(height: 8),
                const Text(
                    'Counts use the selected dates and filters across all statuses. Processed includes prepared and dismissed decisions.'),
              ]),
              const SizedBox(height: 16),
              if (!_repo.enabled)
                _banner('Recommendation queue is unavailable in this release.')
              else if (!current)
                _banner('Your Admin session changed. Reopen Recommendations.',
                    error: true)
              else ...[
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Malaysia date range',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        for (final days in [7, 30, 90])
                          ChoiceChip(
                              label: Text('$days days'),
                              selected: _days == days,
                              onSelected: _busy ? null : (_) => _range(days)),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : _calendar,
                            icon: const Icon(Icons.date_range_outlined),
                            label: const Text('Choose dates'))
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          '${malaysiaDate(_query.start)} – ${malaysiaDate(_query.end.subtract(const Duration(milliseconds: 1)))} · Malaysia time'),
                      const SizedBox(height: 16),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        _select(
                            'queue-status',
                            'Status',
                            _query.status,
                            [
                              const DropdownMenuItem(
                                  value: 'all', child: Text('All statuses')),
                              ...queueStatuses.map((s) => DropdownMenuItem(
                                  value: s, child: Text(queueStatusLabel(s))))
                            ],
                            (s) => _filters(status: s)),
                        _select(
                            'queue-exercise',
                            'Exercise',
                            _query.exerciseId,
                            [
                              const DropdownMenuItem(
                                  value: '', child: Text('All exercises')),
                              ...?_facets?.exercises.map((e) =>
                                  DropdownMenuItem(
                                      value: e.id, child: Text(e.label)))
                            ],
                            (v) => _filters(
                                exerciseId: v, resetExercise: v == '')),
                        _select(
                            'queue-category',
                            'Category',
                            _query.category,
                            [
                              const DropdownMenuItem(
                                  value: '', child: Text('All categories')),
                              ...?_facets?.categories.map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                            ],
                            (v) =>
                                _filters(category: v, resetCategory: v == '')),
                        if (widget.trainer)
                          _select(
                              'queue-specialization',
                              'Coach specialization',
                              _query.specialization,
                              [
                                const DropdownMenuItem(
                                    value: '',
                                    child: Text('All specializations')),
                                ...?_facets?.specializations.map((v) =>
                                    DropdownMenuItem(value: v, child: Text(v)))
                              ],
                              (v) => _filters(
                                  specialization: v,
                                  resetSpecialization: v == '')),
                      ]),
                      const SizedBox(height: 16),
                      Wrap(spacing: 12, runSpacing: 12, children: [
                        FilledButton.icon(
                            onPressed: _busy || _readOnly ? null : _refresh,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(_continuation != null
                                ? 'Continue refresh'
                                : _refreshFailed
                                    ? 'Retry refresh'
                                    : 'Refresh queue')),
                        OutlinedButton.icon(
                            onPressed: _busy ? null : () => _load(),
                            icon: const Icon(Icons.sync_rounded),
                            label: const Text('Reload records'))
                      ]),
                      if (_generationSummary != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                                'Latest refresh: ${_generationSummary!.status == 'in_progress' ? 'In progress' : _generationSummary!.status == 'complete' ? 'Complete' : 'Stopped'} · ${_generationSummary!.processed} processed · ${_generationSummary!.generated} generated · ${_generationSummary!.abstained} without a suggestion · ${_generationSummary!.fallbackCount} deterministic fallbacks')),
                      if (_generationSummary != null &&
                          _generationSummary!.abstained > 0)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_generationSummary!
                                .abstentionReasons.entries
                                .where((entry) => entry.value > 0)
                                .map((entry) =>
                                    '${queueAbstentionLabels[entry.key]}: ${entry.value}')
                                .join(' · '))),
                    ])),
                const SizedBox(height: 16),
                if (_notice != null) ...[
                  _banner(_notice!),
                  const SizedBox(height: 12)
                ],
                if (_error != null) ...[
                  _banner(_error!, error: true),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: _busy ? null : () => _load(),
                      child: const Text('Retry')),
                  const SizedBox(height: 12)
                ],
                if (_loading || _refreshing || _checkingDetail)
                  const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: LinearProgressIndicator(
                          semanticsLabel: 'Loading recommendation queue')),
                if (!_loading && page != null && _leads.isEmpty)
                  _banner('No recommendations match these filters.'),
                Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: _leads
                        .map((lead) => SizedBox(
                            width: 380, child: _leadCard(context, lead)))
                        .toList()),
                const SizedBox(height: 12),
                if (page?.nextAfterLeadId != null)
                  OutlinedButton(
                      onPressed: _busy ? null : () => _load(append: true),
                      child: const Text('Load more')),
              ],
            ])));
  }
}
