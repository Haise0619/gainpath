import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> option() => {
      'branchId': 'branch-1',
      'startAtMillis': 1893492000000,
      'endAtMillis': 1893495600000,
      'startLabel': '10:00 +00:00',
      'endLabel': '11:00 +00:00'
    };
Map<String, dynamic> options() => {
      'schemaVersion': 1,
      'coachId': 'coach-1',
      'durationMinutes': 60,
      'serverNowMillis': 1893488400000,
      'todayLocalDate': '2030-01-01',
      'localDate': '2030-01-01',
      'timeZone': 'UTC',
      'throughLocalDate': '2030-01-31',
      'permittedBranchIds': ['branch-1'],
      'options': [option()]
    };
Map<String, dynamic> record() => {
      'bookingId': 'booking-1',
      'schemaVersion': 1,
      'organizationId': 'org-1',
      'memberId': 'member-1',
      'coachId': 'coach-1',
      'branchId': 'branch-1',
      'requestId': 'request-1',
      'startAtMillis': 1893492000000,
      'endAtMillis': 1893495600000,
      'durationMinutes': 60,
      'status': 'pending_hold',
      'holdExpiresAtMillis': 1893489300000,
      'localDate': '2030-01-01',
      'timeZone': 'UTC',
      'policyVersion': 'policy-1',
      'createdAtMillis': 1893488400000,
      'startLabel': '10:00 +00:00',
      'endLabel': '11:00 +00:00',
      'expiryLabel': '09:15 +00:00'
    };
Map<String, dynamic> page() => {
      'schemaVersion': 1,
      'serverNowMillis': 1893488400000,
      'timeZone': 'UTC',
      'firstLocalDate': '2030-01-01',
      'throughLocalDate': '2030-01-31',
      'records': [record()]
    };

void main() {
  test('options accept Coach configured advance windows from 1 through 30 days',
      () {
    for (final days in [1, 14, 30]) {
      final json = {
        ...options(),
        'throughLocalDate': '2030-01-${(days + 1).toString().padLeft(2, '0')}'
      };
      expect(BookingOptionsContext.fromJson(json).throughLocalDate,
          json['throughLocalDate']);
    }
    for (final last in ['2030-01-01', '2030-02-01']) {
      expect(
          () => BookingOptionsContext.fromJson(
              {...options(), 'throughLocalDate': last}),
          throwsFormatException);
    }
    expect(
        () => BookingOptionsContext.fromJson({
              ...options(),
              'throughLocalDate': '2030-01-15',
              'localDate': '2030-01-16'
            }),
        throwsFormatException);
  });
  test('options preserve epochs and server labels with immutable collections',
      () {
    final json = options();
    final result = BookingOptionsContext.fromJson(json,
        expectedCoachId: 'coach-1',
        expectedDurationMinutes: 60,
        expectedLocalDate: '2030-01-01');
    expect(result.toJson(), json);
    expect(result.options.single.startAt.isUtc, isTrue);
    (json['options'] as List).clear();
    expect(result.options, hasLength(1));
    expect(() => result.options.clear(), throwsUnsupportedError);
    expect(() => result.permittedBranchIds.clear(), throwsUnsupportedError);
  });
  test('options reject malformed data and mismatched request context', () {
    for (final json in [
      {...options(), 'private': 'secret'},
      {...options(), 'schemaVersion': 1.0},
      {...options(), 'serverNowMillis': 0},
      {...options(), 'localDate': '2030-02-30'},
      {
        ...options(),
        'options': [
          {...option(), 'startAtMillis': 1893492000001}
        ]
      },
      {
        ...options(),
        'options': [
          {...option(), 'endAtMillis': 1893493800000}
        ]
      },
      {
        ...options(),
        'options': [
          {...option(), 'branchId': 'other'}
        ]
      },
      {...options(), 'unavailableReason': 'daily_limit'},
      {...options(), 'options': []},
    ]) {
      expect(() => BookingOptionsContext.fromJson(json), throwsFormatException);
    }
    expect(
        () =>
            BookingOptionsContext.fromJson(options(), expectedCoachId: 'other'),
        throwsFormatException);
    expect(
        () => BookingOptionsContext.fromJson(options(),
            expectedDurationMinutes: 30),
        throwsFormatException);
    expect(
        () => BookingOptionsContext.fromJson(options(),
            expectedLocalDate: '2030-01-02'),
        throwsFormatException);
    final empty = {
      ...options(),
      'options': [],
      'unavailableReason': 'no_open_times'
    };
    expect(BookingOptionsContext.fromJson(empty).toJson(), empty);
  });
  test('persisted known states never substitute mock pending or elapsed expiry',
      () {
    for (final status in [
      'pending_hold',
      'confirmed',
      'cancelled',
      'completed',
      'refunded'
    ]) {
      final json = {...record(), 'status': status};
      expect(PersistedBookingRecord.fromJson(json).toJson(), json);
    }
    expect(PersistedBookingRecord.fromJson(record()).status,
        BookingStatus.pendingHold);
    for (final json in [
      {...record(), 'status': 'pending'},
      {...record(), 'status': 'expired'},
      {...record(), 'createdBy': 'private'},
      {...record(), 'endAtMillis': 0},
      {...record(), 'holdExpiresAtMillis': 8639999996400001},
      {...record(), 'createdAtMillis': 1.0},
      {...record(), 'durationMinutes': 30},
    ]) {
      expect(
          () => PersistedBookingRecord.fromJson(json), throwsFormatException);
    }
  });
  test('page validates identity ordering cursor and immutable records', () {
    final json = page();
    final result = BookingPage.fromJson(json,
        expectedOrganizationId: 'org-1',
        expectedMemberId: 'member-1',
        expectedCoachId: 'coach-1',
        permittedBranchIds: ['branch-1']);
    expect(result.toJson(), json);
    expect(() => result.records.clear(), throwsUnsupportedError);
    expect(() => BookingPage.fromJson(json, expectedOrganizationId: 'other'),
        throwsFormatException);
    expect(() => BookingPage.fromJson(json, expectedMemberId: 'other'),
        throwsFormatException);
    expect(() => BookingPage.fromJson(json, expectedCoachId: 'other'),
        throwsFormatException);
    expect(() => BookingPage.fromJson(json, permittedBranchIds: ['other']),
        throwsFormatException);
    for (final invalid in [
      {...page(), 'unknown': true},
      {...page(), 'records': List.generate(21, (_) => record())},
      {
        ...page(),
        'records': [record(), record()]
      },
      {
        ...page(),
        'nextCursor': {'startAtMillis': 1893492000000, 'bookingId': 'other'}
      },
      {...page(), 'throughLocalDate': '2030-02-01'},
    ]) {
      expect(() => BookingPage.fromJson(invalid), throwsFormatException);
    }
    final continued = {
      ...page(),
      'nextCursor': {'startAtMillis': 1893492000000, 'bookingId': 'booking-1'}
    };
    expect(BookingPage.fromJson(continued).toJson(), continued);
  });
  test('booking exceptions expose safe messages without transport detail', () {
    expect(const BookingException('permission-denied').message,
        contains('account'));
    expect(const BookingException('transport-secret').toString(),
        isNot(contains('transport-secret')));
  });
}
