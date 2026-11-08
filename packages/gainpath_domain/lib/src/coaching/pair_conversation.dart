class PairChatMessage {
  const PairChatMessage(
      {required this.id,
      required this.senderRole,
      required this.text,
      required this.sentAtMillis,
      this.sourceBookingId,
      this.sourceBookingLabel,
      this.orderKey});
  final String id, senderRole, text;
  final int sentAtMillis;
  final String? sourceBookingId;
  final String? sourceBookingLabel, orderKey;
}

class PairSessionContext {
  const PairSessionContext(
      {required this.bookingId,
      required this.kind,
      required this.startAtMillis,
      required this.endAtMillis,
      required this.timeZone,
      required this.durationMinutes,
      this.followUpUntilMillis,
      this.dateLabel,
      this.followUpLabel});
  final String bookingId, kind, timeZone;
  final int startAtMillis, endAtMillis, durationMinutes;
  final int? followUpUntilMillis;
  final String? dateLabel, followUpLabel;
}

class PairChatPage {
  const PairChatPage(
      {required this.conversationId,
      required this.peerId,
      required this.peerName,
      required this.serverNowMillis,
      required this.canSend,
      required this.reason,
      required this.messages,
      this.context,
      this.nextBefore});
  final String conversationId, peerId, peerName, reason;
  final int serverNowMillis;
  final bool canSend;
  final List<PairChatMessage> messages;
  final PairSessionContext? context;
  final String? nextBefore;
}

class PairChatSummary {
  const PairChatSummary(
      {required this.peerId,
      required this.name,
      required this.unreadCount,
      this.preview,
      this.updatedAtMillis});
  final String peerId, name;
  final int unreadCount;
  final String? preview;
  final int? updatedAtMillis;
}

class PairChatInboxPage {
  const PairChatInboxPage(this.conversations, {this.nextCursor});
  final List<PairChatSummary> conversations;
  final String? nextCursor;
}

abstract interface class PairConversationRepository {
  Future<PairChatPage> loadConversation(
      {String? bookingId,
      String? peerId,
      String? before,
      bool markRead = false});
  Future<PairChatPage> sendConversation(
      {required String peerId,
      required String requestId,
      required String text});
  Future<PairChatInboxPage> loadInbox({String? cursor});
}
