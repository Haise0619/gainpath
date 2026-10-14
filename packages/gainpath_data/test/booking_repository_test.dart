import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

Map<String, dynamic> response({String requestId = 'request-1'}) => {
      'schemaVersion': 1,
      'requestId': requestId,
      'bookingId': 'booking-1',
      'status': 'pending_hold',
      'holdExpiresAtMillis': 1893489300000,
    };

class _Source implements BookingRemoteDataSource {
  _Source(this.json);
  final Map<String, dynamic> json;
  CreateBookingHoldRequestDto? received;
  @override
  Future<BookingHoldDto> createHold(CreateBookingHoldRequestDto request) async {
    received = request;
    return BookingHoldDto.fromJson(json);
  }
}

CreateBookingHoldRequest request() => CreateBookingHoldRequest(
      requestId: 'request-1',
      organizationId: const OrganizationId('org-1'),
      memberId: const UserId('member-1'),
      branchId: const BranchId('branch-1'),
      coachId: const UserId('coach-1'),
      startAt: DateTime.utc(2030, 1, 1, 10),
      durationMinutes: 60,
    );
void main() {
  test(
      'remote repository sends exact member command and returns UTC pending hold',
      () async {
    final source = _Source(response());
    final hold = await RemoteBookingRepository(source).createHold(request());
    expect(source.received!.toJson(), {
      'schemaVersion': 1,
      'requestId': 'request-1',
      'organizationId': 'org-1',
      'memberId': 'member-1',
      'branchId': 'branch-1',
      'coachId': 'coach-1',
      'startAtMillis': 1893492000000,
      'durationMinutes': 60,
    });
    expect(
        CreateBookingHoldRequestDto.fromJson(source.received!.toJson())
            .toJson(),
        source.received!.toJson());
    expect(hold.bookingId, 'booking-1');
    expect(hold.status, BookingStatus.pendingHold);
    expect(hold.holdExpiresAt, DateTime.utc(2030, 1, 1, 9, 15));
    expect(hold.holdExpiresAt.isUtc, isTrue);
    expect(BookingHoldDto.fromJson(response()).toJson(), response());
  });
  test(
      'create response rejects mock statuses malformed fields and unsafe millis',
      () {
    for (final invalid in [
      {...response(), 'extra': true},
      {...response(), 'schemaVersion': 1.0},
      {...response(), 'bookingId': 'bad/path'},
      {...response(), 'status': 'confirmed'},
      {...response(), 'status': 'pending'},
      {...response(), 'status': 'unknown-secret'},
      {...response(), 'holdExpiresAtMillis': 0},
      {...response(), 'holdExpiresAtMillis': 1.5},
      {...response(), 'holdExpiresAtMillis': 8639999996400001},
    ]) {
      expect(() => BookingHoldDto.fromJson(invalid), throwsFormatException);
    }
    expect(
        () => BookingHoldDto.fromJson(response(requestId: 'different'),
            expectedRequestId: 'request-1'),
        throwsFormatException);
  });
  test(
      'repository verifies response identity even when source skips correlation',
      () async {
    await expectLater(
        RemoteBookingRepository(_Source(response(requestId: 'different')))
            .createHold(request()),
        throwsFormatException);
  });
}
