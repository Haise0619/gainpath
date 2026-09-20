part of 'chat_bloc.dart';

class ChatState extends Equatable {
  const ChatState({
    this.messages = const [],
    this.savedAdvice = const [],
    this.isReplying = false,
    this.revision = 0,
  });

  final List<ChatMessage> messages;

  /// The live bookmark list shared with the repository; [revision] bumps on
  /// every toggle so listeners rebuild even though the instance is reused.
  final List<String> savedAdvice;
  final bool isReplying;
  final int revision;

  bool isBookmarked(ChatMessage m) => !m.fromUser && savedAdvice.contains(m.text);

  @override
  List<Object?> get props => [messages, savedAdvice, isReplying, revision];
}
