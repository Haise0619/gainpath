import 'package:gainpath_domain/coaching.dart' as legacy;
import 'package:gainpath_domain/gainpath_domain.dart' as live;

legacy.Booking persistedBookingPresentation(
    live.PersistedBookingRecord record) {
  final status = switch (record.rawStatus) {
    'confirmed' => legacy.BookingStatus.confirmed,
    'completed' => legacy.BookingStatus.completed,
    'cancelled' || 'expired' => legacy.BookingStatus.cancelled,
    _ => legacy.BookingStatus.pending,
  };
  // Calendar components are the persisted organization-local date and labels.
  return legacy.Booking(
      id: record.bookingId,
      coachId: record.coachId,
      coachName: '-',
      memberName: record.memberDisplayName ?? '-',
      start: _calendarTime(record.localDate, record.startLabel),
      durationMin: record.durationMinutes,
      branch: record.branchId,
      status: status,
      fee: 0,
      cancellationReason: record.resolution == 'hold_expired'
          ? 'Hold expired'
          : record.resolution == null
              ? null
              : 'Member cancellation');
}

DateTime _calendarTime(String date, String label) {
  final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(label);
  return DateTime.parse('${date}T00:00:00').add(Duration(
      hours: int.tryParse(match?.group(1) ?? '') ?? 0,
      minutes: int.tryParse(match?.group(2) ?? '') ?? 0));
}
