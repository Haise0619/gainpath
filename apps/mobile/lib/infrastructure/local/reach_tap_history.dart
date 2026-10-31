import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:path_provider/path_provider.dart';
import '../../features/gamification/domain/reach_tap_ports.dart';

class LocalReachTapHistory implements ReachTapHistoryStore {
  LocalReachTapHistory({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;
  static const _maxBytes = 65536;

  // All instances in this application isolate share the publication queue.
  static Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<File> _file(SessionScope scope) async {
    final key = sha256
        .convert(utf8.encode(jsonEncode([scope.organizationId, scope.userId])));
    final directory = await _directory();
    return File('${directory.path}/reach_tap_v1_$key.json');
  }

  static int _compare(ReachTapRound a, ReachTapRound b) {
    final time = b.completedAt.compareTo(a.completedAt);
    return time == 0 ? a.id.compareTo(b.id) : time;
  }

  Future<ReachTapHistory> _read(File file, SessionScope scope) async {
    if (!await file.exists()) return ReachTapHistory();
    final input = await file.open();
    late List<int> bytes;
    try {
      if (await input.length() > _maxBytes) {
        throw const FormatException('Reach & Tap history is too large.');
      }
      bytes = await input.read(_maxBytes + 1);
    } finally {
      await input.close();
    }
    if (bytes.length > _maxBytes) {
      throw const FormatException('Reach & Tap history is too large.');
    }
    final data = jsonDecode(utf8.decode(bytes));
    if (data is! Map ||
        data.length != 6 ||
        data['schemaVersion'] is! int ||
        data['schemaVersion'] != 1 ||
        data['organizationId'] != scope.organizationId ||
        data['memberId'] != scope.userId ||
        data['gameVersion'] != 'reach-tap-v1' ||
        data['bestScore'] is! int ||
        data['rounds'] is! List ||
        (data['rounds'] as List).length > ReachTapHistory.maxRounds) {
      throw const FormatException('Invalid owned Reach & Tap history.');
    }
    try {
      final rounds = <ReachTapRound>[];
      for (final row in data['rounds'] as List) {
        if (row is! Map ||
            row.length != 5 ||
            row['id'] is! String ||
            row['completedAt'] is! String ||
            row['hits'] is! int ||
            row['score'] is! int ||
            row['activeMicros'] is! int) {
          throw const FormatException('Invalid completed Reach & Tap round.');
        }
        final completedAt = DateTime.tryParse(row['completedAt'] as String);
        if (completedAt == null ||
            !completedAt.isUtc ||
            completedAt.toIso8601String() != row['completedAt']) {
          throw const FormatException('Invalid Reach & Tap completion date.');
        }
        rounds.add(ReachTapRound(
            id: row['id'],
            completedAt: completedAt,
            hits: row['hits'],
            score: row['score'],
            activeMicros: row['activeMicros']));
      }
      rounds.sort(_compare);
      return ReachTapHistory(rounds: rounds, bestScore: data['bestScore']);
    } on ArgumentError {
      throw const FormatException('Invalid Reach & Tap history aggregates.');
    }
  }

  void _checkCurrent(bool Function() isCurrent) {
    if (!isCurrent()) throw StateError('Reach & Tap account changed.');
  }

  @override
  Future<ReachTapHistory> load(SessionScope scope) =>
      _serial(() async => _read(await _file(scope), scope));

  @override
  Future<ReachTapHistory> record(SessionScope scope, ReachTapRound round,
          {required bool Function() isCurrent}) =>
      _serial(() async {
        _checkCurrent(isCurrent);
        final file = await _file(scope);
        final previous = await _read(file, scope);
        _checkCurrent(isCurrent);
        for (final saved in previous.rounds) {
          if (saved.id != round.id) continue;
          if (saved.completedAt != round.completedAt ||
              saved.hits != round.hits ||
              saved.score != round.score ||
              saved.activeMicros != round.activeMicros) {
            throw StateError(
                'Reach & Tap round ID has conflicting aggregates.');
          }
          return previous;
        }
        // An evicted round cannot be safely distinguished from an old retry.
        if (previous.rounds.length == ReachTapHistory.maxRounds &&
            _compare(round, previous.rounds.last) >= 0) {
          throw StateError(
              'Reach & Tap round is outside the retained retry window.');
        }
        final rounds = [...previous.rounds, round]..sort(_compare);
        final history = ReachTapHistory(
            rounds: rounds.take(ReachTapHistory.maxRounds),
            bestScore: round.score > previous.bestScore
                ? round.score
                : previous.bestScore);
        final encoded = jsonEncode({
          'schemaVersion': 1,
          'organizationId': scope.organizationId,
          'memberId': scope.userId,
          'gameVersion': 'reach-tap-v1',
          'bestScore': history.bestScore,
          'rounds': history.rounds
              .map((item) => {
                    'id': item.id,
                    'completedAt': item.completedAt.toIso8601String(),
                    'hits': item.hits,
                    'score': item.score,
                    'activeMicros': item.activeMicros,
                  })
              .toList(),
        });
        if (utf8.encode(encoded).length > _maxBytes) {
          throw StateError('Reach & Tap history exceeds storage bound.');
        }
        await file.parent.create(recursive: true);
        final pending = File('${file.path}.pending');
        try {
          await pending.writeAsString(encoded, flush: true);
          _checkCurrent(isCurrent);
          await pending.rename(file.path);
          _checkCurrent(isCurrent);
          return history;
        } finally {
          if (await pending.exists()) await pending.delete();
        }
      });
}
