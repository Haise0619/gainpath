import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/recommendation_queue.dart';
import '../../application/recommendation_queue_repository.dart';
import 'recommendation_presentation_copy.dart';

enum RecommendationMonitorTab { overview, history, attention }

class RecommendationMonitor extends StatefulWidget {
  const RecommendationMonitor({
    super.key,
    required this.repository,
    required this.tab,
    required this.clock,
  });

  final RecommendationQueueRepository repository;
  final RecommendationMonitorTab tab;
  final DateTime Function() clock;

  @override
  State<RecommendationMonitor> createState() => _RecommendationMonitorState();
}

class _RecommendationMonitorState extends State<RecommendationMonitor> {
  static const _kinds = ['content', 'trainer'];
  static const _maxPagesPerKind = 8;
  final _pages = {for (final kind in _kinds) kind: <RecommendationQueuePage>[]};
  final _failed = <String>{};
  final _hidden = <(String, String)>{};
  late DateTime _windowEnd;
  String _kind = 'all', _search = '';
  int _days = 90, _generation = 0;
  bool _loading = false, _opening = false;
  final _scope = ValueNotifier<int>(0);
  late String _organization;

  RecommendationQueueRepository get _repo => widget.repository;
  DateTime get _now => widget.clock().toUtc();

  @override
  void initState() {
    super.initState();
    _organization = _repo.organizationId;
    _windowEnd = _now;
    _load();
  }

