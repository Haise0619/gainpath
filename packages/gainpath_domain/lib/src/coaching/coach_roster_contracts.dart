/// Server-owned recurring schedule and private time-off configuration.
class CoachWeeklyDay {
  const CoachWeeklyDay(
      {required this.dayOfWeek,
      required this.isActive,
      required this.startMinute,
      required this.endMinute,
      required this.branchId});
  final int dayOfWeek, startMinute, endMinute;
  final bool isActive;
  final String branchId;
  factory CoachWeeklyDay.fromJson(Map<String, dynamic> d) {
    final start = _number(d['startMinute'], 0, 1410);
    final end = _number(d['endMinute'], 30, 1440);
    if (d['isActive'] is! bool ||
        start % 30 != 0 ||
        end % 30 != 0 ||
        (d['isActive'] == true && start >= end)) {
      throw const FormatException('Invalid weekly working hours.');
    }
    return CoachWeeklyDay(
        dayOfWeek: _number(d['dayOfWeek'], 1, 7),
        isActive: d['isActive'],
        startMinute: start,
        endMinute: end,
        branchId: _id(d['branchId']));
  }
  Map<String, dynamic> toJson() => {
        'dayOfWeek': dayOfWeek,
        'isActive': isActive,
        'startMinute': startMinute,
        'endMinute': endMinute,
        'branchId': branchId
      };
}

class CoachWeeklyAvailability {
  CoachWeeklyAvailability(
      {required this.dailyCapacityHours,
      required this.advanceBookingWindowDays,
      required List<CoachWeeklyDay> schedule})
      : schedule = List.unmodifiable(schedule);
  final int dailyCapacityHours, advanceBookingWindowDays;
  final List<CoachWeeklyDay> schedule;
  factory CoachWeeklyAvailability.fromJson(Map<String, dynamic> d) {
    final days = _list(d['schedule'], CoachWeeklyDay.fromJson, 7);
    if (days.length != 7 || days.map((d) => d.dayOfWeek).toSet().length != 7) {
      throw const FormatException('A complete weekly schedule is required.');
    }
    return CoachWeeklyAvailability(
        dailyCapacityHours: _number(d['dailyCapacityHours'], 1, 24),
        advanceBookingWindowDays: _number(d['advanceBookingWindowDays'], 1, 30),
        schedule: days);
  }
  Map<String, dynamic> toJson() => {
        'dailyCapacityHours': dailyCapacityHours,
        'advanceBookingWindowDays': advanceBookingWindowDays,
        'schedule': schedule.map((d) => d.toJson()).toList()
      };
}

class CoachTimeException {
  const CoachTimeException(
      {required this.id,
      required this.type,
      required this.reason,
      required this.startAtMillis,
      required this.endAtMillis,
      this.startLabel,
      this.endLabel});
  final String id, type, reason;
  final String? startLabel, endLabel;
  final int startAtMillis, endAtMillis;
  factory CoachTimeException.fromJson(Map<String, dynamic> d) {
    final start = _number(d['startAtMillis'], 1, 8639999996400000);
    final end = _number(d['endAtMillis'], 1, 8639999996400000);
    if (!['breakTime', 'offDay', 'leave'].contains(d['type']) ||
        d['reason'] is! String ||
        (d['reason'] as String).length > 200 ||
        start % 1800000 != 0 ||
        end % 1800000 != 0 ||
        end <= start) {
      throw const FormatException('Invalid blocked time.');
    }
    return CoachTimeException(
        id: _id(d['id']),
        type: d['type'],
        reason: d['reason'],
        startLabel:
            d['startLabel'] == null ? null : _text(d['startLabel'], 100),
        endLabel: d['endLabel'] == null ? null : _text(d['endLabel'], 100),
        startAtMillis: start,
        endAtMillis: end);
  }
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'reason': reason,
        'startAtMillis': startAtMillis,
        'endAtMillis': endAtMillis
      };
}

