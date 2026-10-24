import 'package:test/test.dart';
import 'package:gainpath_domain/coaching.dart';

void main() {
  group('BookingReview contracts', () {
    test('SubmitBookingReviewRequest serializes and deserializes', () {
      final req = SubmitBookingReviewRequest(
        organizationId: 'org-1',
        bookingId: 'bk-1',
        requestId: 'req-1',
        stars: 5,
        reviewText: 'Excellent session, learned a lot!',
      );
      final json = req.toJson();
      final parsed = SubmitBookingReviewRequest.fromJson(json);
      expect(parsed.organizationId, 'org-1');
      expect(parsed.bookingId, 'bk-1');
      expect(parsed.stars, 5);
      expect(parsed.reviewText, 'Excellent session, learned a lot!');
    });

    test('SubmitBookingReviewRequest rejects invalid stars', () {
      expect(
        () => SubmitBookingReviewRequest(
          organizationId: 'org-1',
          bookingId: 'bk-1',
          requestId: 'req-1',
          stars: 6,
        ).toJson(),
        returnsNormally,
      );
      final invalidJson = {
        'schemaVersion': 1,
        'organizationId': 'org-1',
        'bookingId': 'bk-1',
        'requestId': 'req-1',
        'stars': 6,
      };
      expect(
        () => SubmitBookingReviewRequest.fromJson(invalidJson),
        throwsFormatException,
      );
    });

    test('BookingReviewResult parses valid response', () {
      final json = {
        'schemaVersion': 1,
        'bookingId': 'bk-1',
        'requestId': 'req-1',
        'stars': 5,
        'reviewedAtMillis': 1700000000000,
      };
      final res = BookingReviewResult.fromJson(
        json,
        expectedBookingId: 'bk-1',
        expectedRequestId: 'req-1',
      );
      expect(res.stars, 5);
      expect(res.bookingId, 'bk-1');
      expect(res.reviewedAtMillis, 1700000000000);
    });
  });
}
