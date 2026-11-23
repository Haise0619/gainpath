import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/content.dart';

/// A session-scoped indication of confirmed unread content for the Home bell.
class MemberNotificationBadge extends ValueNotifier<int> {
  MemberNotificationBadge({
    this.announcements,
    this.inbox,
    required this.isCurrent,
    required this.loadSeen,
    required this.saveSeen,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(0);

  final AnnouncementReader? announcements;
  final Module9Repository? inbox;
  final bool Function() isCurrent;
  final Future<Map<String, int>> Function() loadSeen;
  final Future<void> Function(Map<String, int>) saveSeen;
  final DateTime Function() _clock;

  final _seen = <String, int>{};
  late final _loadedSeen = _readSeen();
  Future<void> _pendingSave = Future.value();
  List<Announcement> _activeAnnouncements = [];
  int _unreadInbox = 0;
  int _announcementRequest = 0;
  int _inboxRequest = 0;
  bool _disposed = false;
  Timer? _expiration;
  Timer? _inboxDebounce;
  StreamSubscription<void>? _inboxChanges;

  bool get _current => !_disposed && isCurrent();
  String _key(Announcement entry) => '${entry.id}:${entry.revision}';

  Future<void> _readSeen() async {
    try {
      _seen.addAll(await loadSeen());
    } catch (_) {
      // The local indicator can still work for this session.
    }
  }

  Future<void> prepareAnnouncements() => _loadedSeen;

  bool isAnnouncementRead(Announcement entry) => _seen.containsKey(_key(entry));

  void watchInbox() {
    _inboxChanges ??= inbox?.watchInbox().listen((_) {
      _inboxDebounce?.cancel();
      _inboxDebounce = Timer(const Duration(milliseconds: 250), refreshInbox);
    }, onError: (_) {
      /* Opening and refreshing Home can still check unread. */
    });
  }

  Future<void> refreshAnnouncements({bool clearFirst = false}) async {
    final reader = announcements;
    if (!_current || reader == null) return;
    final request = ++_announcementRequest;
    if (clearFirst) {
      _activeAnnouncements = [];
      _publish();
    }
    try {
      await _loadedSeen;
      String? cursor;
      final visited = <String>{};
      final entries = <String, Announcement>{};
      do {
        if (!_current || request != _announcementRequest) return;
        final page = await reader.loadAnnouncements(afterId: cursor);
        if (!_current || request != _announcementRequest) return;
        for (final item in page.items) {
          final previous = entries[item.id];
          if (previous == null || item.revision > previous.revision) {
            entries[item.id] = item;
          }
        }
        cursor = page.nextCursor;
        if (cursor != null && !visited.add(cursor)) return;
      } while (cursor != null);
      _activeAnnouncements = entries.values.toList();
      _publish();
    } catch (_) {
      // A failed refresh keeps the last verified indicator for this audience.
      if (_current && request == _announcementRequest) _publish();
    }
  }

  Future<void> markAnnouncementRead(Announcement entry) async {
    if (!_current) return;
    await _loadedSeen;
    if (!_current || isAnnouncementRead(entry)) return;

    _seen[_key(entry)] = entry.validTo.millisecondsSinceEpoch;
    final cutoff = _clock().millisecondsSinceEpoch;
    _seen.removeWhere((_, expiry) => expiry <= cutoff);
    final snapshot = Map<String, int>.of(_seen);
    _pendingSave =
        _pendingSave.then((_) => saveSeen(snapshot)).catchError((_) {});
    _publish();
    await _pendingSave;
  }

  Future<void> refreshInbox() async {
    final source = inbox;
    if (!_current || source == null) return;
    final request = ++_inboxRequest;
    String? cursor;
    final visited = <String>{};
    final readStates = <String, bool>{};
    try {
      do {
        final page = await source.loadInbox(afterId: cursor);
        if (!_current || request != _inboxRequest) return;
        for (final notice in page.records) {
          readStates.putIfAbsent(notice.id, () => notice.read);
        }
        cursor = page.nextAfterId;
        if (cursor != null && !visited.add(cursor)) return;
      } while (cursor != null);
      _unreadInbox = readStates.values.where((read) => !read).length;
      _publish();
    } catch (_) {
      // Retain the last state for this account when inbox verification fails.
    }
  }

  void _publish() {
    _expiration?.cancel();
    if (!_current) return;
    final now = _clock();
    DateTime? nextExpiry;
    var unread = _unreadInbox;
    for (final entry in _activeAnnouncements) {
      if (entry.displayStatusAt(now) != AnnouncementDisplayStatus.active ||
          isAnnouncementRead(entry)) {
        continue;
      }
      unread++;
      if (nextExpiry == null || entry.validTo.isBefore(nextExpiry)) {
        nextExpiry = entry.validTo;
      }
    }
    if (nextExpiry != null) {
      _expiration = Timer(nextExpiry.difference(now), _publish);
    }
    value = unread;
  }

  void clear() {
    _announcementRequest++;
    _inboxRequest++;
    _expiration?.cancel();
    _inboxDebounce?.cancel();
    _activeAnnouncements = [];
    _unreadInbox = 0;
    value = 0;
  }

  @override
  void dispose() {
    _disposed = true;
    _expiration?.cancel();
    _inboxDebounce?.cancel();
    unawaited(_inboxChanges?.cancel());
    super.dispose();
  }
}
