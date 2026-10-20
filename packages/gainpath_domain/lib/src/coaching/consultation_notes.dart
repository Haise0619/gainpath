import 'booking_wire_validation.dart' as wire;

class ConsultationNotesResult {
  const ConsultationNotesResult(
      {required this.bookingId,
      required this.status,
      required this.canPublish,
      this.text,
      this.publishedAtMillis});
  final String bookingId, status;
  final bool canPublish;
  final String? text;
  final int? publishedAtMillis;
  factory ConsultationNotesResult.fromJson(Map<String, dynamic> data,
      {required String expectedBookingId}) {
    wire.bookingShape(
        data, ['schemaVersion', 'bookingId', 'status', 'canPublish', 'note']);
    wire.bookingVersion(data['schemaVersion']);
    if (wire.bookingId(data['bookingId']) != expectedBookingId ||
        ![
          'pending_hold',
          'confirmed',
          'cancelled',
          'expired',
          'completed',
          'refunded'
        ].contains(data['status']) ||
        data['canPublish'] is! bool) {
      wire.invalidBookingData();
    }
    String? text;
    int? published;
    if (data['note'] != null) {
      final note = Map<String, dynamic>.from(data['note'] as Map);
      wire.bookingShape(note, ['text', 'publishedAtMillis']);
      text = wire.bookingText(note['text'], max: 5000, multiline: true);
      published = wire.bookingInt(note['publishedAtMillis']);
      if (data['status'] != 'completed' || data['canPublish'] == true) {
        wire.invalidBookingData();
      }
    } else if (data['canPublish'] == true && data['status'] != 'confirmed') {
      wire.invalidBookingData();
    }
    return ConsultationNotesResult(
        bookingId: expectedBookingId,
        status: data['status'],
        canPublish: data['canPublish'],
        text: text,
        publishedAtMillis: published);
  }
}

abstract class ConsultationNotesRepository {
  Future<ConsultationNotesResult> load(String bookingId);
  Future<ConsultationNotesResult> publish(
      String bookingId, String requestId, String text);
}
