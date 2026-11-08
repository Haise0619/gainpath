import 'package:gainpath_domain/coaching.dart' as legacy;
import 'package:gainpath_domain/gainpath_domain.dart' as live;

legacy.Booking persistedBookingPresentation(live.PersistedBookingRecord record,
    {String? coachName}) {
  final status = switch (record.rawStatus) {
    'confirmed' => legacy.BookingStatus.confirmed,
    'completed' => legacy.BookingStatus.completed,
    'cancelled' || 'expired' || 'refunded' => legacy.BookingStatus.cancelled,
    _ => legacy.BookingStatus.pending,
  };
  // Calendar components are the persisted organization-local date and labels.
  return legacy.Booking(
      id: record.bookingId,
      coachId: record.coachId,
      coachName: coachName ?? '-',
      memberName: record.memberDisplayName ?? '-',
      start: _calendarTime(record.localDate, record.startLabel),
      durationMin: record.durationMinutes,
      branch: record.branchId,
      status: status,
      rated: record.reviewStars != null,
      reviewStars: record.reviewStars,
      fee: record.feeMinor != null ? (record.feeMinor! / 100.0) : 0.0,
      cancellationReason: record.resolution == 'hold_expired'
          ? 'Hold expired'
          : record.resolution == 'coach_cancelled'
              ? (record.cancellationReason ?? 'Coach cancellation')
              : record.resolution == null
                  ? null
                  : 'Member cancellation');
}

enum MemberBookingPhase {
  upcoming,
  past,
  holdElapsed,
  completed,
  cancelled,
  expired,
  refunded
}

/// Server-clock presentation only. Never rewrites confirmation or settlement.
MemberBookingPhase memberBookingPhase(
    live.PersistedBookingRecord record, int serverNowMillis) {
  switch (record.status) {
    case live.BookingStatus.refunded:
      return MemberBookingPhase.refunded;
    case live.BookingStatus.completed:
      return MemberBookingPhase.completed;
    case live.BookingStatus.cancelled:
      return MemberBookingPhase.cancelled;
    case live.BookingStatus.expired:
      return MemberBookingPhase.expired;
    case live.BookingStatus.confirmed:
      return record.endAtMillis <= serverNowMillis
          ? MemberBookingPhase.past
          : MemberBookingPhase.upcoming;
    case live.BookingStatus.pendingHold:
      return record.holdExpiresAtMillis <= serverNowMillis
          ? MemberBookingPhase.holdElapsed
          : MemberBookingPhase.upcoming;
  }
}

String memberBookingStatus(
        live.PersistedBookingRecord record, int serverNowMillis) =>
    switch (memberBookingPhase(record, serverNowMillis)) {
      MemberBookingPhase.past => 'Session ended',
      MemberBookingPhase.holdElapsed => 'Hold time elapsed',
      MemberBookingPhase.completed => 'Completed',
      MemberBookingPhase.cancelled => 'Cancelled',
      MemberBookingPhase.expired => 'Expired',
      MemberBookingPhase.refunded => 'Refunded',
      MemberBookingPhase.upcoming =>
        record.status == live.BookingStatus.pendingHold
            ? 'Pending hold'
            : 'Confirmed',
    };

DateTime _calendarTime(String date, String label) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(label);
  return DateTime.parse('${date}T00:00:00').add(Duration(
      hours: int.tryParse(match?.group(1) ?? '') ?? 0,
      minutes: int.tryParse(match?.group(2) ?? '') ?? 0));
}
