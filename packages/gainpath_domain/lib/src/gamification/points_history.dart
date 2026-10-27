class PointsHistoryEntry {
  const PointsHistoryEntry(
      {required this.id,
      required this.source,
      required this.title,
      required this.points,
      required this.occurredAtMillis,
      this.wallet = 'spendable',
      this.redemptionId});
  final String id, source, title, wallet;
  final int points, occurredAtMillis;
  final String? redemptionId;
}

class PointsHistorySnapshot {
  const PointsHistorySnapshot(
      {required this.balance,
      required this.entries,
      required this.reconciled,
      this.demoBalance,
      this.demoReconciled});
  final int balance;

  /// Null means the legacy endpoint did not include participation history.
  final int? demoBalance;
  final bool? demoReconciled;
  final List<PointsHistoryEntry> entries;
  final bool reconciled;
  factory PointsHistorySnapshot.fromJson(Map<String, dynamic> d,
      {required String organizationId, required String memberId}) {
    bool integer(Object? v) => v is int && v >= 0 && v <= 9007199254740991;
    final unified = d['schemaVersion'] == 2;
    if ((!unified && d['schemaVersion'] != 1) ||
        d['organizationId'] != organizationId ||
        d['memberId'] != memberId ||
        !integer(d['balance']) ||
        !integer(d['resolvedAtMillis']) ||
        d['reconciled'] is! bool ||
        d['entries'] is! List ||
        (d['entries'] as List).length > (unified ? 1000 : 800) ||
        (unified &&
            (!integer(d['demoBalance']) || d['demoReconciled'] is! bool))) {
      throw const FormatException('Invalid points history.');
    }
    final seen = <String>{};
    int last = 9007199254740991;
    var net = 0, demoNet = 0;
    final entries = (d['entries'] as List).map((raw) {
      if (raw is! Map) throw const FormatException('Invalid history entry.');
      final id = raw['id'],
          source = raw['source'],
          title = raw['title'],
          points = raw['points'],
          at = raw['occurredAtMillis'],
          voucher = raw['redemptionId'],
          wallet = unified ? raw['wallet'] : 'spendable';
      if (id is! String ||
          !RegExp(r'^[A-Za-z0-9_:-]{1,150}$').hasMatch(id) ||
          !seen.add(id) ||
          ![
            'app_check_in',
            'manual_credit',
            'activity_reward',
            'redemption',
            if (unified) ...['workout_reward', 'mini_game_participation']
          ].contains(source) ||
          !['spendable', 'demo'].contains(wallet) ||
          (wallet == 'demo' && source != 'mini_game_participation') ||
          title is! String ||
          title.isEmpty ||
          title.length > 200 ||
          points is! int ||
          points == 0 ||
          points.abs() > 9007199254740991 ||
          !integer(at) ||
          at == 0 ||
          at > last ||
          at > d['resolvedAtMillis'] ||
          ((source == 'redemption') != (points < 0)) ||
          (source == 'redemption' &&
              (voucher is! String ||
                  !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(voucher))) ||
          (source != 'redemption' && voucher != null)) {
        throw const FormatException('Invalid history entry.');
      }
      last = at as int;
      if (wallet == 'demo') {
        demoNet += points;
      } else {
        net += points;
      }
      if (net.abs() > 9007199254740991 || demoNet > 9007199254740991) {
        throw const FormatException('Invalid history totals.');
      }
      return PointsHistoryEntry(
          id: id,
          source: source as String,
          title: title,
          points: points,
          occurredAtMillis: at,
          wallet: wallet as String,
          redemptionId: voucher as String?);
    }).toList(growable: false);
    if (d['reconciled'] != (net == d['balance']) ||
        (unified && d['demoReconciled'] != (demoNet == d['demoBalance']))) {
      throw const FormatException('Invalid history totals.');
    }
    return PointsHistorySnapshot(
        balance: d['balance'] as int,
        demoBalance: unified ? d['demoBalance'] as int : null,
        demoReconciled: unified ? d['demoReconciled'] as bool : null,
        entries: List.unmodifiable(entries),
        reconciled: d['reconciled'] as bool);
  }
}
