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
      branchId: const BranchId('branch-1'),
      coachId: const UserId('coach-1'),
      startAt: DateTime.utc(2030, 1, 1, 10),
      durationMinutes: 60,
    );

    expect(request.startAt.isUtc, isTrue);
    expect(request.durationMinutes, 60);
  });
}
