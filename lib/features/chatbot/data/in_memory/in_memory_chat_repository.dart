import 'package:gainpath/features/chatbot/data/in_memory/chatbot_seed.dart';
import 'package:gainpath/features/chatbot/domain/entities/chat_message.dart';
import 'package:gainpath/features/chatbot/domain/entities/faq_prompt.dart';
import 'package:gainpath/features/chatbot/domain/repositories/chat_repository.dart';

/// Session-scoped in-memory [ChatRepository] backed by [ChatbotSeed].
class InMemoryChatRepository implements ChatRepository {
  @override
  List<ChatMessage> get chatSeed => ChatbotSeed.chatSeed;

  @override
  List<String> get savedAdvice => ChatbotSeed.savedAdvice;

  @override
  List<FaqPrompt> get faqPrompts => ChatbotSeed.faqPrompts;

  @override
  String buildProgressAuditReply() => ChatbotSeed.buildProgressAuditReply();
}
