import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart' as legacy;
import 'package:gainpath_mobile/features/coaching/presentation/shared/coach_session_presentation.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/booking_status_clock.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'booking_history_coach_fix_test.dart' show bookingJson;

PersistedBookingRecord statusRecord(String status) {
  final raw = bookingJson('status-$status', DateTime.utc(2026, 11, 8, 6, 30),
      status: status)
    ..['memberDisplayName'] = 'Member $status';
  if (status == 'expired') {
    raw['resolution'] = 'hold_expired';
    raw['resolvedAtMillis'] = raw['holdExpiresAtMillis'];
  }
  return PersistedBookingRecord.fromJson(raw);
}

void main() {
  test(
      'confirmed stages use server start/end boundaries without mutating recorded status',
      () {
    final record = statusRecord('confirmed'),
        booking = persistedBookingPresentation(statusRecord('confirmed'));
    CoachSessionPhase phase(int now) =>
        coachSessionPhase(booking, record: record, serverNowMillis: now);
    expect(phase(record.startAtMillis - 1), CoachSessionPhase.confirmed);
    expect(phase(record.startAtMillis), CoachSessionPhase.inProgress);
    expect(phase(record.endAtMillis - 1), CoachSessionPhase.inProgress);
    expect(phase(record.endAtMillis), CoachSessionPhase.awaitingNotes);
    expect(phase(record.startAtMillis).canCancel, false);
    expect(phase(record.endAtMillis).canWriteNotes, true);
    expect(phase(record.endAtMillis).isHistory, true);
    expect(record.rawStatus, 'confirmed');
    expect(booking.status, legacy.BookingStatus.confirmed);
  });
  test(
      'terminal states win over time and expired/refunded never become cancelled',
      () {
    for (final status in ['completed', 'cancelled', 'expired', 'refunded']) {
      final r = statusRecord(status),
          b = persistedBookingPresentation(statusRecord(status));
      final phase =
          coachSessionPhase(b, record: r, serverNowMillis: r.startAtMillis + 1);
      expect(phase.name, status);
      expect(phase.isHistory, true);
      expect(phase.canCancel, false);
      expect(phase.canWriteNotes, false);
      expect(phase.canViewNotes, status == 'completed');
    }
  });
  test(
      'elapsed holds remain distinct from authoritative expiry and have no session actions',
      () {
    final r = statusRecord('pending_hold'),
        b = persistedBookingPresentation(statusRecord('pending_hold'));
    expect(
        coachSessionPhase(b,
            record: r, serverNowMillis: r.holdExpiresAtMillis - 1),
        CoachSessionPhase.pendingHold);
    final phase =
        coachSessionPhase(b, record: r, serverNowMillis: r.holdExpiresAtMillis);
    expect(phase, CoachSessionPhase.holdElapsed);
    expect(phase.label, 'Hold time elapsed');
    expect(phase.canOpenConversation, false);
    expect(phase.canViewFormHistory, false);
    expect(r.rawStatus, 'pending_hold');
  });
  testWidgets(
      'local server-clock boundaries update without a network poll and dispose cleanly',
      (t) async {
    var elapsed = 0;
    await t.pumpWidget(MaterialApp(
        home: BookingStatusClock(
            serverNowMillis: 1000,
            boundaryMillis: const [1050, 1100],
            elapsedMillis: () => elapsed,
            builder: (_, now) => Text('$now'))));
    expect(find.text('1000'), findsOneWidget);
    elapsed = 50;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('1050'), findsOneWidget);
    elapsed = 100;
    await t.pump(const Duration(milliseconds: 50));
    expect(find.text('1100'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
