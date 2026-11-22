import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/operations_calendar/operations_calendar_data.dart';

final _from = DateTime.utc(2026, 11, 21, 16);
final _to = DateTime.utc(2026, 11, 22, 16);
const _types = {CalendarEventType.booking, CalendarEventType.announcement};

Map<String, Object?> event({
  String id = 'booking:b1',
  String type = 'booking',
  String? branch = 'east',
  List<String>? branches,
  DateTime? start,
  DateTime? end,
}) =>
    {
      'id': id,
      'sourceId': 'fixture',
      'title': 'Fixture operations',
      'type': type,
      'status': type == 'booking' ? 'pending_hold' : 'active',
      'startAtMillis': (start ?? _from).millisecondsSinceEpoch,
      'endAtMillis': (end ?? _to).millisecondsSinceEpoch,
      if (branch != null) 'branchId': branch,
      if (branches != null) 'branchIds': branches,
    };

void main() {
  test('bounds and scopes read requests and deduplicates stable IDs', () async {
    final warning =
        event(id: 'announcement:x', type: 'announcement', branch: null);
    final repo = FirebaseOperationsCalendarRepository((input) async {
      expect(input, {
        'action': 'calendarEvents',
        'startAtMillis': _from.millisecondsSinceEpoch,
        'endAtMillis': _to.millisecondsSinceEpoch,
        'types': ['booking', 'announcement'],
        'branchId': 'east',
      });
      return {
        'events': [event(), warning, warning],
        'unavailable': ['booking'],
      };
    });
    final reply = await repo.loadEvents(
        start: _from, end: _to, types: _types, branchId: 'east');
    expect(
        reply.events.map((item) => item.id), ['booking:b1', 'announcement:x']);
    expect(reply.events.first.status, 'pending_hold');
    expect(reply.events.first.start, _from);
    expect(reply.unavailable, {CalendarEventType.booking});
  });

  test('rejects neighboring branches and end-exclusive event boundaries',
      () async {
    for (final invalid in [
      event(branch: 'west'),
      event(
          id: 'announcement:x',
          type: 'announcement',
          branch: null,
          branches: ['west']),
      event(start: _to, end: _to.add(const Duration(hours: 1))),
      event(start: _from.subtract(const Duration(hours: 1)), end: _from),
    ]) {
      final repo = FirebaseOperationsCalendarRepository((_) async => {
            'events': [invalid],
            'unavailable': [],
          });
      await expectLater(
          repo.loadEvents(
              start: _from, end: _to, types: _types, branchId: 'east'),
          throwsFormatException);
    }
  });

  test(
      'keeps MYT daily statistics as civil dates and distinguishes null from zero',
      () async {
    final repo = FirebaseOperationsCalendarRepository((input) async {
      expect(input['branchId'], isNull);
      expect(input['action'], 'calendarInsights');
      return {
        'daily': [
          {
            'date': '2026-11-22',
            'visits': 0,
            'bookings': 3,
            'coachingMinor': null
          },
        ],
        'unavailable': ['coachingMinor'],
      };
    });
    final reply = await repo.loadInsights(start: _from, end: _to);
    final day = reply.daily.single;
    expect(day.date, DateTime.utc(2026, 11, 22));
    expect(day.visits, 0);
    expect(day.bookings, 3);
    expect(day.coachingMinor, isNull);
    expect(reply.unavailable, {'coachingMinor'});
  });

  test('keeps inactive branches and errors when the cursor repeats', () async {
    var repeats = false;
    final repo = FirebaseOperationsCalendarRepository((input) async => {
          'records': [
            if (input['afterId'] == null)
              {
                'branchId': 'east',
                'displayName': 'East Gym',
                'status': 'active'
              }
            else
              {
                'branchId': 'west',
                'displayName': 'Former West Gym',
                'status': 'inactive'
              },
          ],
          'nextAfterId': input['afterId'] == null || repeats ? 'east' : null,
        });
    final branches = await repo.loadBranches();
    expect(
        branches.map((branch) => branch.name), ['East Gym', 'Former West Gym']);
    expect(branches.map((branch) => branch.active), [true, false]);
    repeats = true;
    await expectLater(repo.loadBranches(), throwsFormatException);
  });
}
