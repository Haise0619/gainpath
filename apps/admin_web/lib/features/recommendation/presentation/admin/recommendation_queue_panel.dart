import 'recommendation_presentation_copy.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/recommendation_queue.dart';
import '../../application/recommendation_queue_repository.dart';

class RecommendationQueuePanel extends StatefulWidget {
  const RecommendationQueuePanel(
      {super.key,
      this.trainer = false,
      this.history = false,
      this.internalMaintenance = false,
      this.repository,
      this.clock});
  final bool trainer, history;

  /// Internal diagnostics only; normal screens never expose generation.
  final bool internalMaintenance;
  final RecommendationQueueRepository? repository;
  final DateTime Function()? clock;
  @override
  State<RecommendationQueuePanel> createState() =>
      _RecommendationQueuePanelState();
}

class _RecommendationQueuePanelState extends State<RecommendationQueuePanel> {
  bool get _readOnly =>
      _repo is RecommendationReadOnlyPresentation &&
      (_repo as RecommendationReadOnlyPresentation).readOnly;
  RecommendationQueueRepository get _repo =>
      widget.repository ?? const UnavailableRecommendationQueueRepository();
  late String _kind;
  String _search = '';
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
  bool get _sendsToFictionalInbox =>
      _repo is RecommendationDeliveryPresentation &&
      (_repo as RecommendationDeliveryPresentation).sendsToFictionalInbox;
  @override
  void initState() {
    super.initState();
    _kind = widget.trainer ? 'trainer' : 'content';
    _resetQuery();
    _load();
  }

