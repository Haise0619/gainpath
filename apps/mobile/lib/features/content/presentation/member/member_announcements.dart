import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Owns only announcement read state. Session composition replaces this widget
/// on account changes; generation checks discard late reads and old refreshes.
class MemberAnnouncements extends StatefulWidget {
  const MemberAnnouncements({super.key, required this.reader});
  final AnnouncementReader reader;
  @override
  State<MemberAnnouncements> createState() => MemberAnnouncementsState();
}

class MemberAnnouncementsState extends State<MemberAnnouncements> {
  List<Announcement> _items = [];
  String? _cursor, _error;
  bool _loading = true;
  int _generation = 0;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    unawaited(refresh());
  }

  @override
  void didUpdateWidget(MemberAnnouncements oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reader != widget.reader) unawaited(refresh());
  }

  @override
  void dispose() {
    _generation++;
    _expiry?.cancel();
    super.dispose();
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
      final page = await widget.reader
          .loadAnnouncements(afterId: reset ? null : _cursor);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...page.items];
        _cursor = page.nextCursor;
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
      ..sort((a, b) => b.validFrom.compareTo(a.validFrom));
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
          for (final entry in visible)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(entry.body)
                    ])),
          if (_cursor != null)
            TextButton(
                onPressed: _loading ? null : () => _load(),
                child: const Text('Load more announcements')),
        ]));
  }
}
