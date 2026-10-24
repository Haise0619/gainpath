import '../entities/gym_equipment.dart';

/// Structured prediction returned by the Vision AI model.
class EquipmentRecognitionResult {
  const EquipmentRecognitionResult({
    required this.detectedEquipment,
    this.aliases = const [],
    this.category,
    this.confidence = 0.0,
    this.isGymEquipment = true,
    this.rawResponse,
  });

  final String detectedEquipment;
  final List<String> aliases;
  final String? category;
  final double confidence;
  final bool isGymEquipment;
  final String? rawResponse;

  factory EquipmentRecognitionResult.fromJson(Map<String, dynamic> json) {
    final detected = json['detectedEquipment'] is String
        ? (json['detectedEquipment'] as String).trim()
        : '';
    final rawAliases = json['aliases'];
    final aliases = <String>[];
    if (rawAliases is List) {
      for (final a in rawAliases) {
        if (a is String && a.trim().isNotEmpty) {
          aliases.add(a.trim());
        }
      }
    }
    final rawConf = json['confidence'];
    final confidence = (rawConf is num) ? rawConf.toDouble() : 0.0;
    final isGym = json['isGymEquipment'] == true;
    final category =
        json['category'] is String ? json['category'] as String : null;

    return EquipmentRecognitionResult(
      detectedEquipment: detected,
      aliases: aliases,
      category: category,
      confidence: confidence,
      isGymEquipment: isGym,
      rawResponse:
          json['rawResponse'] is String ? json['rawResponse'] as String : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'detectedEquipment': detectedEquipment,
        'aliases': aliases,
        if (category != null) 'category': category,
        'confidence': confidence,
        'isGymEquipment': isGymEquipment,
        if (rawResponse != null) 'rawResponse': rawResponse,
      };
}

/// Abstract contract for a Vision AI classifier.
abstract interface class EquipmentVisionClassifier {
  Future<EquipmentRecognitionResult> identifyEquipment(
    List<int> imageBytes, {
    String mimeType = 'image/jpeg',
  });
}

/// Match result outcomes when comparing recognition against catalog.
sealed class EquipmentMatchResult {
  const EquipmentMatchResult();
}

class SingleEquipmentMatch extends EquipmentMatchResult {
  const SingleEquipmentMatch({
    required this.equipment,
    required this.score,
    required this.reason,
  });

  final GymEquipment equipment;
  final double score;
  final String reason;
}

class MultipleEquipmentMatches extends EquipmentMatchResult {
  const MultipleEquipmentMatches({
    required this.candidates,
    required this.topScore,
  });

  final List<GymEquipment> candidates;
  final double topScore;
}

class NoEquipmentMatch extends EquipmentMatchResult {
  const NoEquipmentMatch({this.reason = "Couldn't recognise this equipment"});

  final String reason;
}

/// Pure domain matcher comparing Vision AI results with active catalog items.
class EquipmentMatcher {
  const EquipmentMatcher();

