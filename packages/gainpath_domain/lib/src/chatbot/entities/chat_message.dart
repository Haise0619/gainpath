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

class CoachAvailabilityAttachment extends ChatAttachment {
  CoachAvailabilityAttachment._(
      {required this.localDate,
      required this.timeZone,
      required this.expiresAtMillis,
      required this.items,
      required this.truncated,
      int Function()? clock})
      : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);
  final int Function() _clock;
  final String localDate, timeZone;
  final int expiresAtMillis;
  final List<AssistantCoachSlot> items;
  final bool truncated;
  bool get expired => _clock() >= expiresAtMillis;
  factory CoachAvailabilityAttachment.fromJson(Object? raw,
      {int Function()? clock}) {
    if (raw is! Map ||
        raw['schemaVersion'] != 1 ||
        raw['durationMinutes'] != 60 ||
        raw['localDate'] is! String ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw['localDate'] as String) ||
        DateTime.tryParse('${raw['localDate']}T00:00:00Z')
                ?.toIso8601String()
                .substring(0, 10) !=
            raw['localDate'] ||
        raw['timeZone'] is! String ||
        !RegExp(r'^[A-Za-z][A-Za-z0-9_+\-]*(/[A-Za-z0-9_+\-]+)*$')
            .hasMatch(raw['timeZone'] as String) ||
        raw['expiresAtMillis'] is! int ||
        (raw['expiresAtMillis'] as int) <= 0 ||
        raw['truncated'] is! bool ||
        raw['items'] is! List ||
        (raw['items'] as List).length > 20) {
      throw const FormatException('Invalid coaching availability');
    }
    final items = (raw['items'] as List).map((row) {
      if (row is! Map) throw const FormatException('Invalid coaching slot');
      for (final key in ['coachId', 'branchId']) {
        if (row[key] is! String ||
            !RegExp(r'^[\w-]{1,128}$').hasMatch(row[key] as String))
          throw const FormatException('Invalid coaching slot identity');
      }
      for (final key in ['name', 'branchName', 'startLabel', 'endLabel']) {
        if (row[key] is! String ||
            (row[key] as String).trim().isEmpty ||
            (row[key] as String).length > 160)
          throw const FormatException('Invalid coaching slot label');
      }
      if (row['startAtMillis'] is! int ||
          row['endAtMillis'] is! int ||
          (row['startAtMillis'] as int) <= 0 ||
          (row['endAtMillis'] as int) - (row['startAtMillis'] as int) !=
              3600000 ||
          (row['startAtMillis'] as int) % 1800000 != 0 ||
          row['amountMinor'] is! int ||
          (row['amountMinor'] as int) <= 0 ||
          (row['amountMinor'] as int) > 100000000 ||
          row['currency'] != 'MYR')
        throw const FormatException('Invalid coaching slot values');
      return AssistantCoachSlot._(
          Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(row)));
    }).toList();
    if (items
            .map((slot) =>
                '${slot.coachId}/${slot.data['branchId']}/${slot.data['startAtMillis']}')
            .toSet()
            .length !=
        items.length) throw const FormatException('Duplicate coaching slots');
    return CoachAvailabilityAttachment._(
        localDate: raw['localDate'] as String,
        timeZone: raw['timeZone'] as String,
        expiresAtMillis: raw['expiresAtMillis'] as int,
        items: List.unmodifiable(items),
        truncated: raw['truncated'] as bool,
        clock: clock);
  }
  BookingSuggestionAttachment suggestionFor(AssistantCoachSlot slot) {
    if (expired || !items.contains(slot))
      throw const FormatException('Coaching availability expired');
    final start = slot.data['startAtMillis'] as int;
    return BookingSuggestionAttachment.fromJson({
      'schemaVersion': 1,
      'coachId': slot.coachId,
      'coachName': slot.name,
      'branchId': slot.data['branchId'],
      'branchName': slot.data['branchName'],
      'localDate': localDate,
      'timeZone': timeZone,
      'startAtMillis': start,
      'endAtMillis': slot.data['endAtMillis'],
      'startLabel': slot.data['startLabel'],
      'endLabel': slot.data['endLabel'],
      'durationMinutes': 60,
      'amountMinor': slot.data['amountMinor'],
      'currency': 'MYR',
      'expiresAtMillis': expiresAtMillis < start ? expiresAtMillis : start,
      'requiresConfirmation': true
    });
  }
}

class AssistantCoachSlot {
  const AssistantCoachSlot._(this.data);
  final Map<String, dynamic> data;
  String get coachId => data['coachId'] as String;
  String get name => data['name'] as String;
  String get branchName => data['branchName'] as String;
  String get startLabel => data['startLabel'] as String;
  String get endLabel => data['endLabel'] as String;
  int get amountMinor => data['amountMinor'] as int;
}

class CoachDirectoryAttachment extends ChatAttachment {
  const CoachDirectoryAttachment(this.coaches);
  final List<AssistantCoachOption> coaches;
  factory CoachDirectoryAttachment.fromJson(Object? raw) {
    if (raw is! List || raw.length > 20) {
      throw const FormatException('Invalid coach suggestions');
    }
    final coaches = raw.map((row) {
      if (row is! Map ||
          row['coachId'] is! String ||
          !RegExp(r'^[\w-]{1,128}$').hasMatch(row['coachId'] as String) ||
          row['name'] is! String ||
          (row['name'] as String).trim().isEmpty ||
          (row['name'] as String).length > 160 ||
          row['branchName'] is! String ||
          (row['branchName'] as String).length > 160 ||
          row['amountMinor'] is! int ||
          (row['amountMinor'] as int) <= 0 ||
          (row['amountMinor'] as int) > 100000000 ||
          row['durationMinutes'] != 60 ||
          row['currency'] != 'MYR') {
        throw const FormatException('Invalid coach suggestion facts');
      }
      return AssistantCoachOption(
          coachId: row['coachId'] as String,
          name: row['name'] as String,
          branchName: row['branchName'] as String,
          amountMinor: row['amountMinor'] as int);
    }).toList();
    if (coaches.map((c) => c.coachId).toSet().length != coaches.length) {
      throw const FormatException('Duplicate coach suggestions');
    }
    return CoachDirectoryAttachment(List.unmodifiable(coaches));
  }
}

class AssistantCoachOption {
  const AssistantCoachOption(
      {required this.coachId,
      required this.name,
      required this.branchName,
      required this.amountMinor});
  final String coachId, name, branchName;
  final int amountMinor;
  int get durationMinutes => 60;
}

/// Facts assembled by authorized repositories, never parsed from model output.
class FitnessFactsAttachment extends ChatAttachment {
  const FitnessFactsAttachment(
      {required this.title,
      required this.subtitle,
      required this.facts,
      this.actions = const [],
      this.contentPreviews = const []});
  final String title, subtitle;
  final List<FitnessFact> facts;
  final List<FitnessFactAction> actions;
  final List<FitnessContentPreview> contentPreviews;
}

/// A cover already present on the current published content projection.
class FitnessContentPreview {
  const FitnessContentPreview(
      {required this.title, required this.imageUrl, required this.action});
  final String title, imageUrl;
  final FitnessFactAction action;
}

class FitnessFact {
  const FitnessFact(this.label, this.value);
  final String label, value;
}

enum FitnessFactTarget {
  progress,
  workoutReport,
  tutorial,
  routine,
  recommendation,
  membership,
  coaches
}

class FitnessFactAction {
  const FitnessFactAction(this.label, this.target, {this.id});
  final String label;
  final FitnessFactTarget target;

  /// A repository-owned opaque lookup key, not a model-generated route or URL.
  final String? id;
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
