import 'booking_wire_validation.dart' as wire;

class CancelAssignedBookingRequest {
  const CancelAssignedBookingRequest({
    required this.organizationId,
    required this.bookingId,
    required this.requestId,
    required this.reason,
  });

  final String organizationId;
  final String bookingId;
  final String requestId;
  final String reason;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'bookingId': bookingId,
        'requestId': requestId,
        'reason': reason,
      };

  factory CancelAssignedBookingRequest.fromJson(Map<String, dynamic> data) {
    wire.bookingShape(data,
        ['schemaVersion', 'organizationId', 'bookingId', 'requestId', 'reason']);
    wire.bookingVersion(data['schemaVersion']);
    final org = wire.bookingId(data['organizationId']);
    final id = wire.bookingId(data['bookingId']);
    final req = wire.bookingId(data['requestId']);
    final r = wire.bookingText(data['reason'], max: 500, multiline: true);
    return CancelAssignedBookingRequest(
      organizationId: org,
      bookingId: id,
      requestId: req,
      reason: r,
    );
  }
}

class CancelAssignedBookingResult {
  const CancelAssignedBookingResult({
    required this.bookingId,
    required this.requestId,
    required this.status,
    required this.outcome,
    required this.cancelledAtMillis,
    required this.refundReviewRequired,
  });

  final String bookingId;
  final String requestId;
  final String status;
  final String outcome;
  final int cancelledAtMillis;
  final bool refundReviewRequired;

  factory CancelAssignedBookingResult.fromJson(
    Map<String, dynamic> data, {
    required String expectedBookingId,
    required String expectedRequestId,
  }) {
    wire.bookingShape(data, [
      'schemaVersion',
      'bookingId',
      'requestId',
      'status',
      'outcome',
      'cancelledAtMillis',
      'refundReviewRequired',
    ]);
    wire.bookingVersion(data['schemaVersion']);
    if (wire.bookingId(data['bookingId']) != expectedBookingId ||
        wire.bookingId(data['requestId']) != expectedRequestId ||
        data['status'] != 'cancelled' ||
        !['cancelled', 'already_cancelled'].contains(data['outcome']) ||
        data['refundReviewRequired'] is! bool) {
      wire.invalidBookingData();
    }
    return CancelAssignedBookingResult(
      bookingId: expectedBookingId,
      requestId: expectedRequestId,
      status: 'cancelled',
      outcome: data['outcome'],
      cancelledAtMillis: wire.bookingInt(data['cancelledAtMillis']),
      refundReviewRequired: data['refundReviewRequired'],
    );
  }
}

abstract class CoachBookingCancellationRepository {
  Future<CancelAssignedBookingResult> cancel({
    required String bookingId,
    required String requestId,
    required String reason,
  });
}
