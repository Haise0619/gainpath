import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import 'reports/report_widgets.dart' show ReportSection;
import 'admin_dialogs.dart' show AdminDialog;

/// AD-M13.1/M13.2 — AI-Powered Trainer and Content Recommendation. One
/// continuous page — Leaderboard, Trainer Matching, Content
/// Recommendations as three anchor-jump sections instead of a leaderboard
/// page that pushes a separate AppBar'd queue screen — matching the
/// pattern already established for the rest of this admin console.
class RiskLeaderboardScreen extends StatefulWidget {
  const RiskLeaderboardScreen({super.key});

  @override
  State<RiskLeaderboardScreen> createState() => _RiskLeaderboardScreenState();
}

class _RiskLeaderboardScreenState extends State<RiskLeaderboardScreen> {
  final _leaderboardKey = GlobalKey();
  final _trainerKey = GlobalKey();
  final _contentKey = GlobalKey();

  late int _threshold = MockData.postureRiskThreshold;
  String _category = 'All';

  late final List<RiskLead> _trainerLeads = [...MockData.atRiskLeads];
  int _trainerPoolIndex = 0;
  String _trainerQuery = '';

  late final List<RiskLead> _contentLeads = [...MockData.contentLeads];
  int _contentPoolIndex = 0;
  String _contentQuery = '';