  @override
  void didUpdateWidget(covariant RecommendationQueuePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, widget.repository) ||
        oldWidget.trainer != widget.trainer ||
        oldWidget.history != widget.history) {
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
            _repo.organizationId, _kind, _now, _days)
        .filtered(status: widget.history ? 'all' : 'pending');
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
    if (!mounted) {
      return;
    }
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
    if (!repo.enabled) {
      return;
    }
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
    if (_busy) {
      return;
    }
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
    if (_busy) {
      return;
    }
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
    if (!_current(repo, generation) || range == null) {
      return;
    }
    try {
      _query = RecommendationQueueQuery.calendar(
              repo.organizationId, _kind, _now, range.start, range.end)
          .filtered(status: widget.history ? 'all' : 'pending');
      _days = 0;
      _notice = null;
      _load();
    } on FormatException {
      setState(() => _error = 'Choose a valid range of at most 90 days.');
    }
  }

  Future<void> _refresh() async {
    if (_busy || !_available || _readOnly) {
      return;
    }
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
        builder: (ctx) => Align(
            alignment: Alignment.centerRight,
            child: AdminDialog(
                width: 650,
                child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(ctx).height * .8),
                    child: SingleChildScrollView(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Review recommendation',
                              style: Theme.of(ctx).textTheme.titleLarge),
                          const SizedBox(height: 16),
                          Text(lead.memberLabel,
                              style: Theme.of(ctx).textTheme.titleMedium),
                          Text('${lead.exerciseLabel} · ${lead.category}'),
                          const SizedBox(height: 12),
                          Text(
                              'Suggested ${lead.kind == 'trainer' ? 'Coach' : 'tutorial'}: ${lead.targetLabel}'),
                          Text(
                              'Learning objective: ${queueObjectiveLabel(lead.objective)}'),
                          Text(
                              'Level: ${lead.level[0].toUpperCase()}${lead.level.substring(1)}'),
                          if (lead.specialization != null)
                            Text('Specialization: ${lead.specialization}'),
                          if (lead.target.kind == 'trainer') ...[
                            Text(
                                'Branch: ${lead.branchLabel ?? 'Not provided'}'),
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
                          Text('Why this suggestion',
                              style: Theme.of(ctx).textTheme.titleMedium),
                          ...lead.explanations.map((e) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(recommendationPresentationReason(
                                  e, lead.exerciseLabel)))),
                          const SizedBox(height: 12),
                          Text(_origin(lead)),
                          if (lead.origin == 'deterministic_fallback')
                            const Text(
                                'Additional ranking was unavailable. This suggestion uses the eligible options matched to the Member.'),
                          ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              title: const Text('Technical Details'),
                              children: [
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
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        'Algorithm: ${lead.algorithmVersion}\nPrompt: ${lead.promptVersion}\nModel: ${lead.model ?? 'Not used'}\nEvidence version: ${lead.sourceVersion}\nConfiguration: ${lead.configVersion}\nCreated: ${malaysiaTime(lead.createdAt)} MYT\nExpires: ${malaysiaTime(lead.expiresAt)} MYT\nStatus: ${queueStatusLabel(lead.status)}${lead.dismissReason == null ? '' : '\nDismissal reason: ${lead.dismissReason}'}')),
                              ]),
                          const SizedBox(height: 12),
                          if (!_readOnly && lead.actionable(_now))
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              FilledButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _decide(lead, 'send');
                                  },
                                  child: const Text('Approve & Send')),
                              OutlinedButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _decide(lead, 'dismiss');
                                  },
                                  child: const Text('Dismiss')),
                            ]),
                          Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close'))),
                        ]))))));
  }

  Future<void> _decide(RecommendationLead lead, String action) async {
    if (_busy || !_available || _readOnly || !lead.actionable(_now)) {
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
                                    ? 'Confirm Send prepares and delivers this recommendation to the Member inbox through the protected delivery service.'
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
                                                if (!ctx.mounted) {
                                                  return;
                                                }
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
                ? 'Prepared for the Member inbox. Delivery must be verified separately.'
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
          ? 'Matched using your gym recommendation criteria'
          : switch (lead.origin) {
              'ai_reranked' =>
                'AI-assisted ranking · reviewed eligible candidates',
              'deterministic_single_candidate' =>
                'One eligible candidate · AI ranking not needed',
              _ => 'Matched using available exercise and profile information'
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

  String _status(RecommendationLead lead) =>
      lead.status == 'pending' && !lead.expiresAt.isAfter(_now)
          ? 'Expired'
          : queueStatusLabel(lead.status);
  Widget _leadRow(BuildContext context, RecommendationLead lead, bool wide) {
    final review = TextButton(
        onPressed: _busy ? null : () => _details(lead),
        child: const Text('Review'));
    final reason = lead.explanations.isEmpty
        ? queueObjectiveLabel(lead.objective)
        : recommendationPresentationReason(
            lead.explanations.first, lead.exerciseLabel);
    if (wide) {
      return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline))),
          child: Row(children: [
            Expanded(
                flex: 2,
                child: Text(lead.memberLabel,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Expanded(flex: 2, child: Text(lead.exerciseLabel)),
            Expanded(
                child: Text(lead.kind == 'trainer' ? 'Coach' : 'Tutorial')),
            Expanded(flex: 3, child: Text(reason)),
            Expanded(flex: 2, child: Text(_status(lead))),
            Expanded(flex: 2, child: Text(malaysiaDate(lead.createdAt))),
            review
          ]));
    }
    return Container(
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.hairline))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lead.memberLabel,
              style: Theme.of(context).textTheme.titleMedium),
          Text(
              '${lead.exerciseLabel} · ${lead.kind == 'trainer' ? 'Coach' : 'Tutorial'}'),
          const SizedBox(height: 6),
          Text(reason),
          const SizedBox(height: 6),
          Text('${_status(lead)} · ${malaysiaDate(lead.createdAt)}'),
          Align(alignment: Alignment.centerRight, child: review)
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final current = _repo.isCurrent;
    final page = current ? _page : null;
    final visible = _leads
        .where((lead) =>
            (!widget.history ||
                lead.status != 'pending' ||
                !lead.expiresAt.isAfter(_now)) &&
            '${lead.memberLabel} ${lead.exerciseLabel} ${lead.targetLabel}'
                .toLowerCase()
                .contains(_search))
        .toList();
    return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(constraints.maxWidth < 600 ? 16 : 20,
                16, constraints.maxWidth < 600 ? 16 : 20, 32),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_readOnly)
                const Text(
                    'Read-only · You can review suggestions and history. Approval is unavailable for this account.'),
              if (!_repo.enabled)
                _banner('Recommendation queue is unavailable in this release.')
              else if (!current)
                _banner('Your Admin session changed. Reopen Recommendations.',
                    error: true)
              else ...[
                Text(
                    widget.history
                        ? 'Recorded recommendations and Admin decisions'
                        : 'Review suggestions before approving them for delivery.',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 12, runSpacing: 8, children: [
                  Text('Needs review: ${page?.pending ?? '—'}'),
                  Text('Processed: ${page?.processed ?? '—'}'),
                  Text('Unavailable: ${page?.unavailable ?? '—'}')
                ]),
                Text(
                    'Selected type and dates · Processed includes prepared and dismissed decisions.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
                const SizedBox(height: 16),
                LayoutBuilder(
                    builder: (context, c) =>
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          SizedBox(
                              width: c.maxWidth < 600 ? c.maxWidth : 300,
                              child: TextField(
                                  key: const ValueKey('queue-search'),
                                  decoration: const InputDecoration(
                                      labelText: 'Search loaded records',
                                      prefixIcon: Icon(Icons.search)),
                                  onChanged: (value) => setState(() =>
                                      _search = value.trim().toLowerCase()))),
                          _select('queue-type', 'Type', _kind, const [
                            DropdownMenuItem(
                                value: 'content', child: Text('Tutorial')),
                            DropdownMenuItem(
                                value: 'trainer', child: Text('Coach'))
                          ], (value) {
                            if (value == null) {
                              return;
                            }
                            setState(() {
                              _kind = value;
                              _facets = null;
                              _continuation = null;
                              _refreshCommand = null;
                              _resetQuery();
                            });
                            _load();
                          }),
                          if (widget.history)
                            _select(
                                'queue-status',
                                'Status',
                                _query.status,
                                [
                                  const DropdownMenuItem(
                                      value: 'all', child: Text('All history')),
                                  ...queueStatuses
                                      .where((s) => s != 'pending')
                                      .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(queueStatusLabel(s))))
                                ],
                                (s) => _filters(status: s)),
                        ])),
                const SizedBox(height: 12),
                Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final days in [7, 30, 90])
                        ChoiceChip(
                            label: Text('$days days'),
                            selected: _days == days,
                            onSelected: _busy ? null : (_) => _range(days)),
                      TextButton.icon(
                          onPressed: _busy ? null : _calendar,
                          icon: const Icon(Icons.date_range_outlined),
                          label: const Text('Choose dates')),
                      OutlinedButton.icon(
                          onPressed: _busy ? null : () => _load(),
                          icon: const Icon(Icons.sync),
                          label: const Text('Reload records'))
                    ]),
                Text(
                    '${malaysiaDate(_query.start)} – ${malaysiaDate(_query.end.subtract(const Duration(milliseconds: 1)))} · Malaysia time',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
                if (widget.internalMaintenance && !_readOnly)
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: const Text('Queue maintenance'),
                      children: [
                        Wrap(spacing: 12, runSpacing: 12, children: [
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
                              (v) => _filters(
                                  category: v, resetCategory: v == '')),
                        ]),
                        Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton(
                                onPressed: _busy ? null : _refresh,
                                child: Text(_continuation != null
                                    ? 'Continue refresh'
                                    : _refreshFailed
                                        ? 'Retry refresh'
                                        : 'Refresh queue'))),
                        if (_generationSummary != null &&
                            _generationSummary!.abstained > 0)
                          Text(_generationSummary!.abstentionReasons.entries
                              .where((entry) => entry.value > 0)
                              .map((entry) =>
                                  '${queueAbstentionLabels[entry.key]}: ${entry.value}')
                              .join(' · ')),
                        if (_generationSummary != null)
                          Text(
                              'Latest refresh: ${_generationSummary!.status} · ${_generationSummary!.processed} processed · ${_generationSummary!.generated} generated')
                      ]),
                const SizedBox(height: 12),
                if (_notice != null) _banner(_notice!),
                if (_error != null) ...[
                  _banner(_error!, error: true),
                  TextButton(
                      onPressed: _busy ? null : () => _load(),
                      child: const Text('Retry'))
                ],
                if (_loading || _refreshing || _checkingDetail)
                  const LinearProgressIndicator(
                      semanticsLabel: 'Loading recommendation queue'),
                if (!_loading && page != null && visible.isEmpty)
                  _banner('No recommendations match these filters.'),
                if (visible.isNotEmpty)
                  Container(
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          border: Border.all(color: AppColors.hairline),
                          borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [
                        if (constraints.maxWidth >= 1050 &&
                            MediaQuery.textScalerOf(context).scale(14) < 22)
                          Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                  color: AppColors.primaryTint),
                              child: const Row(children: [
                                Expanded(flex: 2, child: Text('Member')),
                                Expanded(flex: 2, child: Text('Exercise')),
                                Expanded(child: Text('Type')),
                                Expanded(flex: 3, child: Text('Reason')),
                                Expanded(flex: 2, child: Text('Status')),
                                Expanded(flex: 2, child: Text('Date')),
                                SizedBox(width: 76, child: Text('Review'))
                              ])),
                        for (final lead in visible)
                          _leadRow(
                              context,
                              lead,
                              constraints.maxWidth >= 1050 &&
                                  MediaQuery.textScalerOf(context).scale(14) <
                                      22)
                      ])),
                if (page?.nextAfterLeadId != null)
                  TextButton(
                      onPressed: _busy ? null : () => _load(append: true),
                      child: const Text('Load more')),
                if (_search.isNotEmpty)
                  const Text(
                      'Search covers loaded records. Load more to include additional matches.'),
              ]
            ])));
  }
}
