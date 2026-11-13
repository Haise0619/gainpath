import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/persisted_booking_presentation.dart';
import 'booking_history_coach_fix_test.dart' show bookingJson;

void main() {
  test('refund progress comes only from actual cleared payment evidence', () {
    PersistedBookingRecord row(Map<String, dynamic> extra) =>
        PersistedBookingRecord.fromJson({
          ...bookingJson('refund', DateTime.utc(2026, 10, 21, 2, 30),
              status: 'cancelled'),
          ...extra
        });
    expect(memberBookingRefundStatus(row({})), isNull);
    expect(
        memberBookingRefundStatus(
            row({'paymentStatus': 'cleared', 'refundReviewRequired': true})),
        'Refund under review');
    for (final entry in {
      'approved': 'Refund approved',
      'processing': 'Refund processing',
      'completed': 'Refunded',
      'uncertain': 'Refund needs attention',
      'failed': 'Refund needs attention',
      'rejected': 'Refund needs attention'
    }.entries) {
      expect(
          memberBookingRefundStatus(
              row({'paymentStatus': 'cleared', 'refundStatus': entry.key})),
          entry.value);
    }
  });
}