class CoachRosterSnapshot {
  CoachRosterSnapshot(
      {required this.coachId,
      required this.revision,
      required this.serverNowMillis,
      required this.todayLocalDate,
      required this.timeZone,
      required this.policyVersion,
      required this.throughLocalDate,
      required List<String> assignedBranchIds,
      this.weeklyAvailability,
      required List<CoachTimeException> exceptions})
      : assignedBranchIds = List.unmodifiable(assignedBranchIds),
        exceptions = List.unmodifiable(exceptions);
  final String coachId,
      todayLocalDate,
      timeZone,
      policyVersion,
      throughLocalDate;
  final int revision, serverNowMillis;
  final List<String> assignedBranchIds;
  final CoachWeeklyAvailability? weeklyAvailability;
  final List<CoachTimeException> exceptions;
  factory CoachRosterSnapshot.fromJson(Map<String, dynamic> d) {
    if (d['schemaVersion'] != 1 || d['assignedBranchIds'] is! List) {
      throw const FormatException('Invalid roster response.');
    }
    final branches = (d['assignedBranchIds'] as List).map(_id).toList();
    if (branches.isEmpty ||
        branches.length > 8 ||
        branches.toSet().length != branches.length) {
      throw const FormatException('Invalid roster branches.');
    }
    final exceptions = _list(d['exceptions'], CoachTimeException.fromJson, 64);
    if (exceptions.map((e) => e.id).toSet().length != exceptions.length) {
      throw const FormatException('Duplicate blocked time.');
    }
    final weekly = d['weeklyAvailability'] == null
        ? null
        : CoachWeeklyAvailability.fromJson(_map(d['weeklyAvailability']));
    if (weekly != null &&
        weekly.schedule.any((day) => !branches.contains(day.branchId))) {
      throw const FormatException('Roster branch assignments changed.');
    }
    if (_date(d['throughLocalDate']).compareTo(_date(d['todayLocalDate'])) <
        0) {
      throw const FormatException('Invalid roster horizon.');
    }
    return CoachRosterSnapshot(
        coachId: _id(d['coachId']),
        revision: _number(d['revision'], 0, 9007199254740990),
        serverNowMillis: _number(d['serverNowMillis'], 1, 8639999996400000),
        todayLocalDate: _date(d['todayLocalDate']),
        throughLocalDate: _date(d['throughLocalDate']),
        timeZone: _text(d['timeZone'], 100),
        policyVersion: _text(d['policyVersion'], 128),
        assignedBranchIds: branches,
        exceptions: exceptions,
        weeklyAvailability: weekly);
  }
}

abstract interface class CoachRosterRepository {
  Future<CoachRosterSnapshot> loadRoster({required String coachId});
  Future<CoachRosterSnapshot> saveRoster(
      {required CoachRosterSnapshot baseline,
      required CoachWeeklyAvailability weeklyAvailability,
      required List<CoachTimeException> exceptions,
      required String requestId});
}

Map<String, dynamic> _map(dynamic d) {
  if (d is! Map) throw const FormatException('Invalid roster data.');
  return Map<String, dynamic>.from(d);
}

List<T> _list<T>(dynamic d, T Function(Map<String, dynamic>) parse, int max) {
  if (d is! List || d.length > max) {
    throw const FormatException('Invalid roster list.');
  }
  return List.unmodifiable(d.map((v) => parse(_map(v))));
}

int _number(dynamic n, int min, int max) {
  if (n is! int || n < min || n > max) {
    throw const FormatException('Invalid roster number.');
  }
  return n;
}

String _id(dynamic s) {
  if (s is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(s)) {
    throw const FormatException('Invalid roster identifier.');
  }
  return s;
}

String _text(dynamic s, int max) {
  if (s is! String ||
      s.trim().isEmpty ||
      s.length > max ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(s)) {
    throw const FormatException('Invalid roster text.');
  }
  return s;
}

String _date(dynamic s) {
  if (s is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) ||
      DateTime.tryParse('${s}T00:00:00Z')?.toIso8601String().substring(0, 10) !=
          s) {
    throw const FormatException('Invalid roster date.');
  }
  return s;
}
