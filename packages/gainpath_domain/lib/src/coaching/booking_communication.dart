class SessionMessage {
  const SessionMessage(
      {required this.sequence,
      required this.senderRole,
      required this.text,
      required this.sentAtMillis});
  final int sequence, sentAtMillis;
  final String senderRole, text;
}

class SessionConversation {
  const SessionConversation(this.messages, {this.nextBeforeSequence});
  final List<SessionMessage> messages;
  final int? nextBeforeSequence;
}

abstract interface class BookingCommunicationRepository {
  Future<SessionConversation> load(String bookingId, {int? beforeSequence});
  Future<SessionConversation> send(
      String bookingId, String requestId, String text);
}
