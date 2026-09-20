import 'core.dart';

enum BookingStatus { pendingHold, confirmed, cancelled, completed, refunded }

class CreateBookingHoldRequest {
  CreateBookingHoldRequest({
    required this.requestId,
    required this.organizationId,
    required this.branchId,
    required this.coachId,
    required DateTime startAt,
    required this.durationMinutes,
  }) : startAt = startAt.toUtc() {
    if (requestId.trim().isEmpty) {
      throw ArgumentError.value(requestId, 'requestId', 'must not be empty');
    }
    if (durationMinutes != 30 && durationMinutes != 60) {
      throw ArgumentError.value(
          durationMinutes, 'durationMinutes', 'must be 30 or 60');
    }
  }

  final String requestId;
  final OrganizationId organizationId;
  final BranchId branchId;
  final UserId coachId;
  final DateTime startAt;
  final int durationMinutes;
}

class BookingHold {
  const BookingHold({
    required this.bookingId,
    required this.requestId,
    required this.status,
    required this.holdExpiresAt,
  });

  final String bookingId;
  final String requestId;
  final BookingStatus status;
  final DateTime holdExpiresAt;
}

abstract interface class BookingRepository {
  Future<BookingHold> createHold(CreateBookingHoldRequest request);
}
