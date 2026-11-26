import 'package:flutter/foundation.dart';
import 'package:gainpath_ui/gainpath_ui.dart' show ClassCall, classRows;

enum CalendarEventType { booking, availability, announcement, groupClass }

@immutable
class OperationsEvent {
  const OperationsEvent({
    required this.id,
    required this.sourceId,
    required this.title,
    required this.type,
    required this.start,
    required this.end,
    required this.status,
    this.branchId,
    this.branchIds = const [],
    this.coachId,
    this.description,
    this.category,
    this.paymentStatus,
    this.allDay = false,
  });

  final String id;
  final String sourceId;
  final String title;
  final CalendarEventType type;
  final DateTime start;
  final DateTime end;
  final String status;
  final String? branchId;
  final List<String> branchIds;
  final String? coachId;
  final String? description;
  final String? category;
  final String? paymentStatus;
  final bool allDay;

  factory OperationsEvent.fromJson(Map<Object?, Object?> json) =>
      OperationsEvent(
        id: _text(json['id']),
        sourceId: _text(json['sourceId']),
        title: _text(json['title']),
        type: CalendarEventType.values.byName(_text(json['type'])),
        start: _instant(json['startAtMillis']),
        end: _instant(json['endAtMillis']),
        status: _text(json['status']),
        branchId: json['branchId'] as String?,
        branchIds: List.unmodifiable(
            (json['branchIds'] as List? ?? const []).map(_text)),
        coachId: json['coachId'] as String?,
        description: json['description'] as String?,
        category: json['category'] as String?,
        paymentStatus: json['paymentStatus'] as String?,
        allDay: json['allDay'] as bool? ?? false,
      );
}

@immutable
class CalendarBranch {
  const CalendarBranch({
    required this.id,
    required this.name,
    required this.active,
  });

  final String id;
  final String name;
  final bool active;
}

@immutable
class CalendarEventsResult {
  const CalendarEventsResult(this.events, this.unavailable);
  final List<OperationsEvent> events;
  final Set<CalendarEventType> unavailable;
}

@immutable
class CalendarInsightDay {
  const CalendarInsightDay({
    required this.date,
    required this.visits,
    required this.bookings,
    required this.coachingMinor,
  });

  /// UTC-shaped civil date, representing a day in Malaysia Time.
  final DateTime date;
  final int? visits;
  final int? bookings;
  final int? coachingMinor;
}

@immutable
class CalendarInsightsResult {
  const CalendarInsightsResult(this.daily, this.unavailable);
  final List<CalendarInsightDay> daily;
  final Set<String> unavailable;
}

abstract interface class OperationsCalendarRepository {
  Future<List<CalendarBranch>> loadBranches();
  Future<CalendarEventsResult> loadEvents({
    required DateTime start,
    required DateTime end,
    required Set<CalendarEventType> types,
    String? branchId,
  });
  Future<CalendarInsightsResult> loadInsights({
    required DateTime start,
    required DateTime end,
    String? branchId,
  });
}

typedef OperationsCalendarRequest = Future<Map<String, dynamic>> Function(
    Map<String, Object?>);

