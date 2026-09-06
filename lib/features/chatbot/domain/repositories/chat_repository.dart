import 'package:gainpath/features/chatbot/domain/entities/chat_message.dart';
import 'package:gainpath/features/chatbot/domain/entities/faq_prompt.dart';

/// Data access contract for the chatbot feature. Implemented in-memory for the
/// prototype; a Firebase implementation will sit behind the same interface.
abstract class ChatRepository {
  List<ChatMessage> get chatSeed;
  List<String> get savedAdvice;
  List<FaqPrompt> get faqPrompts;
  String buildProgressAuditReply();
}
