import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/analytics/domain/local_member_progress_repository.dart';
import 'firebase_function_transport.dart';

typedef AssistantTransport = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> request);

/// Scoped callable adapter. Conversation history exists only in the caller Bloc.
class FirebaseChatRepository extends ChatRepository {
  FirebaseChatRepository(
      {required this.scope,
      required this.activeScope,
      AssistantTransport? transport,
      String? Function()? currentUid,
      this.progressLoader,
      FirebaseFunctions? functions})
      : _transport = transport ??
            ((data) async {
              final response = await firebaseCallable('fitnessAssistantCommand',
                      functions: functions,
                      options: HttpsCallableOptions(
                          timeout: const Duration(seconds: 55)))
                  .call<Map<String, dynamic>>(data);
              return Map<String, dynamic>.from(response.data);
            }),
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);
  final SessionScope scope;
  final SessionScope? Function() activeScope;
  final AssistantTransport _transport;
  final String? Function() _currentUid;
  final Future<LocalMemberProgressSnapshot> Function()? progressLoader;
  final List<String> _saved = [];
  bool _invalidated = false;
  Map<String, dynamic>? _bookingContext;
  int _contextVersion = 0;
  @override
  void clearSessionContext() {
    _contextVersion++;
    _bookingContext = null;
  }

  @override
  bool get isLive => true;
  @override
  List<ChatMessage> get chatSeed => const [];
  @override
  List<String> get savedAdvice => List.unmodifiable(_saved);
  @override
  List<FaqPrompt> get faqPrompts => const [];
  @override
  String buildProgressAuditReply() => throw const ChatFailure(
      'unavailable', 'Use the assistant to read your tracked progress.');
  void _check() {
    if (_invalidated ||
        activeScope() != scope ||
        _currentUid() != scope.userId) {
      _invalidated = true;
      clearSessionContext();
      _saved.clear();
      throw const ChatFailure('permission-denied',
          'Your account changed. Reopen the assistant after signing in.');
    }
  }

  Future<Map<String, dynamic>> _call(String action,
      [Map<String, dynamic> data = const {}]) async {
    _check();
    try {
      final response = await _transport(
          {'organizationId': scope.organizationId, 'action': action, ...data});
      _check();
      return response;
    } on ChatFailure {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      _check();
      final message = switch (e.code) {
        'resource-exhausted' =>
          'The assistant has reached its request limit. Wait a minute and retry.',
        'failed-precondition' =>
          'Review the current disclaimer or ask your administrator to check the AI configuration.',
        'permission-denied' ||
        'unauthenticated' =>
          'Your session or authorization changed. Please sign in again.',
        'invalid-argument' => 'Use a shorter fitness question and try again.',
        _ => 'The assistant is temporarily unavailable. Please retry.',
      };
      throw ChatFailure(e.code, message);
    } catch (_) {
      _check();
      throw const ChatFailure('unavailable',
          'The assistant is temporarily unavailable. Please retry.');
    }
  }

  @override
  Future<ChatSessionInfo> initialize() async {
    final data = await _call('bootstrap');
    try {
      final notice = Map<String, dynamic>.from(data['disclaimer'] as Map);
      final text = notice['text'] as String,
          revision = notice['revision'] as int;
      final bookmarks = List<String>.from(data['bookmarks'] as List);
      if (text.trim().isEmpty || revision < 1 || bookmarks.length > 50) {
        throw const FormatException();
      }
      _saved
        ..clear()
        ..addAll(bookmarks);
      return ChatSessionInfo(
          disclaimer: ChatDisclaimer(text: text, revision: revision),
          acknowledged: data['acknowledged'] == true);
    } catch (_) {
      throw const ChatFailure('unavailable',
          'The assistant configuration could not be loaded. Retry.');
    }
  }

  @override
  Future<void> acknowledgeDisclaimer(ChatDisclaimer notice) async {
    await _call('acknowledge', {'disclaimerRevision': notice.revision});
  }

  @override
  Future<ChatMessage> generateReply(
      {required String text, required List<ChatMessage> history}) async {
    final contextVersion = _contextVersion;
    Map<String, dynamic>? progress;
    if (progressLoader != null) {
      try {
        final snapshot = await progressLoader!();
        _check();
        if (snapshot.records.any((r) => r.scope != scope)) {
          throw const ChatFailure('permission-denied',
              'Progress belongs to a different account. Reopen the assistant.');
        }
        final cutoff =
            DateTime.now().toUtc().subtract(const Duration(days: 90));
        final records = snapshot.records
            .where((r) => r.scope == scope && !r.startedAt.isBefore(cutoff))
            .toList()
          ..sort((a, b) => b.endedAt.compareTo(a.endedAt));
        progress = {
          'sessions': records
              .take(30)
              .map((r) => {
                    'sessionId': r.sessionId,
                    'startedAtMillis': r.startedAt.millisecondsSinceEpoch,
                    'endedAtMillis': r.endedAt.millisecondsSinceEpoch,
                    'repetitions': r.repetitions,
                    'formScorePercent': r.formScorePercent
                  })
              .toList(),
          'truncated': records.length > 30
        };
      } on ChatFailure {
        rethrow;
      } catch (_) {
        progress = {'sessions': <Object>[], 'unavailable': true};
      }
    }
    final recent = history.where((m) => m.text.trim().isNotEmpty).toList();
    final data = await _call('reply', {
      'text': text,
      'history': recent
          .skip(recent.length > 12 ? recent.length - 12 : 0)
          .map((m) => {
                'role': m.fromUser ? 'user' : 'assistant',
                'text':
                    m.text.length > 2000 ? m.text.substring(0, 2000) : m.text
              })
          .toList(),
      if (progress != null) 'deviceProgress': progress,
      if (_bookingContext != null) 'bookingContext': _bookingContext
    });
    if (contextVersion == _contextVersion) {
      final value = data['bookingContext'];
      _bookingContext = null;
      if (value is Map &&
          value.length == 4 &&
          value.keys.every((k) => [
                'coachId',
                'localDate',
                'durationMinutes',
                'expiresAtMillis'
              ].contains(k)) &&
          value['coachId'] is String &&
          RegExp(r'^[\w-]{1,128}$').hasMatch(value['coachId'] as String) &&
          value['localDate'] is String &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$')
              .hasMatch(value['localDate'] as String) &&
          [30, 60].contains(value['durationMinutes']) &&
          value['expiresAtMillis'] is int) {
        _bookingContext = Map.unmodifiable(Map<String, dynamic>.from(value));
      }
    }
    final answer = data['text'], id = data['responseId'];
    if (answer is! String ||
        answer.trim().isEmpty ||
        answer.length > 6000 ||
        id is! String ||
        id.isEmpty) {
      throw const ChatFailure('unavailable',
          'The assistant returned no usable answer. Please retry.');
    }
    return ChatMessage(answer, false,
        id: id,
        attachment: data['bookingSuggestion'] == null
            ? null
            : BookingSuggestionAttachment.fromJson(
                Map<String, dynamic>.from(data['bookingSuggestion'] as Map)),
        sources: data['sources'] is List
            ? List<String>.from(data['sources'] as List)
            : const []);
  }

  Future<void> _bookmarkWrite = Future.value();
  @override
  Future<void> setBookmarked(String text, bool saved) {
    final operation = _bookmarkWrite.then((_) async {
      final response =
          await _call(saved ? 'bookmark' : 'removeBookmark', {'text': text});
      final raw = response['bookmarks'];
      if (raw is! List ||
          raw.length > 50 ||
          raw.any((v) => v is! String || v.length > 6000)) {
        throw const ChatFailure('unavailable',
            'Saved advice could not be verified. Please reload.');
      }
      _saved
        ..clear()
        ..addAll(List<String>.from(raw));
    });
    _bookmarkWrite = operation.catchError((Object _) {});
    return operation;
  }

  @override
  Future<void> rateAdvice(ChatMessage message, bool helpful) async {
    if (message.fromUser || message.id == null) {
      throw const ChatFailure('invalid-argument',
          'Only generated assistant responses can be rated.');
    }
    await _call('rate', {'responseId': message.id, 'helpful': helpful});
  }
}
