import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

void main() {
  test('money stores minor units and currency without floating point loss', () {
    const amount = Money(minorUnits: 1299, currency: 'MYR');

    expect(amount.minorUnits, 1299);
    expect(amount.currency, 'MYR');
    expect(amount.toString(), 'MYR 12.99');
  });

  test('booking hold requests reject unsupported durations', () {
    expect(
      () => CreateBookingHoldRequest(
        requestId: 'request-1',
        organizationId: const OrganizationId('org-1'),
        memberId: const UserId('member-1'),
        branchId: const BranchId('branch-1'),
        coachId: const UserId('coach-1'),
        startAt: DateTime.utc(2030, 1, 1, 10),
        durationMinutes: 45,
      ),
      throwsArgumentError,
    );
  });

  test('booking hold request retains UTC scheduling identity', () {
    final request = CreateBookingHoldRequest(
      requestId: 'request-1',
      organizationId: const OrganizationId('org-1'),
      memberId: const UserId('member-1'),
      branchId: const BranchId('branch-1'),
      coachId: const UserId('coach-1'),
      startAt: DateTime.utc(2030, 1, 1, 10),
      durationMinutes: 60,
    );

    expect(request.startAt.isUtc, isTrue);
    expect(request.durationMinutes, 60);
  });

  test('booking request emits exact authenticated member wire contract', () {
    final json = <String, dynamic>{
      'schemaVersion': 1,
      'requestId': 'request-1',
      'organizationId': 'org-1',
      'memberId': 'member-1',
      'branchId': 'branch-1',
      'coachId': 'coach-1',
      'startAtMillis': 1893492000000,
      'durationMinutes': 60,
    };
    final request = CreateBookingHoldRequest.fromJson(json);
    expect(request.memberId, const UserId('member-1'));
    expect(request.startAt, DateTime.utc(2030, 1, 1, 10));
    expect(request.toJson(), json);
    for (final invalid in [
      {...json, 'extra': true},
      {...json, 'memberId': 'bad/path'},
      {...json, 'schemaVersion': 1.0},
      {...json, 'startAtMillis': 1.0},
      {...json, 'startAtMillis': 0},
      {...json, 'startAtMillis': 8639999996400001},
      {...json, 'startAtMillis': 1893492000001},
    ]) {
      expect(() => CreateBookingHoldRequest.fromJson(invalid),
          throwsFormatException);
    }
  });
}
