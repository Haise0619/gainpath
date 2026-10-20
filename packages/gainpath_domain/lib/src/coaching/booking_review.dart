import 'booking_wire_validation.dart' as wire;

class SubmitBookingReviewRequest {
  const SubmitBookingReviewRequest({
    required this.organizationId,
    required this.bookingId,
    required this.requestId,
    required this.stars,
    this.reviewText,
  });

  final String organizationId;
  final String bookingId;
  final String requestId;
  final int stars;
  final String? reviewText;

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'organizationId': organizationId,
        'bookingId': bookingId,
        'requestId': requestId,
        'stars': stars,
        if (reviewText != null && reviewText!.trim().isNotEmpty)
          'reviewText': reviewText!.trim(),
      };

  factory SubmitBookingReviewRequest.fromJson(Map<String, dynamic> data) {
    wire.bookingShape(data, [
      'schemaVersion',
      'organizationId',
      'bookingId',
      'requestId',
      'stars'
    ], [
      'reviewText'
    ]);
    wire.bookingVersion(data['schemaVersion']);
    final org = wire.bookingId(data['organizationId']);
    final id = wire.bookingId(data['bookingId']);
    final req = wire.bookingId(data['requestId']);
    final stars = wire.bookingInt(data['stars'], min: 1, max: 5);
    final text = data['reviewText'] == null
        ? null
        : wire.bookingText(data['reviewText'], max: 500, multiline: true);
    return SubmitBookingReviewRequest(
      organizationId: org,
      bookingId: id,
      requestId: req,
      stars: stars,
      reviewText: text,
    );
  }
}

class BookingReviewResult {
  const BookingReviewResult({
    required this.bookingId,
    required this.requestId,
    required this.stars,
    required this.reviewedAtMillis,
  });

  final String bookingId;
  final String requestId;
  final int stars;
  final int reviewedAtMillis;

  factory BookingReviewResult.fromJson(
    Map<String, dynamic> data, {
    required String expectedBookingId,
    required String expectedRequestId,
  }) {
    wire.bookingShape(data, [
      'schemaVersion',
      'bookingId',
      'requestId',
      'stars',
      'reviewedAtMillis',
    ]);
    wire.bookingVersion(data['schemaVersion']);
    if (wire.bookingId(data['bookingId']) != expectedBookingId ||
        wire.bookingId(data['requestId']) != expectedRequestId ||
        wire.bookingInt(data['stars'], min: 1, max: 5) < 1) {
      wire.invalidBookingData();
    }
    return BookingReviewResult(
      bookingId: expectedBookingId,
      requestId: expectedRequestId,
      stars: data['stars'],
      reviewedAtMillis: wire.bookingInt(data['reviewedAtMillis']),
    );
  }
}

abstract class BookingReviewRepository {
  Future<BookingReviewResult> submitReview({
    required String bookingId,
    required String requestId,
    required int stars,
    String? reviewText,
  });
}
