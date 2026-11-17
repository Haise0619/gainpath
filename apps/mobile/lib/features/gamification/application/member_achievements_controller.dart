import 'package:flutter/foundation.dart';
import '../domain/member_achievements.dart';

class MemberAchievementsController extends ChangeNotifier {
  MemberAchievementsController({
    required this.load,
    required this.isCurrent,
    this.readCache,
    this.saveCache,
  });

  final Future<MemberAchievements> Function() load;
  final bool Function() isCurrent;
  final Future<MemberAchievements?> Function()? readCache;
  final Future<void> Function(MemberAchievements, bool Function())? saveCache;

  MemberAchievements? _snapshot;
  MemberAchievements? get snapshot => current ? _snapshot : null;
  bool stale = false;
  bool failed = false;
  bool _disposed = false;
  bool _reloadAfterRequest = false;
  Future<void>? _request;
  DateTime? _loadedAt;
  final _unlocks = <MemberAchievement>[];
  final _seen = <String>{};
  int _generation = 0;

  bool get current => !_disposed && isCurrent();

  List<MemberAchievement> takeUnlocks() {
    final unlocked =
        current ? List<MemberAchievement>.of(_unlocks) : <MemberAchievement>[];
    _unlocks.clear();
    return unlocked;
  }

  Future<void> loadIfNeeded() {
    final loadedAt = _loadedAt;
    if (loadedAt != null &&
        !stale &&
        DateTime.now().difference(loadedAt) < const Duration(minutes: 2)) {
      return Future<void>.value();
    }
    return refresh();
  }

  Future<void> refresh({bool changed = false}) {
    if (!current) return Future<void>.value();
    final request = _request;
    if (request != null) {
      _reloadAfterRequest |= changed;
      return request;
    }
    final generation = _generation;
    return _request = Future<void>.microtask(() => _refresh(generation));
  }

  Future<void> _refresh(int generation) async {
    bool active() => current && generation == _generation;
    try {
      if (!active()) return;
      if (_snapshot == null && readCache != null) {
        try {
          final cached = await readCache!();
          if (!active()) return;
          if (cached != null) {
            _snapshot = cached;
            _seen.addAll(cached.badges
                .where((badge) => badge.unlocked)
                .map((badge) => badge.id));
            stale = true;
            notifyListeners();
          }
        } catch (_) {
          // Continue to the authoritative read if the display cache is damaged.
        }
      }
      final result = await load();
      if (!active()) return;
      for (final badge in result.badges.where((badge) => badge.unlocked)) {
        if (_seen.add(badge.id) && _snapshot != null) _unlocks.add(badge);
      }
      _snapshot = result;
      _loadedAt = DateTime.now();
      failed = false;
      stale = false;
      if (saveCache != null) {
        try {
          await saveCache!(result, active);
        } catch (_) {
          // A failed disk write does not invalidate confirmed server progress.
        }
      }
    } catch (_) {
      if (!current || generation != _generation) return;
      stale = _snapshot != null;
      failed = _snapshot == null;
    } finally {
      if (generation == _generation) _request = null;
      if (current && generation == _generation) {
        final reload = _reloadAfterRequest;
        _reloadAfterRequest = false;
        notifyListeners();
        if (reload) await refresh();
      }
    }
  }

  void invalidate() {
    _generation++;
    _request = null;
    _snapshot = null;
    _loadedAt = null;
    _seen.clear();
    _unlocks.clear();
    _reloadAfterRequest = false;
    stale = false;
    failed = false;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
