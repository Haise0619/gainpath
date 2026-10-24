import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/workout.dart';
part 'chat_event.dart';
part 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(
      {required ChatRepository chat,
      EquipmentRepository? equipment,
      AnalyticsRepository? analytics,
      ReplyGenerator generator = const ReplyGenerator(),
      this.replyDelay = const Duration(milliseconds: 900)})
      : _chat = chat,
        _equipment = equipment,
        _analytics = analytics,
        _generator = generator,
        super(ChatState(
            messages: List.unmodifiable(chat.chatSeed),
            savedAdvice: List.unmodifiable(chat.savedAdvice),
            isLoading: chat.isLive,
            acknowledged: !chat.isLive)) {
    on<ChatStarted>(_initialize);
    on<DisclaimerAcknowledged>(_acknowledge);
    on<MessageSent>((e, emit) => _send(e.text, emit));
    on<PromptSent>((e, emit) => _send(e.prompt.question, emit,
        mockReply: ChatMessage(e.prompt.reply, false)));
    on<ProgressAuditRequested>((e, emit) => _send(
        'Give me a summary of my progress.', emit,
        mockReply: _chat.isLive
            ? null
            : _generator.progressAudit(
                summary: _chat.buildProgressAuditReply(),
                volumeTrend: _analytics?.volumeTrend ?? const [])));
    on<AdviceBookmarkToggled>(_bookmark);
    on<AdviceRated>(_rate);
    on<HistoryCleared>((_, emit) {
      _chat.clearSessionContext();
      _generation++;
      _historyVersion++;
      _lastText = null;
      _failedAction = null;
      emit(_with(
          messages: const [],
          isReplying: false,
          ratings: const {},
          clearError: true));
    });
    on<ChatRetried>((_, emit) async {
      if (_failedAction != null && state.acknowledged) {
        final action = _failedAction!;
        _failedAction = null;
        add(action);
        return;
      }
      if (!state.acknowledged || state.notice == null && _chat.isLive) {
        await _initialize(const ChatStarted(), emit);
      } else if (_lastText != null) {
        await _send(_lastText!, emit);
      }
    });
    if (chat.isLive) add(const ChatStarted());
  }
  final ChatRepository _chat;
  final EquipmentRepository? _equipment;
  final AnalyticsRepository? _analytics;
  final ReplyGenerator _generator;
  final Duration replyDelay;
  int _generation = 0;
  int _historyVersion = 0;
  String? _lastText;
  ChatEvent? _failedAction;
  final Set<String> _saving = {};
  final Set<String> _rating = {};
  @override
  Future<void> close() {
    _generation++;
    _chat.clearSessionContext();
    return super.close();
  }

  ChatState _with(
          {List<ChatMessage>? messages,
          bool? isReplying,
          bool? isLoading,
          bool? acknowledged,
          ChatDisclaimer? notice,
          String? error,
          bool clearError = false,
          Map<String, bool>? ratings}) =>
      ChatState(
          messages: messages ?? state.messages,
          savedAdvice: List.unmodifiable(_chat.savedAdvice),
          isReplying: isReplying ?? state.isReplying,
          isLoading: isLoading ?? state.isLoading,
          acknowledged: acknowledged ?? state.acknowledged,
          notice: notice ?? state.notice,
          error: clearError ? null : error ?? state.error,
          ratings: ratings ?? state.ratings,
          revision: state.revision + 1);

  String _error(Object error) => error is ChatFailure
      ? error.message
      : 'Unable to complete this request. Please try again.';
  Future<void> _initialize(ChatStarted e, Emitter<ChatState> emit) async {
    if (state.isLoading && state.revision > 0) return;
    emit(_with(isLoading: true, clearError: true));
    try {
      final session = await _chat.initialize();
      if (emit.isDone) return;
      emit(_with(
          isLoading: false,
          notice: session.disclaimer,
          acknowledged: session.acknowledged));
    } catch (error) {
      if (!emit.isDone) {
        emit(
            _with(isLoading: false, acknowledged: false, error: _error(error)));
      }
    }
  }

  Future<void> _acknowledge(
      DisclaimerAcknowledged e, Emitter<ChatState> emit) async {
    final notice = state.notice;
    if (notice == null || state.isLoading) return;
    emit(_with(isLoading: true, clearError: true));
    try {
      await _chat.acknowledgeDisclaimer(notice);
      if (!emit.isDone) {
        emit(_with(isLoading: false, acknowledged: true));
        if (_failedAction != null) add(const ChatRetried());
      }
    } catch (error) {
      if (!emit.isDone) emit(_with(isLoading: false, error: _error(error)));
    }
  }

  Future<void> _send(String value, Emitter<ChatState> emit,
      {ChatMessage? mockReply}) async {
    final text = value.trim();
    if (text.isEmpty || !state.canSend) return;
    final generation = ++_generation;
    final history = state.messages.length > 12
        ? state.messages.sublist(state.messages.length - 12)
        : state.messages;
    _lastText = text;
    emit(_with(
        messages: [...state.messages, ChatMessage(text, true)],
        isReplying: true,
        clearError: true));
    try {
      final ChatMessage reply;
      if (_chat.isLive) {
        reply = await _chat.generateReply(
            text: text, history: List.unmodifiable(history));
      } else {
        reply = mockReply ??
            _generator.replyFor(text,
                equipment: _equipment?.gymEquipment ?? const [],
                postureTrend: _analytics?.postureTrend ?? const []);
        await Future<void>.delayed(replyDelay);
      }
      if (emit.isDone || generation != _generation) return;
      _lastText = null;
      emit(_with(messages: [...state.messages, reply], isReplying: false));
    } catch (error) {
      if (!emit.isDone && generation == _generation) {
        emit(_with(
            messages: state.messages.sublist(0, state.messages.length - 1),
            isReplying: false,
            error: _error(error)));
        if (error is ChatFailure && error.code == 'failed-precondition') {
          emit(_with(acknowledged: false));
          await _initialize(const ChatStarted(), emit);
        }
      }
    }
  }

  Future<void> _bookmark(
      AdviceBookmarkToggled e, Emitter<ChatState> emit) async {
    if (!state.acknowledged || !_saving.add(e.text)) return;
    try {
      await _chat.setBookmarked(e.text, !_chat.savedAdvice.contains(e.text));
      if (!emit.isDone) emit(_with(clearError: true));
    } catch (error) {
      _failedAction = e;
      if (!emit.isDone) {
        emit(_with(error: _error(error)));
        if (error is ChatFailure && error.code == 'failed-precondition') {
          emit(_with(acknowledged: false));
          await _initialize(const ChatStarted(), emit);
        }
      }
    } finally {
      _saving.remove(e.text);
    }
  }

  Future<void> _rate(AdviceRated e, Emitter<ChatState> emit) async {
    if (!state.acknowledged || e.message.fromUser) return;
    final key = e.message.id ?? e.message.text;
    if (!_rating.add(key)) return;
    final historyVersion = _historyVersion;
    try {
      await _chat.rateAdvice(e.message, e.helpful);
      if (!emit.isDone && historyVersion == _historyVersion) {
        emit(_with(
            ratings: {...state.ratings, key: e.helpful}, clearError: true));
      }
    } catch (error) {
      _failedAction = e;
      if (!emit.isDone) {
        emit(_with(error: _error(error)));
        if (error is ChatFailure && error.code == 'failed-precondition') {
          emit(_with(acknowledged: false));
          await _initialize(const ChatStarted(), emit);
        }
      }
    } finally {
      _rating.remove(key);
    }
  }
}
