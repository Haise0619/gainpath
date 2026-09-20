import '../enums/booking_status.dart';

/// Embedded chat message for the member↔coach thread on a single booking,
/// mirroring the BookingMessage subcollection in the data dictionary
/// (senderRole, text, sentAt) without a backend behind it.
class BookingMessage {
  final String senderRole;
  final String text;
  final DateTime sentAt;
  const BookingMessage(this.senderRole, this.text, this.sentAt);
}

/// [start], [status], [notes], [rated], and [cancellationReason] are
/// mutable — rescheduling, cancelling, rating, and a coach publishing
/// consultation notes all mutate a booking in place rather than
/// replacing it in the list, the same pattern already used for
/// `savedAdvice` in the chatbot module.
class Booking {
  final String id;
  final String coachId;
  final String coachName;
  final String memberName;
  DateTime start;
  final int durationMin;
  final String branch;
  BookingStatus status;
  final double fee;
  String? notes;
  bool rated;
  String? cancellationReason;
  final List<BookingMessage> messages;
  Booking({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.memberName,
    required this.start,
    this.durationMin = 60,
    required this.branch,
    required this.status,
    required this.fee,
    this.notes,
    this.rated = false,
    this.cancellationReason,
    List<BookingMessage>? messages,
  }) : messages = messages ?? [];
}