  @override
  void didUpdateWidget(covariant RecommendationMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.repository, _repo) ||
        _organization != _repo.organizationId ||
        !_repo.isCurrent) {
      _generation++;
      _scope.value++;
      _organization = _repo.organizationId;
      _windowEnd = _now;
      for (final pages in _pages.values) {
        pages.clear();
      }
      _failed.clear();
      _hidden.clear();
      _loading = false;
      _opening = false;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    _scope.dispose();
    super.dispose();
  }

  bool _current(RecommendationQueueRepository repo, int generation) =>
      mounted &&
      identical(repo, _repo) &&
      generation == _generation &&
      _organization == repo.organizationId &&
      repo.isCurrent;

  List<String> get _filteredKinds => _kind == 'all' ? _kinds : [_kind];

  bool _hasMore(String kind) {
    final pages = _pages[kind]!;
    return pages.isNotEmpty &&
        pages.length < _maxPagesPerKind &&
        pages.last.nextAfterLeadId != null;
  }

  Future<void> _load({bool more = false, bool reload = false}) async {
    if (_loading || !_repo.enabled || !_repo.isCurrent) return;
    final repo = _repo, generation = _generation;
    final kinds = reload
        ? _kinds
        : more
            ? _filteredKinds.where(_hasMore).toList()
            : _failed.isEmpty
                ? _kinds
                : _failed.toList();
    if (kinds.isEmpty) return;
    if (reload) _windowEnd = _now;
    setState(() => _loading = true);
    await Future.wait(kinds.map((kind) async {
      final pages = _pages[kind]!;
      final append = more || (!reload && pages.isNotEmpty);
      final query =
          RecommendationQueueQuery.recent(_organization, kind, _windowEnd, 90)
              .filtered(
                  status: 'all',
                  afterLeadId: append ? pages.last.nextAfterLeadId : null);
      try {
        final page = await repo.list(query);
        if (!_current(repo, generation)) return;
        setState(() {
          if (!append) {
            pages.clear();
            _hidden.removeWhere((key) => key.$1 == kind);
          }
          pages.add(page);
          _failed.remove(kind);
        });
      } catch (_) {
        if (!_current(repo, generation)) return;
        setState(() {
          if (!append) pages.clear();
          _failed.add(kind);
        });
      }
    }));
    if (mounted && generation == _generation && identical(repo, _repo)) {
      setState(() {
        _loading = false;
        if (!repo.isCurrent) {
          for (final pages in _pages.values) {
            pages.clear();
          }
          _hidden.clear();
        }
      });
    }
  }

  String _status(RecommendationLead lead, bool delivered) =>
      switch (lead.status) {
        'sent' => delivered ? 'Delivered' : 'Delivery unverified',
        'pending' =>
          lead.expiresAt.isAfter(_now) ? 'Awaiting delivery' : 'Expired',
        'dismissed' => 'Dismissed',
        'expired' => 'Expired',
        'stale' => 'Unavailable',
        'revoked' => 'Permission withdrawn',
        _ => 'Unavailable',
      };

  bool _attention(String status) => const {
        'Delivery unverified',
        'Expired',
        'Unavailable',
        'Permission withdrawn',
      }.contains(status);

  Future<void> _open(RecommendationLead summary, bool delivered) async {
    if (_opening ||
        !_repo.isCurrent ||
        _hidden.contains((summary.kind, summary.id))) {
      return;
    }
    final repo = _repo, generation = _generation;
    _opening = true;
    final binding = _scope.value;
    await showDialog<void>(
      context: context,
      builder: (context) => _RecommendationDetail(
        scope: _scope,
        binding: binding,
        isCurrent: () => _current(repo, generation),
        status: (lead) =>
            _status(lead, delivered && lead.revision == summary.revision),
        load: () async {
          try {
            final lead = await repo.detail(summary);
            if (!_current(repo, generation)) {
              throw const RecommendationQueueUnavailable();
            }
            if (lead.status != summary.status ||
                lead.revision != summary.revision) {
              // Discard outdated list data. The drawer owns the fresh detail only.
              setState(() => _hidden.add((summary.kind, summary.id)));
            }
            return lead;
          } catch (_) {
            if (_current(repo, generation)) {
              setState(() => _hidden.add((summary.kind, summary.id)));
            }
            rethrow;
          }
        },
      ),
    );
    if (mounted && generation == _generation) _opening = false;
  }

  @override
  Widget build(BuildContext context) {
    final start = RecommendationQueueQuery.recent(
            _organization, 'content', _windowEnd, _days)
        .start;
    final loaded = <(RecommendationLead, bool)>[
      if (_repo.isCurrent)
        for (final pages in _pages.values)
          for (final page in pages)
            for (final lead in page.leads)
              if (!_hidden.contains((lead.kind, lead.id)))
                (lead, page.deliveredIds.contains(lead.id)),
    ]..sort((a, b) => b.$1.createdAt.compareTo(a.$1.createdAt));
    final visible = loaded.where((entry) {
      final (lead, delivered) = entry;
      return (_kind == 'all' || lead.kind == _kind) &&
          !lead.createdAt.isBefore(start) &&
          '${lead.memberLabel} ${lead.exerciseLabel} ${lead.targetLabel}'
              .toLowerCase()
              .contains(_search) &&
          (widget.tab != RecommendationMonitorTab.attention ||
              _attention(_status(lead, delivered)));
    }).toList();
    final overview = widget.tab == RecommendationMonitorTab.overview;
    final rows = overview ? visible.take(8) : visible;
    final canLoad = !overview && _filteredKinds.any(_hasMore);
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 620;
      final table = constraints.maxWidth >= 1080 &&
          MediaQuery.textScalerOf(context).scale(14) < 20;
      return ListView(
        padding:
            EdgeInsets.fromLTRB(narrow ? 12 : 20, 12, narrow ? 12 : 20, 24),
        children: [
          if (!_repo.enabled)
            const _MonitorMessage(
                'Recommendation queue is unavailable in this release.')
          else if (!_repo.isCurrent)
            const _MonitorMessage(
                'Your Admin session changed. Reopen Recommendations.')
          else ...[
            if (overview)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Wrap(spacing: 10, runSpacing: 10, children: [
                  _Metric(
                      'Records loaded', loaded.length, Icons.layers_outlined),
                  _Metric('Delivered', loaded.where((entry) => entry.$2).length,
                      Icons.check_circle_outline),
                  _Metric(
                      'Needs attention',
                      loaded
                          .where((entry) =>
                              _attention(_status(entry.$1, entry.$2)))
                          .length,
                      Icons.error_outline),
                ]),
              ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: narrow ? constraints.maxWidth - 24 : 285,
                  child: TextField(
                    key: const ValueKey('queue-search'),
                    decoration: const InputDecoration(
                      labelText: 'Search loaded records',
                      prefixIcon: Icon(Icons.search),
                      isDense: true,
                    ),
                    onChanged: (value) =>
                        setState(() => _search = value.trim().toLowerCase()),
                  ),
                ),
                _filter<String>(
                  'Type',
                  _kind,
                  const {
                    'all': 'All types',
                    'trainer': 'Coach',
                    'content': 'Tutorial'
                  },
                  (value) => setState(() => _kind = value),
                ),
                _filter<int>(
                  'Date range',
                  _days,
                  const {
                    7: 'Last 7 days',
                    30: 'Last 30 days',
                    90: 'Last 90 days'
                  },
                  (value) => setState(() => _days = value),
                ),
                IconButton(
                  tooltip: 'Reload records',
                  onPressed: _loading ? null : () => _load(reload: true),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_failed.isNotEmpty)
              _MonitorMessage(
                'Some recommendations could not be loaded.',
                action: TextButton(
                  onPressed: _loading ? null : () => _load(),
                  child: const Text('Retry'),
                ),
              ),
            if (_loading && loaded.isEmpty)
              const _MonitorSkeleton(label: 'Loading recommendations')
            else if (_loading)
              const LinearProgressIndicator(
                  semanticsLabel: 'Loading more recommendations'),
            if (!_loading && visible.isEmpty && _failed.isEmpty)
              _MonitorMessage(
                  widget.tab == RecommendationMonitorTab.attention &&
                          _search.isEmpty &&
                          _kind == 'all' &&
                          _days == 90
                      ? 'No issues in the loaded recommendations.'
                      : 'No recommendations match these filters.'),
            if (overview && visible.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text('Recent activity',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            if (visible.isNotEmpty && table)
              _TableLine(
                header: true,
                children: [
                  for (final heading in const [
                    'Member',
                    'Exercise',
                    'Type',
                    'Recommendation',
                    'Reason',
                    'Status',
                    'Created',
                    'Details',
                  ])
                    Text(heading),
                ],
              ),
            for (final (lead, delivered) in rows)
              _MonitorRow(
                lead: lead,
                status: _status(lead, delivered),
                table: table,
                onOpen: () => _open(lead, delivered),
              ),
            if (canLoad)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _loading ? null : () => _load(more: true),
                  child: const Text('Load more'),
                ),
              ),
            if (_filteredKinds.any((kind) =>
                _pages[kind]!.length == _maxPagesPerKind &&
                _pages[kind]!.last.nextAfterLeadId != null))
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                    'Showing the maximum number of records for this view.'),
              ),
          ],
        ],
      );
    });
  }

  Widget _filter<T>(String label, T value, Map<T, String> options,
          ValueChanged<T> onChanged) =>
      SizedBox(
        width: 170,
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label, isDense: true),
          items: options.entries
              .map((item) =>
                  DropdownMenuItem(value: item.key, child: Text(item.value)))
              .toList(),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      );
}

