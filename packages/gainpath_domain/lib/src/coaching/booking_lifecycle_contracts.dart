import '../coaching.dart' show BookingStatus;
import '../identity.dart' show SessionScope;
import 'booking_wire_validation.dart';

class CancelBookingHoldRequest {
  CancelBookingHoldRequest(
      {required this.organizationId,
      required this.bookingId,
      required this.requestId}) {
    for (final id in [organizationId, bookingId, requestId]) {
      _id(id);
    }
  }
  final String organizationId, bookingId, requestId;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'bookingId': bookingId,
        'requestId': requestId
      };
}

class CancelBookingHoldResult {
  const CancelBookingHoldResult._(this.bookingId, this.requestId, this.status,
      this.outcome, this.resolvedAtMillis);
  final String bookingId, requestId, outcome;
  final BookingStatus status;
  final int? resolvedAtMillis;
  factory CancelBookingHoldResult.fromJson(Map<String, dynamic> data,
      {required CancelBookingHoldRequest request}) {
    bookingShape(
        data,
        ['schemaVersion', 'bookingId', 'requestId', 'status', 'outcome'],
        ['resolvedAtMillis']);
    bookingVersion(data['schemaVersion']);
    final id = _id(data['bookingId']), requestId = _id(data['requestId']);
    final status = data['status'], outcome = data['outcome'];
    if (id != request.bookingId ||
        requestId != request.requestId ||
        !['cancelled', 'expired'].contains(status) ||
        !['cancelled', 'expired', 'already_closed'].contains(outcome) ||
        (outcome != 'already_closed' && outcome != status)) {
      invalidBookingData();
    }
    final resolved = data.containsKey('resolvedAtMillis')
        ? bookingInt(data['resolvedAtMillis'])
        : null;
    if (outcome != 'already_closed' && resolved == null) {
      invalidBookingData();
    }
    return CancelBookingHoldResult._(
        id,
        requestId,
        status == 'expired' ? BookingStatus.expired : BookingStatus.cancelled,
        outcome,
        resolved);
  }
}

abstract interface class BookingCancellationRepository {
  SessionScope get scope;
  Future<CancelBookingHoldResult> cancelHold(CancelBookingHoldRequest request);
}

String _id(dynamic value) => bookingId(value);
