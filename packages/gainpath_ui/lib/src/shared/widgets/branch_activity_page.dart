import 'package:flutter/material.dart';
import '../../tokens/app_theme.dart';
import 'branch_visit_qr_dialog.dart';
import 'branch_directory_page.dart' show BranchRequest;

class BranchActivityPage extends StatefulWidget {
  const BranchActivityPage(
      {super.key,
      required this.title,
      required this.request,
      this.branchId,
      this.admin = false,
      this.visits = false,
      this.embedded = false,
      this.canIssueVisitCode = true});

  final String title;
  final BranchRequest request;
  final String? branchId;
  final bool admin, visits, embedded, canIssueVisitCode;

  @override
  State<BranchActivityPage> createState() => _BranchActivityPageState();
}

class _BranchActivityPageState extends State<BranchActivityPage> {
  List<Map<String, dynamic>> _records = [];
  String? _next;
  bool _loading = false;
  String? _error;

  String get _action => widget.visits
      ? (widget.admin ? 'branchVisits' : 'myVisits')
      : 'inventory';

  Future<Map<String, dynamic>> _request(String action,
          [Map<String, Object?> data = const {}]) =>
      widget.request({
        'action': action,
        if (widget.branchId != null) 'branchId': widget.branchId,
        ...data
      });

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool append = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _request(_action, {if (append) 'afterId': _next});
      final rows = (result['records'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map));
      if (mounted) {
        setState(() {
          _records = [if (append) ..._records, ...rows];
          _next = result['nextAfterId'] as String?;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load records. Refresh to retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCode() async {
    try {
      final result = await _request('issueVisitCode');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (_) => BranchVisitQrDialog(
                first: result,
                refresh: () => _request('issueVisitCode'),
              ));
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not generate the visit code.');
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? item]) async {
    try {
      final catalog = <Map<String, dynamic>>[];
      if (item == null) {
        String? cursor;
        do {
          final result = await _request(
              'catalog', {if (cursor != null) 'afterId': cursor});
          catalog.addAll((result['records'] as List)
              .map((row) => Map<String, dynamic>.from(row as Map)));
          cursor = result['nextAfterId'] as String?;
        } while (cursor != null && mounted);
      }
      if (!mounted) return;
      final result = await showDialog<Map<String, Object?>>(
          context: context,
          builder: (_) => _InventoryEditor(item: item, catalog: catalog));
      if (result == null || !mounted) return;
      await _request(
          result['remove'] == true ? 'removeInventory' : 'saveInventory',
          result);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Could not save inventory. Check the equipment and counts.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (widget.admin && widget.visits)
        TextButton(
          onPressed: widget.canIssueVisitCode ? _showCode : null,
          child: const Text('Generate QR'),
        ),
      if (widget.admin && !widget.visits)
        TextButton(
            onPressed: () => _edit(), child: const Text('Add equipment')),
      IconButton(
          tooltip: 'Refresh',
          onPressed: _loading ? null : () => _load(),
          icon: const Icon(Icons.refresh)),
    ];

    if (widget.visits && !widget.admin) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Gym Visits'),
          actions: actions,
        ),
        body: _buildMemberVisitsView(),
      );
    }

