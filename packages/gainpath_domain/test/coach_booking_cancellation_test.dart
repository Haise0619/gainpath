import 'package:gainpath_domain/coaching.dart'
    show CancelAssignedBookingRequest, CancelAssignedBookingResult;
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:test/test.dart';

void main() {
  group('CoachBookingCancellation contracts', () {
    test('CancelAssignedBookingRequest serializes and deserializes cleanly', () {
      final request = const CancelAssignedBookingRequest(
        organizationId: 'org-1',
        bookingId: 'booking-1',
        requestId: 'req-1',
        reason: 'Personal emergency.\nCannot conduct session.',
      );

      final json = request.toJson();
      expect(json, {
        'schemaVersion': 1,
        'organizationId': 'org-1',
        'bookingId': 'booking-1',
        'requestId': 'req-1',
        'reason': 'Personal emergency.\nCannot conduct session.',
      });

      final parsed = CancelAssignedBookingRequest.fromJson(json);
      expect(parsed.organizationId, 'org-1');
      expect(parsed.bookingId, 'booking-1');
      expect(parsed.requestId, 'req-1');
      expect(parsed.reason, 'Personal emergency.\nCannot conduct session.');
    });

    test('CancelAssignedBookingRequest rejects empty or oversized reasons', () {
      expect(
        () => CancelAssignedBookingRequest.fromJson({
          'schemaVersion': 1,
          'organizationId': 'org-1',
          'bookingId': 'booking-1',
          'requestId': 'req-1',
          'reason': '   ',
        }),
        throwsFormatException,
      );

      expect(
        () => CancelAssignedBookingRequest.fromJson({
          'schemaVersion': 1,
          'organizationId': 'org-1',
          'bookingId': 'booking-1',
          'requestId': 'req-1',
          'reason': 'A' * 501,
        }),
        throwsFormatException,
      );
    });

    test('CancelAssignedBookingResult parses valid server response', () {
      final json = {
        'schemaVersion': 1,
        'bookingId': 'booking-1',
        'requestId': 'req-1',
        'status': 'cancelled',
        'outcome': 'cancelled',
        'cancelledAtMillis': 1792400000000,
        'refundReviewRequired': true,
      };

      final result = CancelAssignedBookingResult.fromJson(
        json,
        expectedBookingId: 'booking-1',
        expectedRequestId: 'req-1',
      );

      expect(result.bookingId, 'booking-1');
      expect(result.requestId, 'req-1');
      expect(result.status, 'cancelled');
      expect(result.outcome, 'cancelled');
      expect(result.cancelledAtMillis, 1792400000000);
      expect(result.refundReviewRequired, isTrue);
    });

    test('PersistedBookingRecord parses coach_cancelled resolution with reason', () {
      final json = {
        'schemaVersion': 1,
        'organizationId': 'org-1',
        'bookingId': 'booking-1',
        'memberId': 'member-1',
        'coachId': 'coach-1',
        'branchId': 'branch-1',
        'requestId': 'req-1',
        'startAtMillis': 1893492000000,
        'endAtMillis': 1893495600000,
        'durationMinutes': 60,
        'status': 'cancelled',
        'holdExpiresAtMillis': 1893489300000,
        'localDate': '2030-01-01',
        'timeZone': 'UTC',
        'policyVersion': 'policy-1',
        'createdAtMillis': 1893488400000,
        'resolvedAtMillis': 1893490000000,
        'resolution': 'coach_cancelled',
        'cancellationReason': 'Emergency situation',
        'cancelledBy': 'coach-1',
        'startLabel': '10:00 +00:00',
        'endLabel': '11:00 +00:00',
        'expiryLabel': '09:15 +00:00',
      };

      final record = PersistedBookingRecord.fromJson(json);
      expect(record.status, BookingStatus.cancelled);
      expect(record.resolution, 'coach_cancelled');
      expect(record.cancellationReason, 'Emergency situation');
      expect(record.cancelledBy, 'coach-1');
      expect(record.resolvedAtMillis, 1893490000000);
    });

    test('Legacy client DTO reads coach-cancelled record omitting details without throwing', () {
      final legacyJson = {
        'schemaVersion': 1,
        'organizationId': 'org-1',
        'bookingId': 'booking-1',
        'memberId': 'member-1',
        'coachId': 'coach-1',
        'branchId': 'branch-1',
        'requestId': 'req-1',
        'startAtMillis': 1893492000000,
        'endAtMillis': 1893495600000,
        'durationMinutes': 60,
        'status': 'cancelled',
        'holdExpiresAtMillis': 1893489300000,
        'localDate': '2030-01-01',
        'timeZone': 'UTC',
        'policyVersion': 'policy-1',
        'createdAtMillis': 1893488400000,
        'startLabel': '10:00 +00:00',
        'endLabel': '11:00 +00:00',
        'expiryLabel': '09:15 +00:00',
      };

      final record = PersistedBookingRecord.fromJson(legacyJson);
      expect(record.status, BookingStatus.cancelled);
      expect(record.resolution, isNull);
      expect(record.resolvedAtMillis, isNull);
    });
  });
}
