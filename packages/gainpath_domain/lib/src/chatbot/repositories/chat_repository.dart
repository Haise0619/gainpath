import '../entities/chat_message.dart';
import '../entities/faq_prompt.dart';

class ChatDisclaimer {
  const ChatDisclaimer({required this.text, required this.revision});
  final String text;
  final int revision;
}

class ChatSessionInfo {
  const ChatSessionInfo({required this.disclaimer, required this.acknowledged});
  final ChatDisclaimer disclaimer;
  final bool acknowledged;
}

class ChatFailure implements Exception {
  const ChatFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// Shared UI port. Active messages never belong in durable storage.
abstract class ChatRepository {
  List<ChatMessage> get chatSeed;
  List<String> get savedAdvice;
  List<FaqPrompt> get faqPrompts;
  String buildProgressAuditReply();
  bool get isLive => false;
  int _acknowledgedRevision = 0;
  static const mockDisclaimer = ChatDisclaimer(
      revision: 1,
      text:
          'The AI coach provides general educational fitness and nutrition information. '
          'It cannot diagnose injuries, prescribe treatment or replace a qualified professional. '
          'Do not rely on it in an emergency. AI can be wrong. '
          'Your questions and relevant tracked workout summaries are sent to the AI provider to generate answers. '
          'The active conversation stays in session memory; only advice you bookmark and helpfulness ratings are saved.');
  Future<ChatSessionInfo> initialize() async => ChatSessionInfo(
      disclaimer: mockDisclaimer,
      acknowledged: _acknowledgedRevision == mockDisclaimer.revision);
  Future<void> acknowledgeDisclaimer(ChatDisclaimer notice) async {
    _acknowledgedRevision = notice.revision;
  }

  Future<ChatMessage> generateReply(
          {required String text, required List<ChatMessage> history}) async =>
      throw const ChatFailure(
          'unavailable', 'The AI assistant is unavailable. Please retry.');
  Future<void> setBookmarked(String text, bool saved) async {
    if (saved && !savedAdvice.contains(text)) savedAdvice.add(text);
    if (!saved) savedAdvice.remove(text);
  }

  Future<void> rateAdvice(ChatMessage message, bool helpful) async {}
  void clearSessionContext() {}
}
