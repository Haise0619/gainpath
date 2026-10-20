import '../identity.dart' show SessionScope;

bool _id(dynamic value) =>
    value is String && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value);
int _int(dynamic value, {int min = 0, int max = 8639999996400000}) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Unsupported schedule data.');
  }
  return value;
}

String _date(dynamic value) {
  if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('Invalid schedule date.');
  }
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
    throw const FormatException('Invalid schedule date.');
  }
  return value;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is! Map) throw const FormatException('Unsupported schedule data.');
  return Map<String, dynamic>.from(value);
}

List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse, int max) {
  if (raw is! List || raw.length > max) {
    throw const FormatException('Unsupported schedule list.');
  }
  return List.unmodifiable(raw.map((v) => parse(_map(v))));
}

class DatedCoachWindow {
  DatedCoachWindow(
      {required this.branchId,
      required this.startAtMillis,
      required this.endAtMillis}) {
    if (!_id(branchId) ||
        _int(startAtMillis, min: 1) % 1800000 != 0 ||
        _int(endAtMillis, min: 1) % 1800000 != 0 ||
        endAtMillis <= startAtMillis ||
        endAtMillis - startAtMillis > 26 * 3600000) {
      throw const FormatException('Check schedule time boundaries.');
    }
  }
  final String branchId;
  final int startAtMillis, endAtMillis;
  factory DatedCoachWindow.fromJson(Map<String, dynamic> data) {
    if (!_id(data['branchId'])) {
      throw const FormatException('Invalid schedule branch.');
    }
    return DatedCoachWindow(
        branchId: data['branchId'],
        startAtMillis: _int(data['startAtMillis'], min: 1),
        endAtMillis: _int(data['endAtMillis'], min: 1));
  }
  Map<String, dynamic> toJson() => {
        'branchId': branchId,
        'startAtMillis': startAtMillis,
        'endAtMillis': endAtMillis
      };
}

class CoachTimeBoundary {
  const CoachTimeBoundary({required this.atMillis, required this.label});
  final int atMillis;
  final String label;
  factory CoachTimeBoundary.fromJson(Map<String, dynamic> data) {
    if (data['label'] is! String ||
        (data['label'] as String).isEmpty ||
        (data['label'] as String).length > 80) {
      throw const FormatException('Unsupported time label.');
    }
    final time = _int(data['atMillis'], min: 1);
    if (time % 1800000 != 0) {
      throw const FormatException('Unsupported time grid.');
    }
    return CoachTimeBoundary(atMillis: time, label: data['label']);
  }
}

class CoachAvailabilityDay {
  CoachAvailabilityDay(
      {required this.localDate,
      this.revision,
      this.editable = false,
      this.reviewRequired = false,
      required List<DatedCoachWindow> windows,
      List<CoachTimeBoundary> boundaries = const [],
      List<CoachTimeBoundary> displayTimes = const []})
      : windows = List.unmodifiable(windows),
        boundaries = List.unmodifiable(boundaries),
        displayTimes = List.unmodifiable(displayTimes);
  final String localDate;
  final int? revision;
  final bool editable, reviewRequired;
  final List<DatedCoachWindow> windows;
  final List<CoachTimeBoundary> boundaries, displayTimes;
  String labelFor(int instant) =>
      [...boundaries, ...displayTimes]
          .where((b) => b.atMillis == instant)
          .map((b) => b.label)
          .firstOrNull ??
      '${DateTime.fromMillisecondsSinceEpoch(instant, isUtc: true).toIso8601String()} UTC';
  factory CoachAvailabilityDay.fromJson(Map<String, dynamic> data) {
    final revision = data.containsKey('revision')
        ? _int(data['revision'], max: 9007199254740990)
        : null;
    final editable = data['editable'] == true;
    if ((data.containsKey('editable') && data['editable'] is! bool) ||
        (data.containsKey('reviewRequired') &&
            data['reviewRequired'] is! bool) ||
        (editable && (revision == null || data['reviewRequired'] == true))) {
      throw const FormatException('Unsupported edit authority.');
    }
    return CoachAvailabilityDay(
        localDate: _date(data['localDate']),
        revision: revision,
        editable: editable,
        reviewRequired: data['reviewRequired'] == true,
        windows: _list(data['windows'], DatedCoachWindow.fromJson, 96),
        boundaries:
            _list(data['boundaries'] ?? [], CoachTimeBoundary.fromJson, 104),
        displayTimes:
            _list(data['displayTimes'] ?? [], CoachTimeBoundary.fromJson, 192));
  }
}

