import '../../fakes/mock_data_session.dart';
import 'chatbot_seed.dart';
import 'package:gainpath_domain/chatbot.dart';

/// Session-scoped in-memory [ChatRepository] backed by [ChatbotSeed].
class InMemoryChatRepository implements ChatRepository {
  InMemoryChatRepository({MockDataSession? session})
      : _seed = (session ?? MockDataSession()).chatbot;

  final ChatbotSeed _seed;

  @override
  List<ChatMessage> get chatSeed => _seed.chatSeed;

  @override
  List<String> get savedAdvice => _seed.savedAdvice;

  @override
  List<FaqPrompt> get faqPrompts => _seed.faqPrompts;

  @override
  String buildProgressAuditReply() => _seed.buildProgressAuditReply();
}
