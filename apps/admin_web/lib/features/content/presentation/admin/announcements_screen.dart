import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/content.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec'
];
String _fmt(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// AD-M11.4 — asynchronous scoped announcement authoring. Repository saves
/// retain the original edit baseline; only verified persistence reports success.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _composing = false;
  bool _loading = true, _saving = false, _reloadRequired = false;
  String? _error, _cursor;
  List<Announcement> _entries = [];
  Announcement? _editing;
  int _generation = 0;
  final _title = TextEditingController();
  final _body = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 7));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool more = false}) async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _entries = [];
        _cursor = null;
        _composing = false;
        _editing = null;
        _reloadRequired = false;
      }
    });
    try {
      final page = await context
          .read<ContentRepository>()
          .loadAnnouncements(afterId: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _entries = [..._entries, ...page.items];
        _cursor = page.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _entries = [];
        _cursor = null;
        _error =
            'Could not load announcements. Check your authorization and retry.';
      });
    }
  }

  void _open([Announcement? entry]) => setState(() {
        _editing = entry;
        _composing = true;
        _reloadRequired = false;
        _error = null;
        _title.text = entry?.title ?? '';
        _body.text = entry?.body ?? '';
        _from = entry?.validFrom ?? DateTime.now();
        _to = entry?.validTo ?? DateTime.now().add(const Duration(days: 7));
      });

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(9999),
    );
    if (picked != null && mounted && !_saving) {
      setState(() => isFrom ? _from = picked : _to = picked);
    }
  }

  Future<void> _save(AnnouncementStatus status,
      {Announcement? existing}) async {
    if (_saving || _reloadRequired) return;
    final entry = existing?.copyWith(status: status) ??
        (_editing ??
                Announcement(
                    id: '',
                    title: '',
                    body: '',
                    validFrom: _from,
                    validTo: _to))
            .copyWith(
                title: _title.text.trim(),
                body: _body.text.trim(),
                validFrom: _from,
                validTo: _to,
                status: status);
    try {
      entry.validate();
    } on FormatException catch (e) {
      showToast(context, e.message);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<ContentRepository>().saveAnnouncement(entry);
      if (!mounted) return;
      showToast(
          context,
          status == AnnouncementStatus.published
              ? 'Announcement saved and published. Members can refresh Home.'
              : status == AnnouncementStatus.inactive
                  ? 'Announcement deactivated.'
                  : 'Draft saved.');
      await _load();
    } on AnnouncementConflict {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'This announcement changed or was removed. Discard and reload before saving.';
        });
      }
    } on AnnouncementSessionChanged {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error =
              'Your account or authorization changed. Sign in again before editing.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reloadRequired = true;
          _error = 'Save was not verified. Discard and reload before retrying.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final announcements = [..._entries]
      ..sort((a, b) => b.validFrom.compareTo(a.validFrom));
    final activeCount = announcements.where((a) => a.isActive).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                      '$activeCount active, ${announcements.length} loaded',
                      style: Theme.of(context).textTheme.bodyLarge),
                ),
                IconButton(
                    tooltip: 'Refresh announcements',
                    onPressed: _saving || _loading ? null : () => _load(),
                    icon: const Icon(Icons.refresh)),
                if (!_composing && !_loading && _error == null)
                  FilledButton.icon(
                    onPressed: _saving ? null : () => _open(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New announcement'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Panel(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_error!),
                    TextButton(
                        onPressed: _saving ? null : () => _load(),
                        child: Text(_reloadRequired
                            ? 'Discard and reload'
                            : 'Retry announcements'))
                  ])),
            if (!_loading &&
                _error == null &&
                announcements.isEmpty &&
                !_composing)
              const Panel(
                  child: Text(
                      'No announcements yet. Create a draft to get started.')),
            if (_composing)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _editing == null
                              ? 'New announcement'
                              : 'Edit announcement',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _title,
                        enabled: !_saving && !_reloadRequired,
                        maxLength: 120,
                        decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'Public holiday hours'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _body,
                        enabled: !_saving && !_reloadRequired,
                        maxLength: 4000,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'Message',
                            hintText: 'What do members need to know?'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving || _reloadRequired
                                  ? null
                                  : () => _pickDate(true),
                              child: Text('From ${_fmt(_from)}'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving || _reloadRequired
                                  ? null
                                  : () => _pickDate(false),
                              child: Text('Until ${_fmt(_to)}'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Panel(
                        background: AppColors.accentTint,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.campaign_rounded,
                                size: 19, color: AppColors.warning),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Published announcements appear on Member Home after refresh, during this date window. No push or email is sent. Until is exclusive; dates use this device’s local timezone.',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() => _composing = false),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: OutlinedButton(
                                  onPressed: _saving || _reloadRequired
                                      ? null
                                      : () => _save(AnnouncementStatus.draft),
                                  child: const Text('Save draft'))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                                onPressed: _saving || _reloadRequired
                                    ? null
                                    : () => _save(AnnouncementStatus.published),
                                child: Text(_saving ? 'Saving…' : 'Publish')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ...announcements.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Panel(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: (a.isActive
                                      ? AppColors.success
                                      : AppColors.inkSoft)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(11)),
                          child: Icon(Icons.campaign_rounded,
                              size: 18,
                              color: a.isActive
                                  ? AppColors.success
                                  : AppColors.inkSoft),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.title,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text(a.body,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text('${_fmt(a.validFrom)} – ${_fmt(a.validTo)}',
                                  style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.inkSoft)),
                            ],
                          ),
                        ),
                        Column(children: [
                          statusPill(a.status != AnnouncementStatus.published
                              ? a.status.name
                              : a.isActive
                                  ? 'Active'
                                  : DateTime.now().isBefore(a.validFrom)
                                      ? 'Scheduled'
                                      : 'Expired'),
                          TextButton(
                              onPressed:
                                  _saving || _reloadRequired || _composing
                                      ? null
                                      : () => _open(a),
                              child: const Text('Edit')),
                          if (a.status != AnnouncementStatus.inactive)
                            TextButton(
                                onPressed: _saving ||
                                        _reloadRequired ||
                                        _composing
                                    ? null
                                    : () => _save(AnnouncementStatus.inactive,
                                        existing: a),
                                child: const Text('Deactivate')),
                        ]),
                      ],
                    ),
                  ),
                )),
            if (_cursor != null)
              TextButton(
                  onPressed:
                      _loading || _saving ? null : () => _load(more: true),
                  child: const Text('Load more announcements')),
          ],
        ),
      ),
    );
  }
}