/// Uses the same authenticated branch callable as the existing Admin module.
class FirebaseOperationsCalendarRepository
    implements OperationsCalendarRepository {
  const FirebaseOperationsCalendarRepository(this.request, {this.groupClasses});

  final OperationsCalendarRequest request;
  final ClassCall? groupClasses;

  @override
  Future<List<CalendarBranch>> loadBranches() async {
    final branches = <String, CalendarBranch>{};
    final cursors = <String>{};
    String? cursor;
    do {
      final data = await request({
        'action': 'list',
        if (cursor != null) 'afterId': cursor,
      });
      for (final row in (data['records'] as List).cast<Map>()) {
        final id = _text(row['branchId']);
        branches[id] = CalendarBranch(
          id: id,
          name: _text(row['displayName']),
          active: row['status'] == 'active',
        );
      }
      cursor = data['nextAfterId'] as String?;
      if (cursor != null && (!cursors.add(cursor) || cursors.length >= 32)) {
        throw const FormatException('Branch directory page limit exceeded.');
      }
    } while (cursor != null);
    return List.unmodifiable(branches.values);
  }

  @override
  Future<CalendarEventsResult> loadEvents({
    required DateTime start,
    required DateTime end,
    required Set<CalendarEventType> types,
    String? branchId,
  }) async {
    if (types.isEmpty) return const CalendarEventsResult([], {});
    final standard =
        types.where((type) => type != CalendarEventType.groupClass);
    final data = standard.isEmpty
        ? <String, dynamic>{'events': [], 'unavailable': []}
        : await request({
            'action': 'calendarEvents',
            ..._range(start, end, branchId),
            'types': standard.map((type) => type.name).toList(),
          });
    final events = <String, OperationsEvent>{};
    for (final json in (data['events'] as List).cast<Map>()) {
      final event = OperationsEvent.fromJson(json);
      final inBranch = branchId == null ||
          event.branchId == branchId ||
          (event.type == CalendarEventType.announcement &&
              (event.branchIds.isEmpty || event.branchIds.contains(branchId)));
      if (!types.contains(event.type) ||
          !inBranch ||
          !event.end.isAfter(event.start) ||
          !event.start.isBefore(end) ||
          !event.end.isAfter(start)) {
        throw const FormatException('Calendar event outside requested scope.');
      }
      events[event.id] = event;
    }
    final unavailable = (data['unavailable'] as List)
        .map((type) => CalendarEventType.values.byName(_text(type)))
        .toSet();
    if (types.contains(CalendarEventType.groupClass) && groupClasses != null) {
      try {
        final result = await groupClasses!('calendar', {
          if (branchId != null) 'branchId': branchId,
          'startAtMillis': start.millisecondsSinceEpoch,
          'endAtMillis': end.millisecondsSinceEpoch,
        });
        for (final row in classRows(result['classes'])) {
          final id = row['id'] as String;
          events['groupClass-$id'] = OperationsEvent(
            id: 'groupClass-$id',
            sourceId: id,
            title: row['title'] as String,
            type: CalendarEventType.groupClass,
            start: _instant(row['startAtMillis']),
            end: _instant(row['endAtMillis']),
            status: row['status'] as String,
            branchId: row['branchId'] as String,
            coachId: row['coachId'] as String?,
            description:
                '${row['instructor']} · ${row['activeCount']}/${row['capacity']} registered',
          );
        }
      } catch (_) {
        unavailable.add(CalendarEventType.groupClass);
      }
    }
    return CalendarEventsResult(
        List.unmodifiable(events.values), Set.unmodifiable(unavailable));
  }

  @override
  Future<CalendarInsightsResult> loadInsights({
    required DateTime start,
    required DateTime end,
    String? branchId,
  }) async {
    final data = await request({
      'action': 'calendarInsights',
      ..._range(start, end, branchId),
    });
    final daily = (data['daily'] as List).cast<Map>().map((row) {
      final day = DateTime.parse('${_text(row['date'])}T00:00:00Z');
      final dayStart = day.subtract(const Duration(hours: 8));
      if (dayStart.isBefore(start) || !dayStart.isBefore(end)) {
        throw const FormatException(
            'Calendar statistic outside requested range.');
      }
      return CalendarInsightDay(
        date: day,
        visits: _count(row['visits']),
        bookings: _count(row['bookings']),
        coachingMinor: _count(row['coachingMinor']),
      );
    });
    return CalendarInsightsResult(
      List.unmodifiable(daily),
      Set.unmodifiable((data['unavailable'] as List).map(_text)),
    );
  }

  Map<String, Object?> _range(DateTime start, DateTime end, String? branchId) =>
      {
        'startAtMillis': start.millisecondsSinceEpoch,
        'endAtMillis': end.millisecondsSinceEpoch,
        if (branchId != null) 'branchId': branchId,
      };
}

String _text(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw const FormatException('Missing calendar text.');
}

int? _count(Object? value) {
  if (value == null) return null;
  if (value is int && value >= 0) return value;
  throw const FormatException('Invalid calendar count.');
}

DateTime _instant(Object? value) =>
    DateTime.fromMillisecondsSinceEpoch(_count(value)!, isUtc: true);
