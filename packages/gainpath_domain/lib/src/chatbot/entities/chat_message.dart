import '../../workout/entities/gym_equipment.dart';

/// A chatbot reply can carry a rich [attachment] alongside its [text] —
/// an equipment card with a photo, or a small progress chart — instead
/// of every answer being a plain text bubble.
class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatAttachment? attachment;
  final String? id;
  final List<String> sources;
  const ChatMessage(this.text, this.fromUser,
      {this.attachment, this.id, this.sources = const []});
}

sealed class ChatAttachment {
  const ChatAttachment();
}

/// Ephemeral navigation hint. Existing checkout revalidates every field.
class BookingSuggestionAttachment extends ChatAttachment {
  BookingSuggestionAttachment._(this.data);
  final Map<String, dynamic> data;
  factory BookingSuggestionAttachment.fromJson(Map<String, dynamic> raw) {
    const keys = [
      'schemaVersion',
      'coachId',
      'coachName',
      'branchId',
      'branchName',
      'localDate',
      'timeZone',
      'startAtMillis',
      'endAtMillis',
      'startLabel',
      'endLabel',
      'durationMinutes',
      'amountMinor',
      'currency',
      'expiresAtMillis',
      'requiresConfirmation'
    ];
    if (raw.length != keys.length ||
        raw.keys.any((k) => !keys.contains(k)) ||
        raw['schemaVersion'] != 1 ||
        raw['requiresConfirmation'] != true ||
        raw['currency'] != 'MYR') {
      throw const FormatException('Invalid booking suggestion');
    }
    for (final key in ['coachId', 'branchId']) {
      if (raw[key] is! String ||
          !RegExp(r'^[\w-]{1,128}$').hasMatch(raw[key] as String)) {
        throw const FormatException('Invalid booking identity');
      }
    }
    for (final key in [
      'coachName',
      'branchName',
      'startLabel',
      'endLabel',
      'timeZone',
      'localDate'
    ]) {
      if (raw[key] is! String ||
          (raw[key] as String).trim().isEmpty ||
          (raw[key] as String).length > 160) {
        throw const FormatException('Invalid booking label');
      }
    }
    for (final key in [
      'startAtMillis',
      'endAtMillis',
      'expiresAtMillis',
      'amountMinor'
    ]) {
      if (raw[key] is! int ||
          (raw[key] as int) <= 0 ||
          (raw[key] as int) > 8639999996400000) {
        throw const FormatException('Invalid booking value');
      }
    }
    if (![30, 60].contains(raw['durationMinutes']) ||
        (raw['startAtMillis'] as int) % 1800000 != 0 ||
        (raw['endAtMillis'] as int) - (raw['startAtMillis'] as int) !=
            (raw['durationMinutes'] as int) * 60000 ||
        (raw['expiresAtMillis'] as int) > (raw['startAtMillis'] as int) ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw['localDate'] as String) ||
        (raw['amountMinor'] as int) > 100000000 ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)*$')
            .hasMatch(raw['timeZone'] as String)) {
      throw const FormatException('Invalid booking interval');
    }
    if (DateTime.tryParse('${raw['localDate']}T00:00:00Z')
            ?.toIso8601String()
            .substring(0, 10) !=
        raw['localDate']) {
      throw const FormatException('Invalid booking date');
    }
    return BookingSuggestionAttachment._(Map.unmodifiable(raw));
  }
  String get coachId => data['coachId'] as String;
  String get branchId => data['branchId'] as String;
  String get localDate => data['localDate'] as String;
  int get startAtMillis => data['startAtMillis'] as int;
  int get durationMinutes => data['durationMinutes'] as int;
  bool get expired =>
      DateTime.now().millisecondsSinceEpoch >= (data['expiresAtMillis'] as int);
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
