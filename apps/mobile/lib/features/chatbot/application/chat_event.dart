part of 'chat_bloc.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();
  @override
  List<Object?> get props => [];
}

/// Member typed [text] and tapped send.
class MessageSent extends ChatEvent {
  const MessageSent(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// Member tapped an FAQ suggestion chip.
class PromptSent extends ChatEvent {
  const PromptSent(this.prompt);
  final FaqPrompt prompt;
  @override
  List<Object?> get props => [prompt.question];
}

/// Member tapped the progress-audit shortcut (SD-M6.1).
class ProgressAuditRequested extends ChatEvent {
  const ProgressAuditRequested();
}

/// Bookmark or un-bookmark an AI reply (SD-M6.1 / SD-M6.2).
class AdviceBookmarkToggled extends ChatEvent {
  const AdviceBookmarkToggled(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// Clear the conversation; bookmarks are kept.
class HistoryCleared extends ChatEvent {
  const HistoryCleared();
}
