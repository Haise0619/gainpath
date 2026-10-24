part of 'chat_bloc.dart';

class ChatState extends Equatable {
  const ChatState(
      {this.messages = const [],
      this.savedAdvice = const [],
      this.isReplying = false,
      this.isLoading = false,
      this.acknowledged = true,
      this.notice,
      this.error,
      this.ratings = const {},
      this.revision = 0});
  final List<ChatMessage> messages;
  final List<String> savedAdvice;
  final bool isReplying;
  final bool isLoading;
  final bool acknowledged;
  final ChatDisclaimer? notice;
  final String? error;
  final Map<String, bool> ratings;
  final int revision;
  bool get canSend => acknowledged && !isLoading && !isReplying;
  bool isBookmarked(ChatMessage m) =>
      !m.fromUser && savedAdvice.contains(m.text);
  @override
  List<Object?> get props => [
        messages,
        savedAdvice,
        isReplying,
        isLoading,
        acknowledged,
        notice,
        error,
        ratings,
        revision
      ];
}