IconData _typeIcon(RecommendationLead lead) => lead.kind == 'trainer'
    ? Icons.person_outline_rounded
    : Icons.play_circle_outline_rounded;

String _type(RecommendationLead lead) =>
    lead.kind == 'trainer' ? 'Coach' : 'Tutorial';

List<String> _reasons(RecommendationLead lead) => lead.explanations
    .map((reason) =>
        recommendationPresentationReason(reason, lead.exerciseLabel))
    .toSet()
    .toList();

String _shortReason(RecommendationLead lead) {
  final reasons = _reasons(lead);
  return reasons.firstWhere(
      (reason) => !reason.startsWith('Guidance for your '),
      orElse: () =>
          '${queueObjectiveLabel(lead.objective)} for ${lead.exerciseLabel}');
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.lead,
    required this.status,
    required this.table,
    required this.onOpen,
  });
  final RecommendationLead lead;
  final String status;
  final bool table;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final member = Text(lead.memberLabel,
        style: const TextStyle(fontWeight: FontWeight.w700));
    final type = Wrap(
      spacing: 5,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(_typeIcon(lead), size: 17, color: AppColors.primary),
        Text(_type(lead))
      ],
    );
    final target = Text(lead.targetLabel,
        style: const TextStyle(fontWeight: FontWeight.w600));
    final reason = Text(_shortReason(lead));
    final date = Text(malaysiaDate(lead.createdAt));
    final open = TextButton(onPressed: onOpen, child: const Text('View'));
    final badge = _StatusBadge(status);
    if (table) {
      return _TableLine(children: [
        member,
        Text(lead.exerciseLabel),
        type,
        target,
        reason,
        badge,
        date,
        open,
      ]);
    }
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          member,
          Text(lead.exerciseLabel),
          const SizedBox(height: 10),
          type,
          target,
          const SizedBox(height: 5),
          reason,
          const SizedBox(height: 10),
          Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [badge, date]),
          Align(alignment: Alignment.centerRight, child: open),
        ]),
      ),
    );
  }
}

class _TableLine extends StatelessWidget {
  const _TableLine({this.header = false, required this.children});
  final bool header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            EdgeInsets.symmetric(horizontal: 14, vertical: header ? 14 : 4),
        decoration: BoxDecoration(
          color: header
              ? AppColors.primaryTint
              : Theme.of(context).colorScheme.surface,
          border: const Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: DefaultTextStyle.merge(
          style: header
              ? const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary)
              : null,
          child: Row(children: [
            for (var i = 0; i < children.length; i++)
              Expanded(
                flex: const [16, 12, 10, 17, 21, 15, 11, 8][i],
                child: Padding(
                  padding:
                      EdgeInsets.only(right: i == children.length - 1 ? 0 : 10),
                  child: children[i],
                ),
              ),
          ]),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Delivered' => const Color(0xff126446),
      'Delivery unverified' ||
      'Unavailable' ||
      'Expired' ||
      'Permission withdrawn' =>
        const Color(0xff815015),
      _ => AppColors.primary,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon);
  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.primaryTint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Wrap(
          spacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            Text('$label · $value',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _MonitorMessage extends StatelessWidget {
  const _MonitorMessage(this.text, {this.action});
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [Text(text), if (action != null) action!],
          ),
        ),
      );
}

