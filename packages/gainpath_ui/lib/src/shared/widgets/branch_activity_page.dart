import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'branch_directory_page.dart' show BranchRequest;

class BranchActivityPage extends StatefulWidget {
  const BranchActivityPage(
      {super.key,
      required this.title,
      required this.request,
      this.branchId,
      this.admin = false,
      this.visits = false});

  final String title;
  final BranchRequest request;
  final String? branchId;
  final bool admin, visits;

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
      final qr = result['qr'] as String;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Gym check-in QR'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  QrImageView(
                      data: qr, size: 210, backgroundColor: Colors.white),
                  const Text(
                      'Valid for 5 minutes. Generating a new code replaces this one.'),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'))
                ],
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title), actions: [
          if (widget.admin && widget.visits)
            TextButton(onPressed: _showCode, child: const Text('Generate QR')),
          if (widget.admin && !widget.visits)
            TextButton(
                onPressed: () => _edit(), child: const Text('Add equipment')),
          IconButton(
              tooltip: 'Refresh',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Icons.refresh)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!),
          if (!_loading && _error == null && _records.isEmpty)
            Text(widget.visits
                ? 'No gym visits recorded.'
                : 'No equipment recorded.'),
          for (final row in _records)
            Card(
                child: ListTile(
              title: Text((widget.visits ? row['branchName'] : row['name'])
                      ?.toString() ??
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
        ]),
      );
}

String _formatDate(Object? millis) {
  if (millis is! num) return 'Time unavailable';
  final time = DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true)
      .add(const Duration(hours: 8));
  return '${time.toIso8601String().substring(0, 16).replaceFirst('T', ' ')} MYT';
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
