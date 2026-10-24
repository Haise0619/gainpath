import '../identity.dart';
import 'booking_read_contracts.dart';
import 'booking_wire_validation.dart';

class MemberBookingChangeRequest {
  MemberBookingChangeRequest(
      {required this.booking,
      required this.action,
      required this.requestId,
      required String reason,
      this.newStartAtMillis})
      : reason = reason.trim() {
    bookingId(requestId);
    if (!['cancel', 'reschedule'].contains(action) ||
        booking.rawStatus != 'confirmed' ||
        this.reason.isEmpty ||
        this.reason.length > 500 ||
        (action == 'reschedule') != (newStartAtMillis != null))
      invalidBookingData();
    if (newStartAtMillis != null) {
      bookingInt(newStartAtMillis);
      if (newStartAtMillis! % bookingSlotMillis != 0) invalidBookingData();
    }
  }
  final PersistedBookingRecord booking;
  final String action, requestId, reason;
  final int? newStartAtMillis;
  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': booking.organizationId,
        'bookingId': booking.bookingId,
        'action': action,
        'requestId': requestId,
        'expectedStartAtMillis': booking.startAtMillis,
        'reason': reason,
        if (newStartAtMillis != null) 'newStartAtMillis': newStartAtMillis
      };
}

class MemberBookingChangeResult {
  MemberBookingChangeResult._(this.data);
  final Map<String, dynamic> data;
  bool get cancelled => data['status'] == 'cancelled';
  factory MemberBookingChangeResult.fromJson(
      Map<String, dynamic> data, MemberBookingChangeRequest request) {
    bookingShape(data, [
      'schemaVersion',
      'requestId',
      'bookingId',
      'action',
      'status',
      'startAtMillis',
      'endAtMillis',
      'localDate',
      'timeZone',
      'changedAtMillis',
      'refundReviewRequired'
    ]);
    bookingVersion(data['schemaVersion']);
    if (data['requestId'] != request.requestId ||
        data['bookingId'] != request.booking.bookingId ||
        data['action'] != request.action ||
        data['status'] !=
            (request.action == 'cancel' ? 'cancelled' : 'confirmed') ||
        data['refundReviewRequired'] != (request.action == 'cancel') ||
        data['timeZone'] != request.booking.timeZone) invalidBookingData();
    final start = bookingInt(data['startAtMillis']),
        end = bookingInt(data['endAtMillis']);
    bookingInterval(start, end, request.booking.durationMinutes);
    bookingDate(data['localDate']);
    bookingInt(data['changedAtMillis']);
    if (start != (request.newStartAtMillis ?? request.booking.startAtMillis))
      invalidBookingData();
    return MemberBookingChangeResult._(Map.unmodifiable(data));
  }
}

abstract interface class MemberBookingChangeRepository {
  SessionScope get scope;
  Future<BookingOptionsContext> loadReplacementOptions(
      PersistedBookingRecord booking,
      {String? localDate});
  Future<MemberBookingChangeResult> change(MemberBookingChangeRequest request);
}
