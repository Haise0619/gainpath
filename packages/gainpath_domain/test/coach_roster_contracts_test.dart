import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

Map<String, dynamic> snapshot() => {
      'schemaVersion': 1,
      'coachId': 'coach',
      'revision': 1,
      'serverNowMillis': 1792368000000,
      'todayLocalDate': '2026-10-19',
      'throughLocalDate': '2026-11-18',
      'timeZone': 'Asia/Kuala_Lumpur',
      'policyVersion': 'booking-v1',
      'assignedBranchIds': ['main'],
      'weeklyAvailability': {
        'dailyCapacityHours': 4,
        'advanceBookingWindowDays': 14,
        'schedule': List.generate(
            7,
            (i) => {
                  'dayOfWeek': i + 1,
                  'isActive': i < 5,
                  'startMinute': 540,
                  'endMinute': 1020,
                  'branchId': 'main'
                })
      },
      'exceptions': <dynamic>[]
    };

void main() {
  test('absent configuration remains truthful; configured hours retain units',
      () {
    final empty = snapshot()
      ..['revision'] = 0
      ..['weeklyAvailability'] = null;
    expect(CoachRosterSnapshot.fromJson(empty).weeklyAvailability, isNull);
    final saved = CoachRosterSnapshot.fromJson(snapshot());
    expect(saved.weeklyAvailability!.dailyCapacityHours, 4);
    expect(saved.weeklyAvailability!.schedule.length, 7);
    expect(
        () => saved.exceptions.add(const CoachTimeException(
            id: 'x',
            type: 'leave',
            reason: '',
            startAtMillis: 1,
            endAtMillis: 2)),
        throwsUnsupportedError);
  });
  test(
      'rejects foreign branches, duplicated weekdays and unsupported policy bounds',
      () {
    for (final mutate in <void Function(Map<String, dynamic>)>[
      (d) => d['assignedBranchIds'] = ['foreign'],
      (d) => d['weeklyAvailability']['schedule'][0]['dayOfWeek'] = 2,
      (d) => d['weeklyAvailability']['dailyCapacityHours'] = 0,
      (d) => d['weeklyAvailability']['advanceBookingWindowDays'] = 31,
      (d) => d['weeklyAvailability']['schedule'][0]['endMinute'] = 540,
      (d) => d['throughLocalDate'] = '2026-10-18',
    ]) {
      final d = snapshot();
      mutate(d);
      expect(() => CoachRosterSnapshot.fromJson(d), throwsFormatException);
    }
  });
  test('server display labels never enter a mutation payload', () {
    final block = CoachTimeException.fromJson({
      'id': 'block',
      'type': 'leave',
      'reason': '',
      'startAtMillis': 1800000,
      'endAtMillis': 3600000,
      'startLabel': '19/10/2026 09:00 GMT+8',
      'endLabel': '19/10/2026 10:00 GMT+8'
    });
    expect(block.startLabel, contains('GMT+8'));
    expect(block.toJson().containsKey('startLabel'), false);
    final d = snapshot()..['exceptions'] = [block.toJson(), block.toJson()];
    expect(() => CoachRosterSnapshot.fromJson(d), throwsFormatException);
  });
}
