import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

class _FakeBookingSource implements BookingRemoteDataSource {
  @override
  Future<BookingHoldDto> createHold(
          CreateBookingHoldRequestDto request) async =>
      BookingHoldDto(
        bookingId: 'booking-1',
        requestId: request.requestId,
        status: 'pending_hold',
        holdExpiresAt: DateTime.utc(2030, 1, 1, 9, 15),
      );
}

void main() {
  test('remote booking repository maps a server hold to a domain value',
      () async {
    final repository = RemoteBookingRepository(_FakeBookingSource());
    final result = await repository.createHold(
      CreateBookingHoldRequest(
        requestId: 'request-1',
        organizationId: const OrganizationId('org-1'),
        branchId: const BranchId('branch-1'),
        coachId: const UserId('coach-1'),
        startAt: DateTime.utc(2030, 1, 1, 10),
        durationMinutes: 60,
      ),
    );

    expect(result.bookingId, 'booking-1');
    expect(result.status, BookingStatus.pendingHold);
  });
}
