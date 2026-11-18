import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

class BranchReportDialog extends StatefulWidget {
  const BranchReportDialog(
      {super.key, required this.request, required this.range});
  final BranchRequest request;
  final DateTimeRange range;

  @override
  State<BranchReportDialog> createState() => _BranchReportDialogState();
}

class _BranchReportDialogState extends State<BranchReportDialog> {
  late final Future<List<Map<String, dynamic>>> _branches = _loadBranches();
  String? _branch;
  Future<Map<String, dynamic>>? _report;

  Future<List<Map<String, dynamic>>> _loadBranches() async {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};
    String? cursor;
    do {
      final result = await widget
          .request({'action': 'list', if (cursor != null) 'afterId': cursor});
      results.addAll((result['records'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map)));
      cursor = result['nextAfterId'] as String?;
      if (cursor != null && !seen.add(cursor)) {
        throw StateError('Branch pagination did not advance.');
      }
    } while (cursor != null && mounted);
    return results;
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
        (
          'Coaching receipts · RM',
          ((result['coachingMinor'] as num? ?? 0) / 100).toStringAsFixed(2)
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

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Branch report'),
        content: SizedBox(
            width: 550,
            height: 520,
            child: ListView(children: [
              Text(
                  '${_myt(widget.range.start)} – ${_myt(widget.range.end)} MYT'),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _branches,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('Branches could not be loaded.');
                  }
                  if (!snapshot.hasData) return const LinearProgressIndicator();
                  return DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Branch scope'),
                    items: [
                      const DropdownMenuItem(
                          value: 'unassigned',
                          child: Text('Unassigned records')),
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
                      return const Text(
                          'Branch report unavailable for this range.');
                    }
                    final result = snapshot.data!;
                    return Column(children: [
                      for (final (label, value) in _metrics(result))
                        ListTile(
                            dense: true,
                            title: Text(label),
                            trailing: Text(value == null || value == ''
                                ? '—'
                                : value.toString())),
                      const Text(
                          'Membership revenue remains in the organization-wide report.'),
                      TextButton.icon(
                        icon: const Icon(Icons.download),
                        label: const Text('Export branch CSV'),
                        onPressed: () =>
                            downloadCsv('gainpath-branch-report.csv', [
                          [
                            'Branch scope',
                            _spreadsheetText(result['branchName'])
                          ],
                          ['Start MYT', _myt(widget.range.start)],
                          ['End MYT (exclusive)', _myt(widget.range.end)],
                          ['Metric', 'Value'],
                          for (final (label, value) in _metrics(result))
                            [label, value],
                        ]),
                      ),
                    ]);
                  },
                ),
            ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      );
}

String _spreadsheetText(Object? raw) {
  final value = raw?.toString() ?? '';
  return RegExp(r'^\s*[=+@-]').hasMatch(value) ? "'$value" : value;
}
