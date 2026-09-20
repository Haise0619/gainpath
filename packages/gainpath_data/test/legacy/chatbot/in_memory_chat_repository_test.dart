import 'package:test/test.dart';
import 'package:gainpath_data/src/chatbot/in_memory/in_memory_chat_repository.dart';

void main() {
  test('InMemoryChatRepository serves seed data', () {
    final repo = InMemoryChatRepository();
    expect(repo.chatSeed, isNotEmpty);
    expect(repo.savedAdvice, isNotEmpty);
    expect(repo.faqPrompts, isNotEmpty);
  });
}