    final body =
        ListView(padding: EdgeInsets.all(widget.embedded ? 28 : 16), children: [
      if (widget.admin && widget.visits && !widget.canIssueVisitCode)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Only active branches can issue a gym check-in QR.'),
        ),
      if (_loading) const LinearProgressIndicator(),
      if (_error != null) Text(_error!),
      if (!_loading && _error == null && _records.isEmpty)
        Text(widget.visits
            ? 'No gym visits recorded.'
            : 'No equipment recorded.'),
      for (final row in _records)
        Card(
            child: ListTile(
          title: Text(
              (widget.visits ? row['branchName'] : row['name'])?.toString() ??
                  'Unavailable'),
          subtitle: Text(widget.visits
              ? '${_formatDate(row['checkedInAtMillis'])}${widget.admin ? ' · ${row['memberId']}' : ''}'
              : '${row['usable']} usable · ${row['maintenance']} in maintenance · ${row['quantity']} total'),
          trailing: widget.admin && !widget.visits
              ? IconButton(
                  tooltip: 'Edit equipment',
                  onPressed: () => _edit(row),
                  icon: const Icon(Icons.edit_outlined))
              : null,
        )),
      if (_next != null)
        TextButton(
            onPressed: _loading ? null : () => _load(append: true),
            child: const Text('Load more')),
    ]);
    if (widget.embedded) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child:
              Wrap(alignment: WrapAlignment.end, spacing: 8, children: actions),
        ),
        Expanded(child: body),
      ]);
    }
    return Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: actions),
        body: body);
  }

  Widget _buildMemberVisitsView() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final row in _records) {
      final key = _formatCalendarDate(
          row['checkedInAtMillis'] ?? row['timestampMillis']);
      (grouped[key] ??= []).add(row);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gym visits',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: AppColors.ink,
                        ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Your visits across GainPath gyms.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            if (_records.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_records.length} loaded',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (_loading && _records.isEmpty) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Text(_error!, style: const TextStyle(color: AppColors.danger)),
          ),
        if (!_loading && _error == null && _records.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No gym visits recorded yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Scan the QR code at any GainPath gym counter to record your attendance and keep track of your visits.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.inkSoft),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.hairline),
            ),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.hairline),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            size: 19,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${entry.value[i]['branchName'] ?? 'GainPath Gym'} — ${_formatTimeOnly(entry.value[i]['checkedInAtMillis'] ?? entry.value[i]['timestampMillis'])}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 3),
                              const Row(
                                children: [
                                  Icon(Icons.verified_rounded,
                                      size: 12, color: AppColors.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified check-in',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (_next != null) ...[
          const SizedBox(height: 18),
          Center(
            child: OutlinedButton(
              onPressed: _loading ? null : () => _load(append: true),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(_loading ? 'Loading…' : 'Load more visits'),
            ),
          ),
        ],
      ],
    );
  }
}

String _formatDate(Object? millis) {
  if (millis is! num) return 'Time unavailable';
  final time = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
      .add(const Duration(hours: 8));
  return '${time.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} MYT';
}

String _formatCalendarDate(Object? millis) {
  if (millis is! num) return 'Date unavailable';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
      .add(const Duration(hours: 8));
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  final weekday = weekdays[(dt.weekday - 1) % 7];
  final month = months[(dt.month - 1) % 12];
  return '$weekday, ${dt.day} $month ${dt.year}';
}

String _formatTimeOnly(Object? millis) {
  if (millis is! num) return 'Time unavailable';
  final dt = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
      .add(const Duration(hours: 8));
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour >= 12 ? 'PM' : 'AM';
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$hour:$minute $period';
}

class _InventoryEditor extends StatefulWidget {
  const _InventoryEditor({this.item, required this.catalog});
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> catalog;
  @override
  State<_InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<_InventoryEditor> {
  late String? _id = widget.item?['equipmentId'] as String?;
  late final _quantity =
      TextEditingController(text: '${widget.item?['quantity'] ?? 1}');
  late final _maintenance =
      TextEditingController(text: '${widget.item?['maintenance'] ?? 0}');
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _maintenance.dispose();
    super.dispose();
  }

  void _save() {
    final quantity = int.tryParse(_quantity.text),
        maintenance = int.tryParse(_maintenance.text);
    if (_id == null ||
        quantity == null ||
        maintenance == null ||
        quantity < 0 ||
        quantity > 10000 ||
        maintenance < 0 ||
        maintenance > quantity) {
      setState(() => _error = 'Select equipment and enter valid quantities.');
      return;
    }
    Navigator.pop(context,
        {'equipmentId': _id, 'quantity': quantity, 'maintenance': maintenance});
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.item == null ? 'Add equipment' : 'Edit equipment'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (widget.item == null)
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Equipment'),
              items: [
                for (final item in widget.catalog)
                  if (item['equipmentId'] is String && item['name'] is String)
                    DropdownMenuItem(
                        value: item['equipmentId'] as String,
                        child: Text(item['name'] as String,
                            overflow: TextOverflow.ellipsis))
              ],
              onChanged: (id) => setState(() => _id = id),
            )
          else
            Text(widget.item!['name'] as String),
          TextField(
              controller: _quantity,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Total quantity')),
          TextField(
              controller: _maintenance,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'In maintenance')),
          if (_error != null) Text(_error!),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          if (widget.item != null)
            TextButton(
                onPressed: () => Navigator.pop(
                    context, {'equipmentId': _id, 'remove': true}),
                child: const Text('Remove from branch')),
          FilledButton(onPressed: _save, child: const Text('Save')),
        ],
      );
}