  void _jumpTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 320), curve: Curves.easeOut, alignment: 0.02);
  }

  void _investigateInTrainerQueue(String exerciseName) {
    setState(() => _trainerQuery = exerciseName);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(_trainerKey));
  }

  void _refreshTrainerQueue() {
    if (_trainerPoolIndex < MockData.trainerLeadsPool.length) {
      setState(() {
        _trainerLeads.add(MockData.trainerLeadsPool[_trainerPoolIndex]);
        _trainerPoolIndex++;
      });
      showToast(context, '1 new lead added to the queue.');
    } else {
      showToast(context, 'No new leads right now.');
    }
  }

  void _refreshContentQueue() {
    if (_contentPoolIndex < MockData.contentLeadsPool.length) {
      setState(() {
        _contentLeads.add(MockData.contentLeadsPool[_contentPoolIndex]);
        _contentPoolIndex++;
      });
      showToast(context, '1 new lead added to the queue.');
    } else {
      showToast(context, 'No new leads right now.');
    }
  }

  Future<void> _send(RiskLead lead, List<RiskLead> list, {required bool isCoach}) async {
    setState(() => list.remove(lead));
    showToast(context, isCoach ? 'Sent to ${lead.suggestion} for ${lead.memberName}.' : 'Surfaced to ${lead.memberName}.');
  }

  Future<void> _dismiss(RiskLead lead, List<RiskLead> list) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => _DismissReasonDialog(memberName: lead.memberName),
    );
    if (reason != null && reason.isNotEmpty) {
      setState(() => list.remove(lead));
      showToast(context, 'Dismissed — ${lead.memberName} stays in the queue history.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Recommendations', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Where members struggle most, and the coach or content leads matched to help.',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 16),
            _anchorNav(),
            const SizedBox(height: 26),
            _leaderboardSection(context),
            _trainerQueueSection(context),
            _contentQueueSection(context),
          ],
        ),
      ),
    );
  }

  Widget _anchorNav() {
    final items = [
      ('Leaderboard', _leaderboardKey),
      ('Trainer Matching', _trainerKey),
      ('Content Recommendations', _contentKey),
    ];
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, key) = items[i];
          return ActionChip(
            label: Text(label),
            onPressed: () => _jumpTo(key),
            backgroundColor: AppColors.primaryTint,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          );
        },
      ),
    );
  }

  Widget _leaderboardSection(BuildContext context) {
    const categories = ['All', 'Lower Body', 'Upper Body', 'Core'];
    final rows = MockData.riskExercises.where((e) => _category == 'All' || e[2] == _category).toList();
    final highRiskCount =
        MockData.riskExercises.where((e) => MockData.riskTierFor(int.parse(e[1].replaceAll('%', ''))) == 'High').length;
    final gaps = MockData.contentGaps;

    return ReportSection(
      anchorKey: _leaderboardKey,
      title: 'High-Risk Exercise Leaderboard',
      subtitle: 'Ranked by lowest average form score across all members',
      live: true,
      tagLabel: 'Live · threshold-driven',
      exportFilename: 'high_risk_leaderboard.csv',
      exportRows: () => [
        ['Rank', 'Exercise', 'Avg score', 'Category', 'Risk tier'],
        ...List.generate(MockData.riskExercises.length, (i) {
          final e = MockData.riskExercises[i];
          return [i + 1, e[0], e[1], e[2], MockData.riskTierFor(int.parse(e[1].replaceAll('%', '')))];
        }),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: StatTile('$highRiskCount', 'Exercises flagged High risk', valueColor: AppColors.danger)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${gaps.length}', 'Have no tutorial video')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('$_threshold%', 'Current risk threshold')),
            ],
          ),
          const SizedBox(height: 16),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune_rounded, size: 16, color: AppColors.inkSoft),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Flag exercises scoring below $_threshold% as High risk',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
                Slider(
                  value: _threshold.toDouble(),
                  min: 55,
                  max: 85,
                  divisions: 6,
                  label: '$_threshold%',
                  onChanged: (v) => setState(() {
                    _threshold = v.round();
                    MockData.postureRiskThreshold = _threshold;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            children: categories.map((c) {
              final selected = c == _category;
              return ChoiceChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => setState(() => _category = c),
                backgroundColor: AppColors.surface,
                selectedColor: AppColors.primary,
                labelStyle:
                    TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.ink),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999), side: const BorderSide(color: AppColors.hairline)),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Panel(
            child: SizedBox(
              height: 190,
              child: SfCartesianChart(
                plotAreaBorderWidth: 0,
                primaryXAxis: const CategoryAxis(
                  majorGridLines: MajorGridLines(width: 0),
                  axisLine: AxisLine(width: 0),
                  labelIntersectAction: AxisLabelIntersectAction.wrap,
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                primaryYAxis: const NumericAxis(
                  minimum: 0,
                  maximum: 100,
                  majorGridLines: MajorGridLines(width: 0.6, color: AppColors.hairline),
                  axisLine: AxisLine(width: 0),
                  labelStyle: TextStyle(fontSize: 10, color: AppColors.inkSoft),
                ),
                tooltipBehavior: TooltipBehavior(enable: true, header: '', format: 'point.x  ·  point.y%'),
                series: <CartesianSeries<List<String>, String>>[
                  ColumnSeries<List<String>, String>(
                    dataSource: rows,
                    xValueMapper: (e, _) => e[0],
                    yValueMapper: (e, _) => int.parse(e[1].replaceAll('%', '')),
                    pointColorMapper: (e, _) {
                      final tier = MockData.riskTierFor(int.parse(e[1].replaceAll('%', '')));
                      return tier == 'High'
                          ? AppColors.danger
                          : tier == 'Moderate'
                              ? AppColors.warning
                              : AppColors.success;
                    },
                    width: 0.6,
                    borderRadius: BorderRadius.circular(6),
                    onPointTap: (details) {
                      final i = details.pointIndex;
                      if (i != null) _investigateInTrainerQueue(rows[i][0]);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.inkSoft),
              const SizedBox(width: 6),
              Text('Tap a bar to see matched members in Trainer Matching below',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 14),
          ...List.generate(rows.length, (i) {
            final e = rows[i];
            final pct = int.parse(e[1].replaceAll('%', ''));
            final tier = MockData.riskTierFor(pct);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                onTap: () => _investigateInTrainerQueue(e[0]),
                child: Row(
                  children: [
                    SizedBox(width: 26, child: Text('${i + 1}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(e[0], style: Theme.of(context).textTheme.titleMedium),
                          Text(e[2], style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(e[1], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    statusPill(tier),
                  ],
                ),
              ),
            );
          }),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 4),
            const Eyebrow('Content gap report — high-risk exercises with no tutorial'),
            ...gaps.map((g) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    background: AppColors.dangerTint,
                    child: Row(
                      children: [
                        const Icon(Icons.videocam_off_rounded, size: 19, color: AppColors.danger),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(g[0], style: Theme.of(context).textTheme.titleMedium),
                              Text('${g[1]} avg form  ·  ${g[2]}', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => showToast(context, 'Opening the tutorial uploader for ${g[0]}.'),
                          child: const Text('Add tutorial'),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _trainerQueueSection(BuildContext context) {
    final visible =
        _trainerLeads.where((l) => _matches(l, _trainerQuery)).toList();
    return ReportSection(
      anchorKey: _trainerKey,
      title: 'Trainer Matching Leads',
      subtitle: 'At-risk members matched to a coach',
      live: true,
      tagLabel: 'Live queue',
      exportFilename: 'trainer_matching_leads.csv',
      exportRows: () => [
        ['Member', 'Weak movement', 'Score', 'Suggested coach'],
        ..._trainerLeads.map((l) => [l.memberName, l.weakCategory, l.score, l.suggestion]),
      ],
      child: _queueBody(
        context,
        leads: visible,
        query: _trainerQuery,
        onQueryChanged: (v) => setState(() => _trainerQuery = v),
        onRefresh: _refreshTrainerQueue,
        isCoach: true,
        list: _trainerLeads,
      ),
    );
  }

  Widget _contentQueueSection(BuildContext context) {
    final visible =
        _contentLeads.where((l) => _matches(l, _contentQuery)).toList();
    return ReportSection(
      anchorKey: _contentKey,
      title: 'Content Recommendation Leads',
      subtitle: 'At-risk members matched to a tutorial video',
      live: true,
      tagLabel: 'Live queue',
      exportFilename: 'content_recommendation_leads.csv',
      exportRows: () => [
        ['Member', 'Weak movement', 'Score', 'Suggested video'],
        ..._contentLeads.map((l) => [l.memberName, l.weakCategory, l.score, l.suggestion]),
      ],
      child: _queueBody(
        context,
        leads: visible,
        query: _contentQuery,
        onQueryChanged: (v) => setState(() => _contentQuery = v),
        onRefresh: _refreshContentQueue,
        isCoach: false,
        list: _contentLeads,
      ),
    );
  }

  bool _matches(RiskLead l, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return l.memberName.toLowerCase().contains(q) || l.weakCategory.toLowerCase().contains(q);
  }

  Widget _queueBody(
    BuildContext context, {
    required List<RiskLead> leads,
    required String query,
    required ValueChanged<String> onQueryChanged,
    required VoidCallback onRefresh,
    required bool isCoach,
    required List<RiskLead> list,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: onQueryChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Search by member or movement',
                  prefixIcon: Icon(Icons.search_rounded, size: 19),
                ),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Refresh'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (leads.isEmpty)
          Panel(
            child: SizedBox(
              height: 100,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.inbox_rounded, size: 30, color: AppColors.hairline),
                    const SizedBox(height: 8),
                    Text(query.isEmpty ? 'Queue is clear. Refresh to check for new leads.' : 'No leads match that search.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
          )
        else
          ...leads.map((l) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(l.memberName, style: Theme.of(context).textTheme.titleMedium),
                                Text('Struggling with ${l.weakCategory}', style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                          Text('${l.score}%',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.danger)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            Icon(isCoach ? Icons.person_rounded : Icons.play_circle_outline_rounded,
                                size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                isCoach ? 'Suggested coach: ${l.suggestion}' : 'Suggested video: ${l.suggestion}',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              style: FilledButton.styleFrom(minimumSize: const Size(0, 42)),
                              onPressed: () => _send(l, list, isCoach: isCoach),
                              child: const Text('Send'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                              onPressed: () => _dismiss(l, list),
                              child: const Text('Dismiss'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }
}

class _DismissReasonDialog extends StatefulWidget {
  final String memberName;
  const _DismissReasonDialog({required this.memberName});

  @override
  State<_DismissReasonDialog> createState() => _DismissReasonDialogState();
}

class _DismissReasonDialogState extends State<_DismissReasonDialog> {
  final _reason = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminDialog(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dismiss this suggestion?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('${widget.memberName} will not see this recommendation. Tell us why so future matches improve.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 14),
          TextField(
            controller: _reason,
            maxLines: 2,
            autofocus: true,
            decoration: InputDecoration(hintText: 'Reason for dismissing', errorText: _error, isDense: true),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    if (_reason.text.trim().isEmpty) {
                      setState(() => _error = 'A reason is required.');
                      return;
                    }
                    Navigator.pop(context, _reason.text.trim());
                  },
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
