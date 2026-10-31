import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;

/// Completed local gameplay aggregates. No pose or reward evidence is retained.
final class ReachTapRound {
  ReachTapRound({
    required this.id,
    required this.completedAt,
    required this.hits,
    required this.score,
    this.activeMicros = completedActiveMicros,
  }) {
    if (!RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        !completedAt.isUtc ||
        completedAt.millisecondsSinceEpoch <= 0 ||
        completedAt.year > 9999 ||
        hits < 0 ||
        hits > maxScore ~/ 10 ||
        score != hits * 10 ||
        activeMicros != completedActiveMicros) {
      throw ArgumentError('Invalid completed Reach & Tap round.');
    }
  }

  static const completedActiveMicros = 40000000;
  static const maxScore = 1000000;
  final String id;
  final DateTime completedAt;
  final int hits, score, activeMicros;
}

final class ReachTapHistory {
  ReachTapHistory({Iterable<ReachTapRound> rounds = const [], this.bestScore = 0})
      : rounds = List.unmodifiable(rounds) {
    if (this.rounds.length > maxRounds ||
        this.rounds.map((round) => round.id).toSet().length != this.rounds.length ||
        bestScore < 0 ||
        bestScore > ReachTapRound.maxScore ||
        bestScore % 10 != 0 ||
        this.rounds.any((round) => round.score > bestScore)) {
      throw ArgumentError('Invalid Reach & Tap history.');
    }
  }

  static const maxRounds = 100;
  final List<ReachTapRound> rounds;
  final int bestScore;
}

abstract interface class ReachTapHistoryStore {
  Future<ReachTapHistory> load(SessionScope scope);
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
      {required bool Function() isCurrent});
}
