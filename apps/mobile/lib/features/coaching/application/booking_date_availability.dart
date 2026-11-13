import 'package:flutter/foundation.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

enum BookingDateState { checking, available, unavailable, failed }

/// Seven-day, read-only calendar snapshots. Unknown and failed reads never mean
/// unavailable. The hold command still rechecks capacity transactionally.
class BookingDateAvailability extends ChangeNotifier {
  BookingDateAvailability(
      {required this.repository,
      required this.coachId,
      required this.isCurrent});
  final MemberBookingOptionsRepository repository;
  final String coachId;
  final bool Function() isCurrent;
  final _values = <String, BookingOptionsContext>{};
  final _failed = <String>{};
  final _checking = <String>{};
  BookingOptionsContext? _reference;
  String? _calendarKey;
  int _generation = 0, page = 0;
  bool _disposed = false, loading = false;
  bool get _current => !_disposed && isCurrent();
  bool get hasPrevious => page > 0;
  bool get hasNext => _reference != null && (page + 1) * 7 < _dayCount;
  int get _dayCount =>
      DateTime.parse(_reference!.throughLocalDate)
          .difference(DateTime.parse(_reference!.todayLocalDate))
          .inDays +
      1;
  List<String> get days {
    if (_reference == null || !_current) return const [];
    final first = DateTime.parse(_reference!.todayLocalDate);
    return [
      for (var i = page * 7; i < _dayCount && i < (page + 1) * 7; i++)
        first.add(Duration(days: i)).toIso8601String().substring(0, 10)
    ];
  }

  BookingDateState state(String date) => _checking.contains(date)
      ? BookingDateState.checking
      : _failed.contains(date)
          ? BookingDateState.failed
          : _values[date] == null
              ? BookingDateState.checking
              : _values[date]!.options.isEmpty
                  ? BookingDateState.unavailable
                  : BookingDateState.available;
  BookingOptionsContext? value(String date) => _current ? _values[date] : null;
  BookingOptionsContext? get firstAvailable => days
      .where((d) => state(d) == BookingDateState.available)
      .map((d) => _values[d]!)
      .firstOrNull;

  Future<void> loadPage(BookingOptionsContext reference,
      {int? targetPage, bool refresh = false}) async {
    if (!_current) return;
    final key =
        '${repository.scope.userId}:${repository.scope.organizationId}:${reference.coachId}:${reference.durationMinutes}:${reference.timeZone}:${reference.todayLocalDate}:${reference.throughLocalDate}';
    if (_calendarKey != key) {
      _values.clear();
      _failed.clear();
      _checking.clear();
      _calendarKey = key;
    }
    _reference = reference;
    final selectedPage = DateTime.parse(reference.localDate)
            .difference(DateTime.parse(reference.todayLocalDate))
            .inDays ~/
        7;
    page = (targetPage ?? selectedPage).clamp(0, (_dayCount - 1) ~/ 7);
    final generation = ++_generation;
    final pageDays = days;
    if (refresh) {
      for (final day in pageDays) {
        _values.remove(day);
        _failed.remove(day);
      }
    }
    _values[reference.localDate] = reference;
    _checking.clear();
    final pending = pageDays
        .where((d) => !_values.containsKey(d) || _failed.contains(d))
        .toList();
    _checking.addAll(pending);
    loading = pending.isNotEmpty;
    notifyListeners();
    var next = 0;
    Future<void> worker() async {
      while (_current && generation == _generation && next < pending.length) {
        final day = pending[next++];
        await _read(day, generation);
      }
    }

    await Future.wait([for (var i = 0; i < 3; i++) worker()]);
    if (_current && generation == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> retry(String day) async {
    if (!_current || loading || !days.contains(day)) return;
    final generation = ++_generation;
    _checking.add(day);
    loading = true;
    notifyListeners();
    await _read(day, generation);
    if (_current && generation == _generation) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _read(String day, int generation) async {
    try {
      final result = await repository
          .load(coachId: coachId, localDate: day, durationMinutes: 60)
          .timeout(const Duration(seconds: 15));
      if (!_current || generation != _generation) return;
      if (result.coachId != coachId ||
          result.durationMinutes != 60 ||
          result.localDate != day ||
          result.timeZone != _reference!.timeZone ||
          result.todayLocalDate != _reference!.todayLocalDate ||
          result.throughLocalDate != _reference!.throughLocalDate) {
        throw const FormatException('Calendar response mismatch');
      }
      _values[day] = result;
      _failed.remove(day);
    } catch (_) {
      if (_current && generation == _generation) {
        _values.remove(day);
        _failed.add(day);
      }
    } finally {
      if (_current && generation == _generation) {
        _checking.remove(day);
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _disposed = true;
    _values.clear();
    _failed.clear();
    _checking.clear();
    super.dispose();
  }
}
