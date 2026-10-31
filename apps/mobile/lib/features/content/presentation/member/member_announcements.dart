import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Owns only announcement read state. Session composition replaces this widget
/// on account changes; generation checks discard late reads and old refreshes.
class MemberAnnouncements extends StatefulWidget {
  const MemberAnnouncements({super.key, required this.reader, this.compact = false});
  final AnnouncementReader reader;
  final bool compact;
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
              const Icon(Icons.info_outline, size: 16, color: AppColors.inkSoft),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_error!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
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
      final latest = visible.first;
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accentTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: InkWell(
          onTap: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(latest.title),
              content: SingleChildScrollView(child: Text(latest.body)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded,
                  size: 20, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (visible.length > 1)
                      Text(
                        '+${visible.length - 1} more announcement${visible.length > 2 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.inkSoft),
            ],
          ),
        ),
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
