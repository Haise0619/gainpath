import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class BranchReportDialog extends StatefulWidget {
  const BranchReportDialog(
      {super.key,
      required this.request,
      required this.range,
      this.fixedScope,
      this.embedded = false,
      this.category});
  final BranchRequest request;
  final DateTimeRange range;
  final String? fixedScope;
  final bool embedded;
  final String? category;

  @override
  State<BranchReportDialog> createState() => _BranchReportDialogState();
}

class _BranchReportDialogState extends State<BranchReportDialog> {
  late final Future<List<Map<String, dynamic>>> _branches =
      loadReportBranches(widget.request);
  late String? _branch = widget.fixedScope;
  late Future<Map<String, dynamic>>? _report =
      _branch == null ? null : _loadReport(_branch!);

  @override
  void didUpdateWidget(covariant BranchReportDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.fixedScope != oldWidget.fixedScope) _branch = widget.fixedScope;
    if (widget.range != oldWidget.range ||
        widget.fixedScope != oldWidget.fixedScope) {
      _report = _branch == null ? null : _loadReport(_branch!);
    }
  }

  Future<Map<String, dynamic>> _loadReport(String branch) => widget.request({
        'action': 'branchReport',
        if (branch == 'unassigned')
          'scope': 'unassigned'
        else
          'branchId': branch.substring('branch:'.length),
        'startAtMillis': widget.range.start.millisecondsSinceEpoch,
        'endAtMillis': widget.range.end.millisecondsSinceEpoch,
      });

  List<(String, Object?)> _metrics(Map<String, dynamic> result) => [
        ('Home branch members · current', result['homeMembers']),
        ('Assigned coaches · current', result['assignedCoaches']),
        if (_branch != 'unassigned') ...[
          ('Equipment units · current', result['equipmentUnits']),
          ('Maintenance units · current', result['maintenanceUnits']),
        ],
        ('Bookings created', result['bookingsCreated']),
        ('Completed sessions · appointment date', result['completedSessions']),
        ('Cancelled sessions · appointment date', result['cancelledSessions']),
        (
          'Coaching receipts · RM',
          switch (result['coachingMinor']) {
            final num value => (value / 100).toStringAsFixed(2),
            _ => null,
          }
        ),
        ('Accepted workouts with this scope', result['acceptedWorkouts']),
        if (_branch != 'unassigned') ...[
          ('Recorded gym visits', result['gymVisits']),
          ('Unique visiting members', result['uniqueVisitors']),
          ('Members with multiple visits', result['repeatVisitors']),
          (
            'Peak recorded hours · MYT',
            (result['peakHours'] as List? ?? [])
                .map((hour) => '${hour.toString().padLeft(2, '0')}:00')
                .join(' · ')
          ),
        ],
      ];

  String _myt(DateTime dt) => dt
      .toUtc()
      .add(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 16)
      .replaceFirst('T', ' ');

  Widget? _scopeChart(Map<String, dynamic> result) {
    final metrics = switch (widget.category) {
      'Engagement' => [('Recorded visits', 'gymVisits'),
          ('Unique visitors', 'uniqueVisitors'),
          ('Returning visitors', 'repeatVisitors')],
      'Overview' || 'Coaching' => [('Completed', 'completedSessions'),
          ('Cancelled', 'cancelledSessions')],
      _ => const <(String, String)>[],
    };
    if (_branch == 'unassigned' && widget.category == 'Engagement') return null;
    if (metrics.isEmpty || metrics.any((entry) => result[entry.$2] is! num)) return null;
    final maximum = metrics.fold<num>(0, (max, entry) {
      final value = result[entry.$2] as num;
      return value > max ? value : max;
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (label, key) in metrics)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$label · ${result[key]}'),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: maximum == 0 ? 0 : (result[key] as num) / maximum,
              ),
            ]),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final contents = <Widget>[
      Text('${_myt(widget.range.start)} – ${_myt(widget.range.end)} MYT'),
      const SizedBox(height: 12),
      if (widget.fixedScope == null)
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _branches,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Branches could not be loaded.');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Branch scope'),
              items: [
                const DropdownMenuItem(
                    value: 'unassigned', child: Text('Unassigned records')),
                for (final row in snapshot.data!)
                  DropdownMenuItem(
                      value: 'branch:${row['branchId']}',
                      child: Text(
                          '${row['displayName']}${row['status'] == 'inactive' ? ' (inactive)' : ''}',
                          overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _branch = value;
                    _report = _loadReport(value);
                  });
                }
              },
            );
          },
        ),
      if (_report != null)
        FutureBuilder<Map<String, dynamic>>(
          future: _report,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return const Text('Branch report unavailable for this range.');
            }
            final result = snapshot.data!;
            return Column(children: [
              if (_scopeChart(result) case final Widget chart) chart,
              for (final (label, value) in _metrics(result))
                ListTile(
                    dense: true,
                    title: Text(label),
                    trailing: Text(
                        value == null || value == '' ? '—' : value.toString())),
              const Text(
                  'Membership revenue remains in the organization-wide report.'),
              TextButton.icon(
                icon: const Icon(Icons.download),
                label: const Text('Export branch CSV'),
                onPressed: () => downloadCsv('gainpath-branch-report.csv', [
                  ['Branch scope', _spreadsheetText(result['branchName'])],
                  ['Start MYT', _myt(widget.range.start)],
                  ['End MYT (exclusive)', _myt(widget.range.end)],
                  ['Metric', 'Value'],
                  for (final (label, value) in _metrics(result)) [label, value],
                ]),
              ),
            ]);
          },
        ),
    ];
    if (widget.embedded) return Panel(child: Column(children: contents));
    return AlertDialog(
      title: const Text('Branch report'),
      content: SizedBox(
          width: 550, height: 520, child: ListView(children: contents)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Close'))
      ],
    );
  }
}

Future<List<Map<String, dynamic>>> loadReportBranches(
    BranchRequest request) async {
  final results = <Map<String, dynamic>>[];
  final seen = <String>{};
  String? cursor;
  do {
    final result = await request(
        {'action': 'list', if (cursor != null) 'afterId': cursor});
    results.addAll((result['records'] as List)
        .map((row) => Map<String, dynamic>.from(row as Map)));
    cursor = result['nextAfterId'] as String?;
    if (cursor != null && !seen.add(cursor)) {
      throw StateError('Branch pagination did not advance.');
    }
  } while (cursor != null);
  return results;
}

String _spreadsheetText(Object? raw) {
  final value = raw?.toString() ?? '';
  return RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
}
