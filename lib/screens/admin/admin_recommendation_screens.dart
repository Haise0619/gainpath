import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M13.1 — View High-Risk Exercise Leaderboard.
class RiskLeaderboardScreen extends StatelessWidget {
  const RiskLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: PageBody(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text('Ranked by lowest average form score across all members.',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => showToast(context, 'Leaderboard exported.'),
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('Export'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...MockData.riskExercises.asMap().entries.map((e) {
            final row = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Row(
                  children: [
                    SizedBox(
                      width: 26,
                      child: Text('${e.key + 1}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                    Expanded(
                      child: Text(row[0],
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    Text(row[1],
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    statusPill(row[2]),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
          const Eyebrow('Missing tutorial content'),
          ...MockData.contentGaps.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  background: AppColors.dangerTint,
                  child: Row(
                    children: [
                      const Icon(Icons.videocam_off_rounded,
                          size: 19, color: AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g[0],
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text('${g[1]} avg form  ·  ${g[2]}',
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const RecommendationQueueScreen())),
            icon: const Icon(Icons.auto_awesome_rounded, size: 19),
            label: const Text('Open recommendation queue'),
          ),
        ],
      ),
    );
  }
}

/// AD-M13.2 — View Recommendation Queue, parameterised across the
/// trainer-matching and content-matching queues.
class RecommendationQueueScreen extends StatefulWidget {
  const RecommendationQueueScreen({super.key});

  @override
  State<RecommendationQueueScreen> createState() =>
      _RecommendationQueueScreenState();
}

class _RecommendationQueueScreenState extends State<RecommendationQueueScreen> {
  int _tab = 0;
  late List<RiskLead> _trainerLeads = [...MockData.atRiskLeads];
  late List<RiskLead> _contentLeads = [...MockData.contentLeads];

  @override
  Widget build(BuildContext context) {
    final leads = _tab == 0 ? _trainerLeads : _contentLeads;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recommendations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh queue',
            onPressed: () {
              setState(() {
                _trainerLeads = [...MockData.atRiskLeads];
                _contentLeads = [...MockData.contentLeads];
              });
              showToast(context, 'Queue refreshed with current data.');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Coaches')),
                ButtonSegment(value: 1, label: Text('Content')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: leads.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.inbox_rounded,
                              size: 40, color: AppColors.hairline),
                          const SizedBox(height: 14),
                          Text('Queue is clear. Refresh to check for new leads.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: leads
                        .map((l) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Panel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(l.memberName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium),
                                              Text(
                                                  'Struggling with ${l.weakCategory}',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium),
                                            ],
                                          ),
                                        ),
                                        Text('${l.score}%',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.danger)),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryTint,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                              _tab == 0
                                                  ? Icons.person_rounded
                                                  : Icons
                                                      .play_circle_outline_rounded,
                                              size: 18,
                                              color: AppColors.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _tab == 0
                                                  ? 'Suggested coach: ${l.suggestion}'
                                                  : 'Suggested video: ${l.suggestion}',
                                              style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600),
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
                                            style: FilledButton.styleFrom(
                                                minimumSize:
                                                    const Size(0, 42)),
                                            onPressed: () {
                                              setState(() {
                                                if (_tab == 0) {
                                                  _trainerLeads.remove(l);
                                                } else {
                                                  _contentLeads.remove(l);
                                                }
                                              });
                                              showToast(context,
                                                  'Sent to ${l.memberName}.');
                                            },
                                            child: const Text('Send'),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                                minimumSize:
                                                    const Size(0, 42)),
                                            onPressed: () {
                                              setState(() {
                                                if (_tab == 0) {
                                                  _trainerLeads.remove(l);
                                                } else {
                                                  _contentLeads.remove(l);
                                                }
                                              });
                                              showToast(
                                                  context, 'Suggestion dismissed.');
                                            },
                                            child: const Text('Dismiss'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
