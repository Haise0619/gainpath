import '../entities/chat_message.dart';
import '../../workout/entities/gym_equipment.dart';

/// Rough keyword routing standing in for real NLU (M6 prototype): an
/// equipment or workout-progress question gets a rich reply — an equipment
/// card or a small trend chart — instead of every answer being plain text.
/// A real build swaps this for the external LLM adapter behind the same call.
class ReplyGenerator {
  const ReplyGenerator();

  static const genericReply =
      'Good question. Focus on controlling the eccentric, keep your core '
      'braced, and add weight only once the movement feels repeatable.\n\n'
      'This is general educational guidance, not medical advice.';

  static const equipmentKeywords = ['equipment', 'machine', 'rack', 'bench', 'treadmill', 'cable', 'dumbbell'];
  static const progressKeywords = ['workout', 'progress', 'how am i doing', 'routine', 'improving', 'form score'];

  ChatMessage replyFor(
    String userText, {
    required List<GymEquipment> equipment,
    required List<int> postureTrend,
  }) {
    final q = userText.toLowerCase();

    if (equipmentKeywords.any(q.contains) && equipment.isNotEmpty) {
      final active = equipment.where((e) => e.isActive).toList();
      GymEquipment? match;
      for (final e in active) {
        if (q.contains(e.name.toLowerCase()) || q.contains(e.muscleGroup.toLowerCase())) {
          match = e;
          break;
        }
      }
      match ??= active.isNotEmpty ? active.first : equipment.first;
      return ChatMessage(
        'This one fits — tap the card for the full setup and safety guide.',
        false,
        attachment: EquipmentAttachment(match),
      );
    }

    if (progressKeywords.any(q.contains) && postureTrend.isNotEmpty) {
      final delta = postureTrend.last - postureTrend.first;
      return ChatMessage(
        'Here is how your form score has trended over your last ${postureTrend.length} sessions.',
        false,
        attachment: ProgressChartAttachment('Form score trend', 'pts', postureTrend, '${delta >= 0 ? '+' : ''}$delta pts'),
      );
    }

    return const ChatMessage(genericReply, false);
  }

  /// The on-demand progress audit (SD-M6.1): a volume-trend chart under the
  /// repository's narrative summary.
  ChatMessage progressAudit({required String summary, required List<int> volumeTrend}) {
    final delta = volumeTrend.isEmpty ? 0 : volumeTrend.last - volumeTrend.first;
    return ChatMessage(
      summary,
      false,
      attachment: ProgressChartAttachment('Training volume trend', 'kg', volumeTrend, '${delta >= 0 ? '+' : ''}$delta kg'),
    );
  }
}
