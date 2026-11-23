import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Owns only announcement read state. Session composition replaces this widget
/// on account changes; generation checks discard late reads and old refreshes.
class MemberAnnouncements extends StatefulWidget {
  const MemberAnnouncements(
      {super.key,
      required this.reader,
      this.compact = false,
      this.onAnnouncementOpened});
  final AnnouncementReader reader;
  final bool compact;
  final Future<void> Function(Announcement)? onAnnouncementOpened;
  @override
  State<MemberAnnouncements> createState() => MemberAnnouncementsState();
}

class MemberAnnouncementsState extends State<MemberAnnouncements>
    with WidgetsBindingObserver {
  List<Announcement> _items = [];
  String? _cursor, _error;
  bool _loading = true;
  int _generation = 0;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
  }

  @override
  void didUpdateWidget(MemberAnnouncements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader) unawaited(refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _expiry?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() => _load(reset: true);
  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _cursor == null)) return;
    final generation = ++_generation;
    _expiry?.cancel();
    setState(() {
      _loading = true;
      _error = null;
      if (reset) {
        _items = [];
        _cursor = null;
      }
    });
    try {
      final reader = widget.reader;
      final items = <Announcement>[];
      final seen = <String>{};
      var cursor = reset ? null : _cursor;
      do {
        final page = await reader.loadAnnouncements(afterId: cursor);
        if (!mounted || generation != _generation) return;
        items.addAll(page.items);
        cursor = page.nextCursor;
        if (cursor != null && !seen.add(cursor)) {
          throw StateError('Announcement pagination did not advance.');
        }
      } while (widget.compact && cursor != null);
      setState(() {
        _items = [..._items, ...items];
        _cursor = cursor;
        _loading = false;
      });
      _scheduleBoundary();
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _items = [];
        _cursor = null;
        _error = 'Could not load announcements. Pull to refresh or retry.';
      });
    }
  }

  void _scheduleBoundary() {
    final now = DateTime.now();
    final dates = _items
        .expand((a) => [a.validFrom, a.validTo])
        .where((d) => d.isAfter(now))
        .toList()
      ..sort();
    if (dates.isNotEmpty) {
      _expiry = Timer(dates.first.difference(now), () {
        if (mounted) {
          setState(() {});
          _scheduleBoundary();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((a) => a.isActive).toList()
      ..sort((a, b) {
        final priority = b.priority.index.compareTo(a.priority.index);
        if (priority != 0) return priority;
        final date = b.validFrom.compareTo(a.validFrom);
        return date == 0 ? a.id.compareTo(b.id) : date;
      });

    if (widget.compact) {
      if (!_loading && _error == null && visible.isEmpty) {
        return const SizedBox.shrink();
      }
      if (_loading && _items.isEmpty) {
        return const SizedBox.shrink();
      }
      if (_error != null) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.inkSoft)),
              ),
              TextButton(
                onPressed: refresh,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Announcements',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Announcements')),
                      body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: MemberAnnouncements(
                            reader: widget.reader,
                            onAnnouncementOpened: widget.onAnnouncementOpened),
                      ),
                    ),
                  ),
                ),
                child: const Text('View all'),
              ),
            ],
          ),
          for (final entry in visible.take(2)) _card(entry),
        ],
      );
    }

    return Panel(
        background: AppColors.accentTint,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Announcements',
              style: TextStyle(fontWeight: FontWeight.w700)),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) ...[
            Text(_error!),
            TextButton(
                onPressed: refresh, child: const Text('Retry announcements'))
          ],
          if (!_loading && _error == null && visible.isEmpty)
            const Text('No active announcements.'),
          for (final entry in visible) _card(entry),
          if (_cursor != null)
            TextButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Load more announcements')),
        ]));
  }

  String _date(DateTime instant) {
    final myt = instant.toUtc().add(const Duration(hours: 8));
    return MaterialLocalizations.of(context).formatMediumDate(myt);
  }

  Widget _card(Announcement entry) {
    final icon = switch (entry.category) {
      AnnouncementCategory.general => Icons.campaign_outlined,
      AnnouncementCategory.maintenance => Icons.construction_outlined,
      AnnouncementCategory.closure => Icons.door_front_door_outlined,
      AnnouncementCategory.promotion => Icons.local_offer_outlined,
      AnnouncementCategory.event => Icons.event_outlined,
      AnnouncementCategory.update => Icons.info_outline,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnnouncementCard(
        title: entry.title,
        message: entry.body,
        caption: '${entry.audienceLabel} · ${_date(entry.validFrom)}',
        icon: icon,
        important: entry.priority == AnnouncementPriority.important,
        warmAccent: entry.category == AnnouncementCategory.maintenance ||
            entry.category == AnnouncementCategory.closure,
        onReadMore: () {
          unawaited(widget.onAnnouncementOpened?.call(entry));
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(entry.title),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.category.name),
                    Text(entry.audienceLabel),
                    Text(
                        '${_date(entry.validFrom)} – ${_date(entry.validTo)} MYT'),
                    const SizedBox(height: 12),
                    SelectableText(entry.body),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ],
            ),
          );
        },
      ),
    );
  }
}
