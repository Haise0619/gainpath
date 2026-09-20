import '../../workout/entities/gym_equipment.dart';

/// A chatbot reply can carry a rich [attachment] alongside its [text] —
/// an equipment card with a photo, or a small progress chart — instead
/// of every answer being a plain text bubble.
class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatAttachment? attachment;
  const ChatMessage(this.text, this.fromUser, {this.attachment});
}

sealed class ChatAttachment {
  const ChatAttachment();
}

/// A single piece of gym equipment surfaced inline, for questions like
/// "what machine works my chest?" — tapping it opens the full
/// `EquipmentDetailScreen` guide.
class EquipmentAttachment extends ChatAttachment {
  final GymEquipment equipment;
  const EquipmentAttachment(this.equipment);
}

/// A small trend chart surfaced inline, for questions like "how's my
/// workout going?" — reuses the same session-indexed series the
/// Progress tab charts are built from.
class ProgressChartAttachment extends ChatAttachment {
  final String title;
  final String unit;
  final List<int> values;
  final String delta;
  const ProgressChartAttachment(this.title, this.unit, this.values, this.delta);
}