class CoachAvailabilityContext {
  CoachAvailabilityContext(
      {required this.coachId,
      required this.serverNowMillis,
      required this.todayLocalDate,
      required this.timeZone,
      this.policyVersion,
      this.writableFromLocalDate,
      this.writableThroughLocalDate,
      required List<String> assignedBranchIds,
      required List<CoachAvailabilityDay> days})
      : assignedBranchIds = List.unmodifiable(assignedBranchIds),
        days = List.unmodifiable(days);
  final String coachId, todayLocalDate, timeZone;
  final int serverNowMillis;
  final String? policyVersion, writableFromLocalDate, writableThroughLocalDate;
  final List<String> assignedBranchIds;
  final List<CoachAvailabilityDay> days;
  factory CoachAvailabilityContext.fromJson(Map<String, dynamic> data) {
    final branches = data['assignedBranchIds'];
    if (data['schemaVersion'] != 1 ||
        !_id(data['coachId']) ||
        data['timeZone'] is! String ||
        (data['timeZone'] as String).isEmpty ||
        (data['timeZone'] as String).length > 100 ||
        branches is! List ||
        branches.isEmpty ||
        branches.length > 8 ||
        branches.any((b) => !_id(b)) ||
        branches.toSet().length != branches.length ||
        (data.containsKey('policyVersion') &&
            (data['policyVersion'] is! String ||
                (data['policyVersion'] as String).isEmpty))) {
      throw const FormatException('Unsupported schedule context.');
    }
    final days = _list(data['days'], CoachAvailabilityDay.fromJson, 7);
    if (days.isEmpty ||
        days.map((d) => d.localDate).toSet().length != days.length) {
      throw const FormatException('Unsupported schedule dates.');
    }
    return CoachAvailabilityContext(
        coachId: data['coachId'],
        serverNowMillis: _int(data['serverNowMillis']),
        todayLocalDate: _date(data['todayLocalDate']),
        timeZone: data['timeZone'],
        policyVersion: data['policyVersion'],
        writableFromLocalDate: data['writableFromLocalDate'] == null
            ? null
            : _date(data['writableFromLocalDate']),
        writableThroughLocalDate: data['writableThroughLocalDate'] == null
            ? null
            : _date(data['writableThroughLocalDate']),
        assignedBranchIds: List<String>.from(branches),
        days: days);
  }
}

class CoachAvailabilitySaveResult {
  const CoachAvailabilitySaveResult(
      {required this.requestId,
      required this.coachId,
      required this.localDate,
      required this.revision,
      required this.outcome});
  final String requestId, coachId, localDate, outcome;
  final int revision;
  factory CoachAvailabilitySaveResult.fromJson(Map<String, dynamic> data) {
    if (data['schemaVersion'] != 1 ||
        !_id(data['coachId']) ||
        !_id(data['requestId']) ||
        !['saved', 'removed'].contains(data['outcome'])) {
      throw const FormatException('Unsupported schedule response.');
    }
    return CoachAvailabilitySaveResult(
        requestId: data['requestId'],
        coachId: data['coachId'],
        localDate: _date(data['localDate']),
        revision: _int(data['revision'], min: 1, max: 9007199254740991),
        outcome: data['outcome']);
  }
}

class CoachAvailabilityException implements Exception {
  const CoachAvailabilityException(this.code);
  final String code;
  String get message => switch (code) {
        'aborted' => 'Schedule or reservations changed. Discard and reload.',
        'permission-denied' ||
        'unauthenticated' =>
          'Schedule unavailable for this account.',
        'failed-precondition' =>
          'Coach, policy or stored schedule needs authorized review.',
        'invalid-argument' =>
          'Check the date, branch and non-overlapping half-hour windows.',
        _ => 'Could not complete the schedule operation. Refresh or retry.'
      };
  @override
  String toString() => message;
}

abstract interface class CoachAvailabilityRepository {
  SessionScope get scope;
  Future<CoachAvailabilityContext> load(
      {required String coachId, String? firstLocalDate, int dayCount = 7});
  Future<CoachAvailabilitySaveResult> save(
      {required CoachAvailabilityDay baseline,
      required CoachAvailabilityContext context,
      required List<DatedCoachWindow> windows,
      required String requestId});
}
