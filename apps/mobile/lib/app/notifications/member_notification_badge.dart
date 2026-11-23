import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/content.dart';

/// A session-scoped indication of confirmed unread content for the Home bell.
class MemberNotificationBadge extends ValueNotifier<bool> {
  MemberNotificationBadge({
    this.announcements,
    this.inbox,
    required this.isCurrent,
    required this.loadSeen,
    required this.saveSeen,
    DateTime Function()? clock,
  })  : _clock = clock ?? DateTime.now,
        super(false);

  final AnnouncementReader? announcements;
  final Module9Repository? inbox;
  final bool Function() isCurrent;
  final Future<Map<String, int>> Function() loadSeen;
  final Future<void> Function(Map<String, int>) saveSeen;
  final DateTime Function() _clock;

  final _seen = <String, int>{};
  late final _loadedSeen = _readSeen();
  Future<void> _pendingSave = Future.value();
  Announcement? _unreadAnnouncement;
  bool _unreadInbox = false;
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
    if (clearFirst) _showAnnouncement(null);
    try {
      await _loadedSeen;
      String? cursor;
      final visited = <String>{};
      do {
        if (!_current || request != _announcementRequest) return;
        final page = await reader.loadAnnouncements(afterId: cursor);
        if (!_current || request != _announcementRequest) return;
        final now = _clock();
        for (final item in page.items) {
          if (item.displayStatusAt(now) == AnnouncementDisplayStatus.active &&
              !isAnnouncementRead(item)) {
            _showAnnouncement(item);
            return;
          }
        }
        cursor = page.nextCursor;
        if (cursor != null && !visited.add(cursor)) return;
      } while (cursor != null);
      _showAnnouncement(null);
    } catch (_) {
      // A failed refresh keeps the last verified indicator for this audience.
      if (_current && request == _announcementRequest) _publish();
    }
  }

  void _showAnnouncement(Announcement? entry) {
    _unreadAnnouncement = entry;
    _expiration?.cancel();
    if (entry != null) {
      _expiration = Timer(entry.validTo.difference(_clock()), () {
        if (_current) unawaited(refreshAnnouncements(clearFirst: true));
      });
    }
    _publish();
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
    if (_unreadAnnouncement != null &&
        isAnnouncementRead(_unreadAnnouncement!)) {
      await refreshAnnouncements();
    }
    await _pendingSave;
  }

  Future<void> refreshInbox() async {
    final source = inbox;
    if (!_current || source == null) return;
    final request = ++_inboxRequest;
    String? cursor;
    final visited = <String>{};
    try {
      do {
        final page = await source.loadInbox(afterId: cursor);
        if (!_current || request != _inboxRequest) return;
        if (page.records.any((notice) => !notice.read)) {
          _unreadInbox = true;
          _publish();
          return;
        }
        cursor = page.nextAfterId;
        if (cursor != null && !visited.add(cursor)) return;
      } while (cursor != null);
      _unreadInbox = false;
      _publish();
    } catch (_) {
      // Retain the last state for this account when inbox verification fails.
    }
  }

  void _publish() {
    value = _current &&
        (_unreadInbox ||
            (_unreadAnnouncement != null &&
                !isAnnouncementRead(_unreadAnnouncement!)));
  }

  void clear() {
    _announcementRequest++;
    _inboxRequest++;
    _expiration?.cancel();
    _inboxDebounce?.cancel();
    _unreadAnnouncement = null;
    _unreadInbox = false;
    value = false;
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
