import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'branch_map.dart';
import 'branch_activity_page.dart';

typedef BranchRequest = Future<Map<String, dynamic>> Function(
    Map<String, Object?> input);

class BranchDirectoryPage extends StatefulWidget {
  const BranchDirectoryPage({
    super.key,
    required this.request,
    required this.openDirections,
    this.admin = false,
    this.onSelected,
    this.locate,
    this.scanVisit,
    this.pickCover,
    this.initialDetails,
    this.onOpenReports,
    this.onOpenCoaches,
  });

  final BranchRequest request;
  final Future<bool> Function(Uri) openDirections;
  final bool admin;
  final ValueChanged<String>? onSelected;
  final Future<({double latitude, double longitude})> Function()? locate;
  final Future<String?> Function(BuildContext context)? scanVisit;
  final Future<String?> Function()? pickCover;
  final Map<String, dynamic>? initialDetails;
  final ValueChanged<String>? onOpenReports;
  final ValueChanged<String>? onOpenCoaches;

  @override
  State<BranchDirectoryPage> createState() => _BranchDirectoryPageState();
}

class _BranchDirectoryPageState extends State<BranchDirectoryPage> {
  List<Map<String, dynamic>> _branches = [];
  String? _home, _next;
  String _query = '';
  String _statusFilter = 'all';
  bool _busy = false, _failed = false;
  bool _showMap = false, _locating = false;
  LatLng? _location;
  String? _selection;

  Future<void> _useLocation() async {
    setState(() => _locating = true);
    try {
      final point = await widget.locate!();
      if (mounted) {
        setState(() => _location = LatLng(point.latitude, point.longitude));
      }
    } on StateError catch (error) {
      if (mounted) _notice(error.message);
    } catch (_) {
      if (mounted) {
        _notice('Location is unavailable. You can still browse branches.');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
    final details = widget.initialDetails;
    if (details != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _details(details);
      });
    }
  }

