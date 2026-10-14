import 'core.dart';
import 'coaching/booking_wire_validation.dart';

enum BookingStatus { pendingHold, confirmed, cancelled, completed, refunded }

class CreateBookingHoldRequest {
  CreateBookingHoldRequest({
    required this.requestId,
    required this.organizationId,
    required this.memberId,
    required this.branchId,
    required this.coachId,
    required DateTime startAt,
    required this.durationMinutes,
  }) : startAt = startAt.toUtc() {
    try {
      bookingId(requestId);
      bookingId(organizationId.value);
      bookingId(memberId.value);
      bookingId(branchId.value);
      bookingId(coachId.value);
      bookingDuration(durationMinutes);
      bookingInt(this.startAt.millisecondsSinceEpoch);
      if (this.startAt.microsecondsSinceEpoch % 1000 != 0 ||
          this.startAt.millisecondsSinceEpoch % bookingSlotMillis != 0) {
        invalidBookingData();
      }
    } on FormatException {
      throw ArgumentError(
          'Check booking identity, duration and UTC half-hour start.');
    }
  }

  final String requestId;
  final OrganizationId organizationId;
  final UserId memberId;
  final BranchId branchId;
  final UserId coachId;
  final DateTime startAt;
  final int durationMinutes;
  int get schemaVersion => 1;

  factory CreateBookingHoldRequest.fromJson(Map<String, dynamic> data) {
    bookingShape(data, [
      'schemaVersion',
      'requestId',
      'organizationId',
      'memberId',
      'branchId',
      'coachId',
      'startAtMillis',
      'durationMinutes'
    ]);
    bookingVersion(data['schemaVersion']);
    final start = bookingInt(data['startAtMillis']);
    if (start % bookingSlotMillis != 0) {
      invalidBookingData();
    }
    return CreateBookingHoldRequest(
      requestId: bookingId(data['requestId']),
      organizationId: OrganizationId(bookingId(data['organizationId'])),
      memberId: UserId(bookingId(data['memberId'])),
      branchId: BranchId(bookingId(data['branchId'])),
      coachId: UserId(bookingId(data['coachId'])),
      startAt: DateTime.fromMillisecondsSinceEpoch(start, isUtc: true),
      durationMinutes: bookingDuration(data['durationMinutes']),
    );
  }
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'requestId': requestId,
        'organizationId': organizationId.value,
        'memberId': memberId.value,
        'branchId': branchId.value,
        'coachId': coachId.value,
        'startAtMillis': startAt.millisecondsSinceEpoch,
        'durationMinutes': durationMinutes
      };
}

class BookingHold {
  const BookingHold(
      {required this.bookingId,
      required this.requestId,
      required this.status,
      required this.holdExpiresAt});
  final String bookingId;
  final String requestId;
  final BookingStatus status;
  final DateTime holdExpiresAt;
  int get schemaVersion => 1;

  /// The create endpoint only returns a pending hold, including receipt replay.
  factory BookingHold.fromJson(Map<String, dynamic> data,
      {String? expectedRequestId}) {
    bookingShape(data, [
      'schemaVersion',
      'requestId',
      'bookingId',
      'status',
      'holdExpiresAtMillis'
    ]);
    bookingVersion(data['schemaVersion']);
    final request = _bookingIdValue(data['requestId']);
    if (data['status'] != 'pending_hold' ||
        (expectedRequestId != null && request != expectedRequestId)) {
      invalidBookingData();
    }
    return BookingHold(
        bookingId: _bookingIdValue(data['bookingId']),
        requestId: request,
        status: BookingStatus.pendingHold,
        holdExpiresAt: DateTime.fromMillisecondsSinceEpoch(
            bookingInt(data['holdExpiresAtMillis']),
            isUtc: true));
  }
  Map<String, dynamic> toJson() {
    _bookingIdValue(bookingId);
    _bookingIdValue(requestId);
    bookingInt(holdExpiresAt.millisecondsSinceEpoch);
    if (status != BookingStatus.pendingHold ||
        holdExpiresAt.microsecondsSinceEpoch % 1000 != 0) {
      invalidBookingData();
    }
    return {
      'schemaVersion': 1,
      'requestId': requestId,
      'bookingId': bookingId,
      'status': 'pending_hold',
      'holdExpiresAtMillis': holdExpiresAt.millisecondsSinceEpoch
    };
  }
}

// Avoid shadowing the validator with BookingHold.bookingId.
String _bookingIdValue(dynamic value) => bookingId(value);

abstract interface class BookingRepository {
  Future<BookingHold> createHold(CreateBookingHoldRequest request);
}
