/// Organization-scoped authoring only. This does not enable chatbot use or
/// record a member's acknowledgement of legal text.
abstract class ChatbotDisclaimerRepository {
  Future<ChatbotDisclaimerSnapshot> load();
  Future<ChatbotDisclaimerSnapshot> save(ChatbotDisclaimerSnapshot original,
      {required String text, required bool isActive});
}

class ChatbotDisclaimer {
  const ChatbotDisclaimer(
      {required this.text,
      required this.isActive,
      required this.revision,
      required this.updatedAt});
  final String text;
  final bool isActive;
  final int revision;
  final DateTime updatedAt;
}

abstract class ChatbotDisclaimerEditBaseline {}

class ChatbotDisclaimerSnapshot {
  const ChatbotDisclaimerSnapshot(
      {required this.current,
      required this.history,
      required this.editBaseline});
  final ChatbotDisclaimer? current;

  /// Most recent 20 immutable snapshots, including the current revision.
  final List<ChatbotDisclaimer> history;
  final ChatbotDisclaimerEditBaseline editBaseline;
}

class ChatbotDisclaimerConflict implements Exception {
  const ChatbotDisclaimerConflict();
}

class ChatbotDisclaimerSessionChanged implements Exception {
  const ChatbotDisclaimerSessionChanged();
}