class _MonitorSkeleton extends StatelessWidget {
  const _MonitorSkeleton({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        liveRegion: true,
        child: Column(children: [
          for (final fraction in const [.8, .63, .9])
            Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 18,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AppColors.primaryTint,
                  ),
                ),
              ),
            ),
        ]),
      );
}

class _RecommendationDetail extends StatefulWidget {
  const _RecommendationDetail({
    required this.scope,
    required this.binding,
    required this.isCurrent,
    required this.load,
    required this.status,
  });
  final ValueNotifier<int> scope;
  final int binding;
  final bool Function() isCurrent;
  final Future<RecommendationLead> Function() load;
  final String Function(RecommendationLead) status;

  @override
  State<_RecommendationDetail> createState() => _RecommendationDetailState();
}

class _RecommendationDetailState extends State<_RecommendationDetail> {
  RecommendationLead? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.scope.addListener(_scopeChanged);
    _load();
  }

  @override
  void dispose() {
    widget.scope.removeListener(_scopeChanged);
    super.dispose();
  }

  void _scopeChanged() {
    _detail = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _load() async {
    try {
      final detail = await widget.load();
      if (mounted && widget.isCurrent()) setState(() => _detail = detail);
    } catch (_) {
      if (mounted) setState(() => _detail = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final valid = widget.scope.value == widget.binding && widget.isCurrent();
    final detail = valid ? _detail : null;
    final theme = Theme.of(context);
    return Dialog(
      alignment: Alignment.centerRight,
      insetPadding: const EdgeInsets.all(12),
      child: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Text('Recommendation details',
                  style: theme.textTheme.titleLarge),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: detail != null
                    ? _VerifiedDetail(
                        detail: detail, status: widget.status(detail))
                    : !valid
                        ? const _MonitorMessage('Your Admin session changed.')
                        : _loading
                            ? const _MonitorSkeleton(
                                label: 'Verifying recommendation')
                            : _MonitorMessage(
                                'Recommendation details could not be verified.',
                                action: TextButton(
                                  onPressed: () {
                                    setState(() => _loading = true);
                                    _load();
                                  },
                                  child: const Text('Retry'),
                                ),
                              ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerifiedDetail extends StatelessWidget {
  const _VerifiedDetail({required this.detail, required this.status});
  final RecommendationLead detail;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reasons = _reasons(detail)
        .where((reason) => !reason.startsWith('Guidance for your '))
        .toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(
          radius: 23,
          backgroundColor: AppColors.primaryTint,
          foregroundColor: AppColors.primary,
          child: Icon(_typeIcon(detail)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_type(detail)),
            Text(detail.targetLabel, style: theme.textTheme.titleLarge),
          ]),
        ),
      ]),
      const SizedBox(height: 12),
      _StatusBadge(status),
      const SizedBox(height: 16),
      Text('Member', style: theme.textTheme.titleMedium),
      Text(detail.memberLabel),
      Text('${detail.exerciseLabel} · ${detail.category}'),
      const SizedBox(height: 16),
      Text('Why this recommendation?', style: theme.textTheme.titleMedium),
      Text(_shortReason(detail)),
      if (detail.specialization case final specialization?)
        Text('Specialization: $specialization'),
      if (detail.branchLabel case final branch?) Text('Branch: $branch'),
      Text('Learning objective: ${queueObjectiveLabel(detail.objective)}'),
      for (final reason in reasons.skip(1))
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(reason)),
      if (detail.scoredSessions case final count?)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('$count assessed ${count == 1 ? 'session' : 'sessions'}'),
        ),
      if (detail.score case final score?)
        Text('Estimated form score: ${score.toStringAsFixed(1)}%'),
      if (detail.coverage case final coverage?)
        Text('Tracking coverage: ${(coverage * 100).toStringAsFixed(1)}%'),
      const SizedBox(height: 12),
      Text('Created ${malaysiaTime(detail.createdAt)} MYT'),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Technical details'),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(detail.evidenceSummary),
          Text('Algorithm: ${detail.algorithmVersion}'),
          Text('Model: ${detail.model ?? 'None'}'),
          Text('Evidence version: ${detail.sourceVersion}'),
          Text('Configuration: ${detail.configVersion}'),
          Text('Expires: ${malaysiaTime(detail.expiresAt)} MYT'),
        ],
      ),
    ]);
  }
}
