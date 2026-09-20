import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/workout.dart';

part 'chat_event.dart';
part 'chat_state.dart';

/// One conversation with the AI coach (SD-M6.1) plus the bookmark library it
/// feeds (SD-M6.2). Replies are generated locally by [ReplyGenerator] after a
/// short delay that stands in for the LLM round trip.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({
    required ChatRepository chat,
    required EquipmentRepository equipment,
    required AnalyticsRepository analytics,
    ReplyGenerator generator = const ReplyGenerator(),
    this.replyDelay = const Duration(milliseconds: 900),
  })  : _chat = chat,
        _equipment = equipment,
        _analytics = analytics,
        _generator = generator,
        super(ChatState(messages: List.unmodifiable(chat.chatSeed), savedAdvice: chat.savedAdvice)) {
    on<MessageSent>(_onMessageSent);
    on<PromptSent>(_onPromptSent);
    on<ProgressAuditRequested>(_onAuditRequested);
    on<AdviceBookmarkToggled>(_onBookmarkToggled);
    on<HistoryCleared>((_, emit) => emit(_with(messages: const [])));
  }

  final ChatRepository _chat;
  final EquipmentRepository _equipment;
  final AnalyticsRepository _analytics;
  final ReplyGenerator _generator;
  final Duration replyDelay;

  ChatState _with({List<ChatMessage>? messages, bool? isReplying}) => ChatState(
        messages: messages ?? state.messages,
        savedAdvice: _chat.savedAdvice,
        isReplying: isReplying ?? state.isReplying,
        revision: state.revision + 1,
      );

  Future<void> _deliver(String userText, ChatMessage reply, Emitter<ChatState> emit) async {
    emit(_with(messages: [...state.messages, ChatMessage(userText, true)], isReplying: true));
    await Future<void>.delayed(replyDelay);
    emit(_with(messages: [...state.messages, reply], isReplying: false));
  }

  Future<void> _onMessageSent(MessageSent e, Emitter<ChatState> emit) async {
    final text = e.text.trim();
    if (text.isEmpty) return;
    final reply = _generator.replyFor(text, equipment: _equipment.gymEquipment, postureTrend: _analytics.postureTrend);
    await _deliver(text, reply, emit);
  }

  Future<void> _onPromptSent(PromptSent e, Emitter<ChatState> emit) =>
      _deliver(e.prompt.question, ChatMessage(e.prompt.reply, false), emit);

  void _onAuditRequested(ProgressAuditRequested e, Emitter<ChatState> emit) {
    final reply = _generator.progressAudit(summary: _chat.buildProgressAuditReply(), volumeTrend: _analytics.volumeTrend);
    emit(_with(messages: [...state.messages, const ChatMessage('Give me a summary of my progress.', true), reply]));
  }

  void _onBookmarkToggled(AdviceBookmarkToggled e, Emitter<ChatState> emit) {
    if (_chat.savedAdvice.contains(e.text)) {
      _chat.savedAdvice.remove(e.text);
    } else {
      _chat.savedAdvice.add(e.text);
    }
    emit(_with());
  }
}