  Future<void> _load({bool more = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      final result = await widget.request({
        'action': 'list',
        if (more) 'afterId': _next,
      });
      if (!mounted) return;
      final branches = (result['records'] as List)
          .map((value) => Map<String, dynamic>.from(value as Map));
      setState(() {
        _branches = [if (more) ..._branches, ...branches];
        _home = result['homeBranchId'] as String?;
        _selection = result['selectedBranchId'] as String?;
        _next = result['nextAfterId'] as String?;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _details(Map<String, dynamic> branch) async {
    final address = (branch['address'] as String?) ?? '';
    final latitude = branch['latitude'];
    final longitude = branch['longitude'];
    final destination =
        latitude is num && longitude is num ? '$latitude,$longitude' : address;
    final facilities = (branch['facilities'] as List?)?.join(' · ') ?? '';
    final hours = branch['openingHours'] as List?;
    final cover = branch['coverUrl'] as String?;
    final id = branch['branchId'] as String;
    final stats = widget.admin
        ? Future<Map<String, dynamic>>.sync(
            () => widget.request({'action': 'branchStats', 'branchId': id}))
        : null;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(branch['displayName'] as String? ?? 'Branch'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (cover != null && cover.isNotEmpty)
                  Image.network(cover,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const SizedBox.shrink()),
                if (address.isNotEmpty) Text(address),
                if (branch['description'] case final String description
                    when description.isNotEmpty)
                  Text(description),
                if (branch['contactPhone'] case final String phone
                    when phone.isNotEmpty)
                  Text(phone),
                if (facilities.isNotEmpty) Text(facilities),
                if (stats != null)
                  FutureBuilder<Map<String, dynamic>>(
                    future: stats,
                    builder: (context, snapshot) {
                      final result = snapshot.data;
                      if (snapshot.hasError) {
                        return const Text('Branch totals unavailable.');
                      }
                      if (result == null) {
                        return const LinearProgressIndicator();
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Wrap(spacing: 8, runSpacing: 4, children: [
                          Chip(
                              label:
                                  Text('${result['coaches']} coach profiles')),
                          Chip(
                              label: Text(
                                  '${result['equipment']} equipment units')),
                          Chip(label: Text('${result['bookings']} bookings')),
                          Chip(label: Text('${result['visits']} gym visits')),
                        ]),
                      );
                    },
                  ),
                const SizedBox(height: 12),
                if (hours == null || hours.length != 7)
                  const Text('Opening hours unavailable')
                else ...[
                  Text(branchOpeningStatus(hours)),
                  const SizedBox(height: 8),
                  for (var i = 0; i < 7; i++)
                    Text('${_days[i]}  ${_dayLabel(hours[i])}'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (widget.admin && widget.onOpenCoaches != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'coaches'),
              child: const Text('Coaches'),
            ),
          if (widget.admin && widget.onOpenReports != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'reports'),
              child: const Text('Reports'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'equipment'),
            child: const Text('Equipment'),
          ),
          if (widget.admin)
            TextButton(
              onPressed: () => Navigator.pop(context, 'visits'),
              child: const Text('Gym visits'),
            )
          else if (_selection != id)
            TextButton(
              onPressed: () => Navigator.pop(context, 'select'),
              child: const Text('Use this branch'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
          if (destination.isNotEmpty)
            TextButton(
                onPressed: () => Navigator.pop(context, 'directions'),
                child: const Text('Get directions')),
          if (address.isNotEmpty)
            TextButton(
                onPressed: () =>
                    Clipboard.setData(ClipboardData(text: address)),
                child: const Text('Copy address')),
          if (widget.admin)
            FilledButton(
                onPressed: () => Navigator.pop(context, 'edit'),
                child: const Text('Edit branch'))
          else if (_home != id)
            FilledButton(
                onPressed: () => Navigator.pop(context, 'home'),
                child: const Text('Set as home branch')),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'coaches') {
      widget.onOpenCoaches?.call(id);
      return;
    }
    if (action == 'reports') {
      widget.onOpenReports?.call(id);
      return;
    }
    if (action == 'equipment' || action == 'visits') {
      await _activity(branch: branch, visits: action == 'visits');
      return;
    }
    if (action == 'select') {
      try {
        await widget.request({'action': 'setSelected', 'branchId': id});
        if (mounted) {
          setState(() => _selection = id);
          widget.onSelected?.call(id);
        }
      } catch (_) {
        if (mounted) _notice('Could not select this branch.');
      }
      return;
    }
    if (action == 'edit') {
      await _edit(branch);
    } else if (action == 'home') {
      try {
        await widget.request({'action': 'setHome', 'branchId': id});
        if (mounted) await _load();
      } catch (_) {
        if (mounted) _notice('Could not update the home branch.');
      }
    } else if (action == 'directions') {
      try {
        final opened = await widget
            .openDirections(Uri.https('www.google.com', '/maps/dir/', {
          'api': '1',
          'destination': destination,
          'travelmode': 'driving',
          'dir_action': 'navigate',
        }));
        if (!opened && mounted) _notice('Could not open directions.');
      } catch (_) {
        if (mounted) _notice('Could not open directions.');
      }
    }
  }

  void _notice(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _activity(
          {Map<String, dynamic>? branch, required bool visits}) =>
      Navigator.of(context).push<void>(MaterialPageRoute(
          builder: (_) => BranchActivityPage(
                title: visits
                    ? 'Gym visits'
                    : '${branch?['displayName']} equipment',
                request: widget.request,
                branchId: branch?['branchId'] as String?,
                visits: visits,
                admin: widget.admin,
              )));

  Future<void> _checkIn() async {
    final code = await widget.scanVisit!(context);
    if (!mounted || code == null) return;
    final match =
        RegExp(r'^gainpath-visit:([A-Za-z0-9_-]{1,128}):([A-Za-z0-9_-]{32})$')
            .firstMatch(code);
    if (match == null) {
      _notice('This is not a GainPath gym visit code.');
      return;
    }
    try {
      final result = await widget.request(
          {'action': 'checkIn', 'branchId': match[1], 'token': match[2]});
      if (mounted) {
        _notice(result['duplicate'] == true
            ? 'Visit already recorded.'
            : 'Gym check-in successful.');
      }
    } catch (_) {
      if (mounted) {
        _notice(
            'Check-in unavailable. Check your membership or ask for a fresh code.');
      }
    }
  }

  Future<void> _edit([Map<String, dynamic>? branch]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _BranchEditor(
          branch: branch, request: widget.request, pickCover: widget.pickCover),
    );
    if (mounted && saved == true) {
      _notice(branch == null ? 'Branch added.' : 'Branch saved.');
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase().trim();
    final visible = _branches
        .where((branch) =>
            (_statusFilter == 'all' || branch['status'] == _statusFilter) &&
            '${branch['displayName']} ${branch['address'] ?? ''}'
                .toLowerCase()
                .contains(query))
        .toList();
    final location = _location;
    if (location != null) {
      double distance(Map<String, dynamic> branch) =>
          branchDistanceKm(branch, location) ?? double.infinity;
      visible.sort((a, b) {
        final order = distance(a).compareTo(distance(b));
        return order != 0
            ? order
            : (a['branchId'] as String).compareTo(b['branchId'] as String);
      });
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.admin ? 'Branch management' : 'Find a gym'),
        actions: [
          IconButton(
              tooltip: 'Refresh',
              onPressed: _busy ? null : () => _load(),
              icon: const Icon(Icons.refresh)),
          if (widget.admin)
            TextButton.icon(
                onPressed: _busy ? null : () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text('Add branch')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                  labelText: 'Search branches',
                  prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            if (widget.admin)
              for (final filter in const {
                'all': 'All',
                'active': 'Active',
                'inactive': 'Inactive'
              }.entries)
                ChoiceChip(
                    label: Text(filter.value),
                    selected: _statusFilter == filter.key,
                    onSelected: (_) =>
                        setState(() => _statusFilter = filter.key)),
            if (widget.scanVisit != null) ...[
              OutlinedButton.icon(
                  onPressed: _checkIn,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Gym check-in')),
              TextButton(
                  onPressed: () => _activity(visits: true),
                  child: const Text('My gym visits')),
            ],
            OutlinedButton.icon(
                onPressed: () => setState(() => _showMap = !_showMap),
                icon: const Icon(Icons.map_outlined),
                label: Text(_showMap ? 'Hide map' : 'Show map')),
            if (widget.locate != null)
              OutlinedButton.icon(
                  onPressed: _locating ? null : _useLocation,
                  icon: const Icon(Icons.my_location),
                  label: Text(
                      _locating ? 'Finding location…' : 'Use my location')),
          ]),
          if (_showMap)
            BranchMap(
              key: ValueKey(
                  (location, visible.map((b) => b['branchId']).join(','))),
              branches: visible,
              location: location,
              selectedId: _selection,
              onBranch: _details,
            ),
          if (location != null)
            const Text('Approximate straight-line distance · loaded branches'),
          if (_busy) const LinearProgressIndicator(),
          if (_failed)
            const Text('Branches could not be loaded. Refresh to retry.'),
          if (!_busy && !_failed && visible.isEmpty)
            const Text('No matching branches.'),
          for (final branch in visible)
            Card(
              child: ListTile(
                leading: _branchThumbnail(branch['coverUrl']),
                title: Text(branch['displayName'] as String? ?? 'Branch'),
                subtitle: Text([
                  if (branch['branchId'] == _home) 'Home branch',
                  if (branch['branchId'] == _selection) 'Selected branch',
                  if ((location == null
                          ? null
                          : branchDistanceKm(branch, location))
                      case final double km)
                    '${km.toStringAsFixed(1)} km away',
                  if (widget.admin)
                    branch['status'] == 'active' ? 'Active' : 'Inactive',
                  if (branch['address'] case final String address
                      when address.isNotEmpty)
                    address,
                ].join(' · ')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _details(branch),
              ),
            ),
          if (_next != null)
            TextButton(
                onPressed: _busy ? null : () => _load(more: true),
                child: const Text('Load more')),
        ],
      ),
    );
  }
}

Widget _branchThumbnail(Object? url) {
  const fallback = Icon(Icons.location_on_outlined);
  if (url is! String || url.isEmpty) return fallback;
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(url,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => fallback),
  );
}

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _dayLabel(Object? value) {
  if (value is! Map) return 'Unavailable';
  if (value['closed'] == true) return 'Closed';
  if (value['allDay'] == true) return 'Open 24 hours';
  return '${value['open']}–${value['close']}';
}

String branchOpeningStatus(List hours) {
  if (hours.length != 7) return 'Opening hours unavailable';
  final local = DateTime.now().toUtc().add(const Duration(hours: 8));
  final today = hours[local.weekday - 1];
  final yesterday = hours[(local.weekday + 5) % 7];
  final minute = local.hour * 60 + local.minute;
  int? parse(Object? value) {
    if (value is! String ||
        !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value)) {
      return null;
    }
    return int.parse(value.substring(0, 2)) * 60 +
        int.parse(value.substring(3));
  }

  bool open(Object? value, {required bool previous}) {
    if (value is! Map || value['closed'] == true) return false;
    if (value['allDay'] == true) return !previous;
    final start = parse(value['open']), end = parse(value['close']);
    if (start == null || end == null) return false;
    return previous
        ? start > end && minute < end
        : minute >= start && (start > end || minute < end);
  }

  return open(today, previous: false) || open(yesterday, previous: true)
      ? 'Open now · MYT'
      : 'Closed now · MYT';
}

class _BranchEditor extends StatefulWidget {
  const _BranchEditor({this.branch, required this.request, this.pickCover});
  final Map<String, dynamic>? branch;
  final BranchRequest request;
  final Future<String?> Function()? pickCover;

  @override
  State<_BranchEditor> createState() => _BranchEditorState();
}

class _BranchEditorState extends State<_BranchEditor> {
  final _form = GlobalKey<FormState>();
  static const _labels = {
    'branchId': 'Branch ID',
    'displayName': 'Branch name',
    'description': 'Description',
    'address': 'Full address',
    'city': 'City',
    'state': 'State',
    'postalCode': 'Postal code',
    'country': 'Country',
    'contactPhone': 'Phone',
    'contactEmail': 'Email',
    'latitude': 'Latitude',
    'longitude': 'Longitude',
    'facilities': 'Facilities (comma-separated)',
  };
  late final _values = {
    for (final key in _labels.keys)
      key: TextEditingController(
          text: key == 'facilities'
              ? (widget.branch?[key] as List?)?.join(', ')
              : widget.branch?[key]?.toString()),
  };
  late bool _active = widget.branch?['status'] != 'inactive';
  late final _hours = List.generate(7, (index) {
    final hours = widget.branch?['openingHours'];
    final saved = hours is List && hours.length == 7 ? hours[index] : null;
    final label = _dayLabel(saved);
    return TextEditingController(
        text: label == 'Unavailable'
            ? ''
            : label == 'Open 24 hours'
                ? '24 hours'
                : label.replaceAll('–', '-'));
  });
  bool _busy = false;
  late String? _cover = widget.branch?['coverUrl'] as String?;
  Uint8List? _coverPreview;
  bool _coverUploadFailed = false;
  bool _uploading = false;

  Future<void> _upload() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final encoded = await widget.pickCover!();
      if (!mounted || encoded == null) return;
      final bytes = base64Decode(encoded);
      setState(() {
        _coverPreview = bytes;
        _coverUploadFailed = false;
      });
      final result = await widget
          .request({'action': 'uploadBranchCover', 'dataBase64': encoded});
      final url = result['url'];
      if (url is! String || url.isEmpty) throw StateError('Missing cover URL');
      if (mounted) setState(() => _cover = url);
    } catch (_) {
      if (mounted) {
        setState(() {
          _coverUploadFailed = _coverPreview != null;
          _error = _coverUploadFailed
              ? 'Cover upload failed. Try again or discard the selected cover.'
              : 'Could not open the image. Choose a JPG or PNG up to 2 MB.';
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  bool _pickOnMap = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in _values.values) {
      controller.dispose();
    }
    for (final controller in _hours) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _uploading) return;
    if (_coverUploadFailed) {
      setState(() => _error =
          'Upload the selected cover again or discard it before saving.');
      return;
    }
    String value(String key) => _values[key]!.text.trim();
    final branchId = value('branchId');
    final name = value('displayName');
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(branchId)) {
      _form.currentState?.validate();
      setState(() => _error =
          'Enter a branch ID using letters, numbers, hyphens or underscores.');
      return;
    }
    if (name.isEmpty || name.length > 120) {
      _form.currentState?.validate();
      setState(() => _error = 'Enter a branch name of up to 120 characters.');
      return;
    }
    final schedule = <Map<String, Object>>[];
    if (_hours.any((controller) => controller.text.trim().isNotEmpty)) {
      final slot = RegExp(r'^([01]\d|2[0-3]):[0-5]\d-([01]\d|2[0-3]):[0-5]\d$');
      for (final controller in _hours) {
        final input = controller.text.trim().toLowerCase();
        if (input == 'closed') {
          schedule.add({'closed': true});
        } else if (input == '24 hours') {
          schedule.add({'allDay': true});
        } else if (slot.hasMatch(input) &&
            input.substring(0, 5) != input.substring(6)) {
          schedule.add(
              {'open': input.substring(0, 5), 'close': input.substring(6)});
        } else {
          setState(() => _error =
              'Set all seven days. Use HH:mm-HH:mm, Closed, or 24 hours.');
          return;
        }
      }
    }
    final latitude = double.tryParse(value('latitude'));
    final longitude = double.tryParse(value('longitude'));
    if ((value('latitude').isNotEmpty || value('longitude').isNotEmpty) &&
        (latitude == null ||
            longitude == null ||
            !latitude.isFinite ||
            !longitude.isFinite ||
            latitude.abs() > 90 ||
            longitude.abs() > 180)) {
      setState(() => _error = 'Enter valid latitude and longitude.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.request({
        'action': 'save',
        'branchId': value('branchId'),
        'create': widget.branch == null,
        'branch': {
          for (final key in _labels.keys.where((key) => ![
                'branchId',
                'latitude',
                'longitude',
                'facilities'
              ].contains(key)))
            key: value(key),
          'latitude': latitude,
          'longitude': longitude,
          'status': _active ? 'active' : 'inactive',
          if (_cover != null) 'coverUrl': _cover,
          if (schedule.isNotEmpty) 'openingHours': schedule,
          'facilities': value('facilities')
              .split(',')
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toList(),
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Branch could not be saved. Check the details and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.branch == null ? 'Add branch' : 'Edit branch'),
        content: SizedBox(
          width: 480,
          height: 540,
          child: Form(
            key: _form,
            child: ListView(
              shrinkWrap: true,
              children: [
                if (_coverPreview case final Uint8List bytes)
                  Image.memory(
                    bytes,
                    height: 130,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Text('Cover preview unavailable'),
                  )
                else if (_cover case final String url when url.isNotEmpty)
                  Image.network(url,
                      webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                      height: 120,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) =>
                          const Text('Cover preview unavailable')),
                if (widget.pickCover != null)
                  OutlinedButton.icon(
                      onPressed: _busy || _uploading ? null : _upload,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_uploading ? 'Uploading…' : 'Upload cover')),
                if (_coverUploadFailed)
                  TextButton(
                    onPressed: _uploading ? null : () => setState(() {
                      _coverPreview = null;
                      _coverUploadFailed = false;
                      _error = null;
                    }),
                    child: const Text('Discard selected cover'),
                  ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _pickOnMap = !_pickOnMap),
                  icon: const Icon(Icons.map_outlined),
                  label: Text(_pickOnMap
                      ? 'Hide location picker'
                      : 'Pick location on map'),
                ),
                if (_pickOnMap) ...[
                  const Text(
                      'Tap the map or drag the marker to set coordinates.'),
                  BranchMap(
                    pin: branchMapPoint({
                      'latitude': double.tryParse(_values['latitude']!.text),
                      'longitude': double.tryParse(_values['longitude']!.text),
                    }),
                    onPin: (point) => setState(() {
                      _values['latitude']!.text =
                          point.latitude.toStringAsFixed(6);
                      _values['longitude']!.text =
                          point.longitude.toStringAsFixed(6);
                    }),
                  ),
                ],
                for (final entry in _labels.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _values[entry.key],
                      onChanged:
                          entry.key == 'latitude' || entry.key == 'longitude'
                              ? (_) {
                                  if (_pickOnMap) setState(() {});
                                }
                              : null,
                      enabled: !_busy &&
                          (entry.key != 'branchId' || widget.branch == null),
                      decoration: InputDecoration(labelText: entry.value),
                      validator: (value) {
                        if (entry.key == 'branchId' &&
                            !RegExp(r'^[A-Za-z0-9_-]{1,128}$')
                                .hasMatch(value?.trim() ?? '')) {
                          return 'Use letters, numbers, hyphens or underscores.';
                        }
                        if (entry.key == 'displayName' &&
                            (value?.trim().isEmpty ?? true)) {
                          return 'Enter the branch name.';
                        }
                        return null;
                      },
                    ),
                  ),
                const Text('Opening hours · MYT'),
                for (var day = 0; day < _days.length; day++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextFormField(
                      enabled: !_busy,
                      controller: _hours[day],
                      decoration: InputDecoration(
                          labelText: _days[day],
                          hintText: '08:00-22:00, Closed, or 24 hours'),
                    ),
                  ),
                SwitchListTile(
                    title: const Text('Active'),
                    value: _active,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _active = value)),
              ],
            ),
          ),
        ),
        actions: [
          if (_error case final String error)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Semantics(
                liveRegion: true,
                child: Text(error,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy || _uploading ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save branch')),
        ],
      );
}