  /// Known synonyms and aliases for standard gym equipment to ensure robust matching.
  static const Map<String, List<String>> _standardAliases = {
    'squat rack': [
      'power rack',
      'power cage',
      'squat cage',
      'squat stand',
      'half rack',
      'barbell rack',
      'olympic squat rack',
    ],
    'standing press station': [
      'overhead press station',
      'military press station',
      'barbell press station',
      'shoulder press station',
      'standing press rack',
    ],
    'adjustable bench': [
      'workout bench',
      'weight bench',
      'flat bench',
      'incline bench',
      'decline bench',
      'utility bench',
      'dumbbell bench',
      'bench press bench',
    ],
    'dumbbell rack': [
      'dumbbells',
      'dumbbell',
      'free weights',
      'dumbbell set',
      'hand weights',
      'weight rack',
    ],
    'cable crossover machine': [
      'cable machine',
      'cable crossover',
      'dual cable cross',
      'cable station',
      'functional trainer',
      'pulley machine',
      'cable tower',
    ],
    'treadmill': [
      'running machine',
      'tread mill',
      'motorised treadmill',
      'motorized treadmill',
    ],
    'leg press machine': [
      'leg press',
      '45 degree leg press',
      'seated leg press',
    ],
    'smith machine': [
      'smith rack',
      'guided barbell',
    ],
    'lat pulldown machine': [
      'lat pulldown',
      'pulldown station',
      'lat pull',
    ],
  };

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Evaluates match similarity between a query string and a catalog equipment item.
  double _scoreQueryAgainstEquipment(String query, GymEquipment item) {
    final normQuery = _normalize(query);
    final normName = _normalize(item.name);

    if (normQuery.isEmpty || normName.isEmpty) return 0.0;

    // 1. Exact normalized name match
    if (normQuery == normName) return 1.0;

    // 2. Query contains exact item name or item name contains query
    if (normQuery.contains(normName) || normName.contains(normQuery)) {
      final ratio = normName.length / normQuery.length;
      return 0.85 + (0.10 * (ratio > 1.0 ? 1.0 / ratio : ratio));
    }

    // 3. Check known aliases for this item
    final aliases = _standardAliases[normName] ?? const [];
    for (final alias in aliases) {
      final normAlias = _normalize(alias);
      if (normQuery == normAlias) return 0.95;
      if (normQuery.contains(normAlias) || normAlias.contains(normQuery)) {
        return 0.88;
      }
    }

    // 4. Token overlap
    final queryTokens = normQuery.split(' ').where((t) => t.length > 2).toSet();
    final nameTokens = normName.split(' ').where((t) => t.length > 2).toSet();
    if (queryTokens.isNotEmpty && nameTokens.isNotEmpty) {
      final intersection = queryTokens.intersection(nameTokens);
      if (intersection.isNotEmpty) {
        final jaccard =
            intersection.length / queryTokens.union(nameTokens).length;
        if (jaccard >= 0.5) return 0.70 + (0.15 * jaccard);
      }
    }

    // 5. Category correlation boost if category is mentioned
    final normCat = _normalize(item.category);
    if (normCat.isNotEmpty && normQuery.contains(normCat)) {
      return 0.65;
    }

    return 0.0;
  }

  /// Match a recognition result against an active catalog list.
  EquipmentMatchResult match({
    required EquipmentRecognitionResult recognition,
    required List<GymEquipment> catalog,
  }) {
    // Model confidence is uncalibrated: use only to reject uncertain output.
    // The scanner requires user confirmation even for an accepted match.
    if (!recognition.confidence.isFinite ||
        recognition.confidence < 0.80 ||
        recognition.confidence > 1.0 ||
        recognition.detectedEquipment.length > 160) {
      return const NoEquipmentMatch(
          reason:
              'The photo is uncertain. Try a clearer photo or browse the catalogue.');
    }
    if (!recognition.isGymEquipment ||
        recognition.detectedEquipment.trim().isEmpty) {
      return const NoEquipmentMatch(
        reason: 'No gym equipment was recognized in this photo.',
      );
    }

    final activeItems = catalog.where((e) => e.isActive).toList();
    if (activeItems.isEmpty) {
      return const NoEquipmentMatch(
        reason: 'No active equipment found in the catalog.',
      );
    }

    final scores = <GymEquipment, double>{};

    for (final item in activeItems) {
      // Score detectedEquipment
      var maxItemScore =
          _scoreQueryAgainstEquipment(recognition.detectedEquipment, item);

      // Score aliases
      for (final alias in recognition.aliases) {
        final s = _scoreQueryAgainstEquipment(alias, item);
        if (s > maxItemScore) maxItemScore = s;
      }

      if (maxItemScore > 0.0) {
        scores[item] = maxItemScore;
      }
    }

    if (scores.isEmpty) {
      return const NoEquipmentMatch();
    }

    final sorted = scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topScore = sorted.first.value;

    // Minimum match threshold
    if (topScore < 0.60) {
      return const NoEquipmentMatch();
    }

    // Check for close candidates (disambiguation / multiple matches)
    final closeCandidates = sorted
        .where((e) => e.value >= 0.65 && (topScore - e.value) <= 0.15)
        .map((e) => e.key)
        .toList();

    if (closeCandidates.length > 1) {
      return MultipleEquipmentMatches(
        candidates: closeCandidates,
        topScore: topScore,
      );
    }

    final bestItem = sorted.first.key;
    return SingleEquipmentMatch(
      equipment: bestItem,
      score: topScore,
      reason: topScore >= 0.95 ? 'Exact match' : 'Best prediction match',
    );
  }
}
