/// Authored instructional content. It grants no tracking or reward capability.
class ExerciseTutorialStep {
  const ExerciseTutorialStep(
      {required this.title, required this.description, this.imageUrl = ''});
  final String title, description, imageUrl;
  Map<String, Object?> toJson() => {
        'title': title.trim(),
        'description': description.trim(),
        'imageUrl': imageUrl.trim(),
      };
}

class ExerciseTutorialDetails {
  const ExerciseTutorialDetails(
      {this.description = '',
      this.coverImageUrl = '',
      this.difficulty = 'Beginner',
      this.equipment = '',
      this.steps = const []});
  static const maxSteps = 12;
  static const difficulties = ['Beginner', 'Intermediate', 'Advanced'];
  final String description, coverImageUrl, difficulty, equipment;
  final List<ExerciseTutorialStep> steps;

  /// Defaults also allow an existing optional value to be explicitly cleared.
  Map<String, Object?> toJson() => {
        'description': description.trim(),
        'coverImageUrl': coverImageUrl.trim(),
        'difficulty': difficulty,
        'equipment': equipment.trim(),
        'tutorialSteps': steps.map((s) => s.toJson()).toList(growable: false),
      };

  factory ExerciseTutorialDetails.fromJson(Map<String, dynamic> data,
      {bool tolerateInvalidImages = false}) {
    String text(Map<dynamic, dynamic> source, String key, int max,
        {String fallback = '', bool required = false}) {
      final value = source[key] ?? fallback;
      if (value is! String ||
          value.trim().length > max ||
          (required && value.trim().isEmpty)) {
        throw const FormatException('Exercise tutorial details are invalid.');
      }
      return value.trim();
    }

    String image(Map<dynamic, dynamic> source, String key) {
      final value = text(source, key, 2048);
      if (value.isEmpty || exerciseImageUri(value) != null) return value;
      if (tolerateInvalidImages) return '';
      throw const FormatException('Use an HTTPS image URL.');
    }

    final difficulty = text(data, 'difficulty', 20, fallback: 'Beginner');
    final rawSteps = data['tutorialSteps'] ?? const [];
    if (!difficulties.contains(difficulty) ||
        rawSteps is! List ||
        rawSteps.length > maxSteps) {
      throw const FormatException('Exercise tutorial details are invalid.');
    }
    final steps = rawSteps.map((raw) {
      if (raw is! Map ||
          raw.keys.any((key) =>
              !const ['title', 'description', 'imageUrl'].contains(key))) {
        throw const FormatException('Exercise tutorial step is invalid.');
      }
      return ExerciseTutorialStep(
          title: text(raw, 'title', 80, required: true),
          description: text(raw, 'description', 1200, required: true),
          imageUrl: image(raw, 'imageUrl'));
    }).toList(growable: false);
    return ExerciseTutorialDetails(
        description: text(data, 'description', 2000),
        coverImageUrl: image(data, 'coverImageUrl'),
        difficulty: difficulty,
        equipment: text(data, 'equipment', 300),
        steps: List.unmodifiable(steps));
  }
}

/// HTTPS images may use signed storage URLs without an extension.
Uri? exerciseImageUri(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty ||
      text.length > 2048 ||
      !text.startsWith('https://') ||
      RegExp(r'[\x00-\x20\x7f\\#]').hasMatch(text)) {
    return null;
  }
  final uri = Uri.tryParse(text);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.hasFragment ||
      uri.port < 1 ||
      uri.port > 65535) {
    return null;
  }
  return uri;
}
