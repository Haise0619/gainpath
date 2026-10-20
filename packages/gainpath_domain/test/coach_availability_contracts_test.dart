import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  final start = DateTime.utc(2026, 10, 16, 2).millisecondsSinceEpoch;
  Map<String, dynamic> context() => {
        'schemaVersion': 1,
        'coachId': 'coach',
        'serverNowMillis': 1,
        'todayLocalDate': '2026-10-15',
        'timeZone': 'Asia/Kuala_Lumpur',
        'policyVersion': 'booking-v1',
        'assignedBranchIds': ['main'],
        'writableFromLocalDate': '2026-10-16',
        'writableThroughLocalDate': '2026-11-14',
        'days': [
          {
            'localDate': '2026-10-16',
            'revision': 0,
            'editable': true,
            'reviewRequired': false,
            'windows': [],
            'boundaries': [
              {'atMillis': start, 'label': '10:00 GMT+8'},
              {'atMillis': start + 1800000, 'label': '10:30 GMT+8'}
            ]
          }
        ]
      };
  test(
      'immutable server context retains UTC instants and nullable read-only revisions',
      () {
    final value = CoachAvailabilityContext.fromJson(context());
    expect(value.days.single.boundaries.first.atMillis, start);
    expect(() => value.days.clear(), throwsUnsupportedError);
    expect(value.days.single.editable, isTrue);
    final raw = context();
    raw['days'] = [
      {'localDate': '2026-10-16', 'windows': []}
    ];
    final member = CoachAvailabilityContext.fromJson(raw);
    expect(member.days.single.revision, isNull);
    expect(member.days.single.editable, isFalse);
  });
  test('rejects malformed dates, unsafe times and non-grid intervals', () {
    final raw = context()..['todayLocalDate'] = '2026-02-30';
    expect(() => CoachAvailabilityContext.fromJson(raw), throwsFormatException);
    for (final t in [-1, start + 1, 9007199254740992]) {
      expect(
          () => DatedCoachWindow(
              branchId: 'main', startAtMillis: t, endAtMillis: start + 1800000),
          throwsFormatException);
    }
  });
  test(
      'save result preserves stable Coach/date/request identity and progression',
      () {
    final result = CoachAvailabilitySaveResult.fromJson({
      'schemaVersion': 1,
      'coachId': 'coach',
      'requestId': 'remove',
      'localDate': '2026-10-16',
      'revision': 3,
      'outcome': 'removed'
    });
    expect(result.revision, 3);
    expect(result.localDate, '2026-10-16');
    expect(() => CoachAvailabilitySaveResult.fromJson({'schemaVersion': 1}),
        throwsFormatException);
  });
}
