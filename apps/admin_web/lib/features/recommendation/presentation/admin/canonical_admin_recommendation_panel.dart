import 'package:flutter/material.dart';
import 'recommendation_monitor.dart';
import '../../application/canonical_admin_recommendation_repository.dart';
import '../../application/recommendation_queue.dart'
    show malaysiaDate, malaysiaTime;

class CanonicalAdminRecommendationPanel extends StatefulWidget {
  const CanonicalAdminRecommendationPanel(
      {super.key,
      required this.repository,
      this.history = false,
      this.tab,
      this.onUnavailable,
      this.clock});
  final CanonicalAdminRecommendationRepository repository;
  final bool history;
  final RecommendationMonitorTab? tab;
  final VoidCallback? onUnavailable;
  final DateTime Function()? clock;
  @override
  State<CanonicalAdminRecommendationPanel> createState() =>
      _CanonicalAdminRecommendationPanelState();
}

class _CanonicalAdminRecommendationPanelState
    extends State<CanonicalAdminRecommendationPanel> {
  final _records = <CanonicalAdminRecommendation>[];
  String _search = '', _kind = 'all', _status = 'all';
  String? _next, _error;
  bool _loading = false, _working = false;
  int _generation = 0;
  DateTime get _now => (widget.clock ?? DateTime.now)().toUtc();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CanonicalAdminRecommendationPanel old) {
    super.didUpdateWidget(old);
    if (!identical(old.repository, widget.repository)) {
      _records.clear();
      _next = null;
      _load();
    }
  }

  bool _current(CanonicalAdminRecommendationRepository repo, int generation) =>
      mounted &&
      identical(repo, widget.repository) &&
      generation == _generation &&
      repo.isCurrent;
  void _lost() {
    if (!mounted) {
      return;
    }
    setState(() {
      _records.clear();
      _next = null;
      _loading = false;
      _working = false;
      _error = 'Your Admin session changed. Reopen Recommendations.';
    });
  }

  Future<void> _load({bool append = false}) async {
    final repo = widget.repository, generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await repo.list(afterId: append ? _next : null);
      if (!_current(repo, generation)) {
        if (mounted && identical(repo, widget.repository) && !repo.isCurrent) {
          _lost();
        }
        return;
      }
      if (append &&
          page.records.any((r) => _records.any((old) => old.id == r.id))) {
        throw const FormatException('Repeated queue page.');
      }
      setState(() {
        if (!append) _records.clear();
        _records.addAll(page.records);
        _next = page.nextAfterId;
        _loading = false;
      });
    } catch (_) {
      if (!mounted ||
          !identical(repo, widget.repository) ||
          generation != _generation) {
        return;
      }
      if (!repo.isCurrent) {
        _lost();
        return;
      }
      if (!repo.enabled && widget.onUnavailable != null) {
        widget.onUnavailable!();
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Recommendations could not be verified. Retry.';
      });
    }
  }

  String _label(CanonicalAdminRecommendation r) =>
      !['dismissed', 'withdrawn'].contains(r.status) &&
              !r.expiresAt.isAfter(_now)
          ? 'Expired'
          : const {
              'pending': 'Awaiting delivery',
              'prepared': 'Delivery unverified',
              'delivered': 'Delivered',
              'dismissed': 'Dismissed',
              'withdrawn': 'Withdrawn / no longer eligible'
            }[r.status]!;
  Future<void> _review(CanonicalAdminRecommendation cached) async {
    if (_working || _loading) {
      return;
    }
    final repo = widget.repository, generation = _generation;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final lead = await repo.detail(cached);
      if (!_current(repo, generation)) {
        _lost();
        return;
      }
      setState(() => _working = false);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
              alignment: Alignment.centerRight,
              insetPadding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Recommendation details',
                                style: Theme.of(ctx).textTheme.titleLarge),
                            const SizedBox(height: 16),
                            Text(lead.title,
                                style: Theme.of(ctx).textTheme.titleMedium),
                            Text(
                                '${lead.exerciseLabel} · ${lead.kind == 'trainer' ? 'Coach' : 'Tutorial'}'),
                            const SizedBox(height: 12),
                            Text('Suggested: ${lead.targetLabel}'),
                            const SizedBox(height: 12),
                            if (lead.evidenceSummary != null)
                              Text(lead.evidenceSummary!),
                            Text(lead.summary),
                            const SizedBox(height: 16),
                            Text('Why this suggestion',
                                style: Theme.of(ctx).textTheme.titleMedium),
                            for (final reason in lead.explanations)
                              Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(reason)),
                            const SizedBox(height: 12),
                            Text(_label(lead)),
                            ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Technical Details'),
                                children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                          'Member account: ${lead.memberId}\nPolicy: ${lead.policyVersion}\nEvidence: ${lead.evidenceFingerprint}\nCreated: ${malaysiaTime(lead.createdAt)} MYT\nExpires: ${malaysiaTime(lead.expiresAt)} MYT${lead.deliveredAt == null ? '' : '\nDelivered: ${malaysiaTime(lead.deliveredAt!)} MYT'}'))
                                ]),
                            const SizedBox(height: 12),
                            Wrap(spacing: 8, runSpacing: 8, children: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('Close')),
                            ])
                          ])))));
    } catch (_) {
      if (!_current(repo, generation)) {
        _lost();
        return;
      }
      setState(() {
        _working = false;
        _records.clear();
        _next = null;
        _error =
            'Recommendation details could not be verified. Reload records before reviewing again.';
      });
    }
  }

  Widget _filter(String label, String value, List<(String, String)> choices,
          ValueChanged<String?> changed) =>
      SizedBox(
          width: 210,
          child: DropdownButtonFormField<String>(
              initialValue: value,
              key: ValueKey('$label-$value'),
              isExpanded: true,
              decoration: InputDecoration(labelText: label),
              items: choices
                  .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                  .toList(),
              onChanged: _working || _loading ? null : changed));
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final current = widget.repository.isCurrent;
        final records = current ? _records : <CanonicalAdminRecommendation>[];
        final tab = widget.tab ??
            (widget.history
                ? RecommendationMonitorTab.history
                : RecommendationMonitorTab.overview);
        final visible = records
            .where((r) =>
                (tab != RecommendationMonitorTab.attention ||
                    const [
                      'Delivery unverified',
                      'Expired',
                      'Withdrawn / no longer eligible'
                    ].contains(_label(r))) &&
                (_kind == 'all' || r.kind == _kind) &&
                (_status == 'all' || r.status == _status) &&
                '${r.title} ${r.exerciseLabel} ${r.targetLabel}'
                    .toLowerCase()
                    .contains(_search))
            .toList();
        final wide = c.maxWidth >= 1100 &&
            MediaQuery.textScalerOf(context).scale(14) < 22;
        return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (!current)
                const Text(
                    'Your Admin session changed. Reopen Recommendations.')
              else if (!_loading && !widget.repository.enabled)
                const Text(
                    'Recommendations are unavailable while evidence, permission and delivery policies await review.')
              else ...[
                Text(
                    widget.history
                        ? 'Authorized recommendation history'
                        : 'Recent recommendation activity',
                    style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 12),
                Wrap(spacing: 16, runSpacing: 8, children: [
                  Text(
                      'Awaiting delivery: ${records.where((r) => r.actionable(_now)).length}'),
                  Text(
                      'Delivered: ${records.where((r) => r.status == 'delivered').length}'),
                  Text(
                      'Prepared: ${records.where((r) => r.status == 'prepared').length}'),
                  Text(
                      'Dismissed: ${records.where((r) => r.status == 'dismissed').length}')
                ]),
                const SizedBox(height: 4),
                const Text(
                    'Counts cover loaded, currently authorized records. Withdrawn permissions hide workout evidence and suggestions.'),
                const SizedBox(height: 16),
                Wrap(spacing: 12, runSpacing: 12, children: [
                  SizedBox(
                      width: c.maxWidth < 600 ? c.maxWidth - 40 : 300,
                      child: TextField(
                          decoration: const InputDecoration(
                              labelText: 'Search loaded records',
                              prefixIcon: Icon(Icons.search)),
                          onChanged: (v) => setState(
                              () => _search = v.trim().toLowerCase()))),
                  _filter(
                      'Type',
                      _kind,
                      const [
                        ('all', 'All types'),
                        ('content', 'Tutorial'),
                        ('trainer', 'Coach')
                      ],
                      (v) => setState(() => _kind = v ?? 'all')),
                  if (tab == RecommendationMonitorTab.history)
                    _filter(
                        'Status',
                        _status,
                        const [
                          ('all', 'All history'),
                          ('prepared', 'Prepared'),
                          ('delivered', 'Delivered'),
                          ('dismissed', 'Dismissed'),
                          ('withdrawn', 'Permission withdrawn')
                        ],
                        (v) => setState(() => _status = v ?? 'all')),
                  OutlinedButton.icon(
                      onPressed: _loading || _working ? null : () => _load(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reload records'))
                ]),
                if (_loading || _working)
                  const LinearProgressIndicator(
                      semanticsLabel: 'Verifying recommendations'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                          liveRegion: true,
                          child: Text(_error!,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.error)))),
                if (!_loading && visible.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No recommendations match these filters.')),
                const SizedBox(height: 16),
                for (final r in visible)
                  Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                          border: Border(
                              bottom: BorderSide(
                                  color: Theme.of(context).dividerColor))),
                      child: wide
                          ? Row(children: [
                              Expanded(
                                  flex: 2,
                                  child: Text(r.memberLabel ?? r.memberId)),
                              Expanded(flex: 2, child: Text(r.exerciseLabel)),
                              Expanded(
                                  child: Text(r.kind == 'trainer'
                                      ? 'Coach'
                                      : 'Tutorial')),
                              Expanded(flex: 2, child: Text(r.targetLabel)),
                              Expanded(flex: 3, child: Text(r.summary)),
                              Expanded(flex: 2, child: Text(_label(r))),
                              Expanded(
                                  flex: 2,
                                  child: Text(malaysiaDate(r.createdAt))),
                              TextButton(
                                  onPressed: _working || _loading
                                      ? null
                                      : () => _review(r),
                                  child: const Text('View'))
                            ])
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(r.memberLabel ?? r.memberId),
                                  Text(r.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  Text(
                                      '${r.exerciseLabel} · ${r.kind == 'trainer' ? 'Coach' : 'Tutorial'}'),
                                  const SizedBox(height: 6),
                                  Text(r.targetLabel),
                                  Text(r.summary),
                                  Text(
                                      '${_label(r)} · ${malaysiaDate(r.createdAt)}'),
                                  Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                          onPressed: _working || _loading
                                              ? null
                                              : () => _review(r),
                                          child: const Text('View')))
                                ])),
                if (_next != null)
                  TextButton(
                      onPressed: _working || _loading
                          ? null
                          : () => _load(append: true),
                      child: const Text('Load more')),
              ],
              if (_error != null && !widget.repository.enabled)
                TextButton(
                    onPressed: _loading ? null : () => _load(),
                    child: const Text('Retry')),
            ]));
      });
}
