class MemberAchievement {
  const MemberAchievement({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.target,
    required this.progress,
    this.unlockedAtMillis,
  });

  final String id, title, category, description;
  final int target, progress;
  final int? unlockedAtMillis;

  bool get unlocked => unlockedAtMillis != null;
  double get fraction => unlocked ? 1 : (progress / target).clamp(0, 1);
  String get unit => category == 'check-in'
      ? 'days'
      : switch (id) {
          'century-club' => 'reps',
          'routine-finisher' => 'routines',
          _ => 'workouts',
        };
  String get progressLabel =>
      '${unlocked ? target : progress.clamp(0, target)} / $target $unit';
  DateTime? get unlockedAt => unlockedAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(unlockedAtMillis!, isUtc: true);

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'description': description,
        'target': target,
        'progress': progress,
        'unlockedAtMillis': unlockedAtMillis,
      };

  factory MemberAchievement.fromJson(Object? value) {
    if (value is! Map ||
        value['id'] is! String ||
        value['title'] is! String ||
        value['description'] is! String ||
        !const ['check-in', 'workout'].contains(value['category']) ||
        value['target'] is! int ||
        (value['target'] as int) <= 0 ||
        value['progress'] is! int ||
        (value['progress'] as int) < 0 ||
        (value['unlockedAtMillis'] != null &&
            (value['unlockedAtMillis'] is! int ||
                (value['unlockedAtMillis'] as int) <= 0 ||
                (value['unlockedAtMillis'] as int) > 8640000000000000))) {
      throw const FormatException('Invalid achievement');
    }
    return MemberAchievement(
      id: value['id'] as String,
      title: value['title'] as String,
      category: value['category'] as String,
      description: value['description'] as String,
      target: value['target'] as int,
      progress: value['progress'] as int,
      unlockedAtMillis: value['unlockedAtMillis'] as int?,
    );
  }
}

class MemberAchievements {
  MemberAchievements({
    required this.currentStreak,
    required Iterable<MemberAchievement> badges,
    this.complete = true,
  }) : badges = List.unmodifiable(badges);

  final int currentStreak;
  final List<MemberAchievement> badges;
  final bool complete;

  Map<String, Object?> toJson() => {
        'schemaVersion': 1,
        'currentStreak': currentStreak,
        'badges': badges.map((badge) => badge.toJson()).toList(),
        'complete': complete,
      };

  int get unlockedCount => badges.where((badge) => badge.unlocked).length;

  MemberAchievement? get next {
    MemberAchievement? best;
    for (final badge in badges) {
      if (!badge.unlocked &&
          (complete || badge.category == 'check-in') &&
          (best == null || badge.fraction > best.fraction)) {
        best = badge;
      }
    }
    return best;
  }

  factory MemberAchievements.fromJson(Object? value) {
    if (value is! Map ||
        value['schemaVersion'] != 1 ||
        value['currentStreak'] is! int ||
        (value['currentStreak'] as int) < 0 ||
        value['badges'] is! List ||
        (value['complete'] != null && value['complete'] is! bool)) {
      throw const FormatException('Invalid achievements response');
    }
    final badges =
        (value['badges'] as List).map(MemberAchievement.fromJson).toList();
    if (badges.isEmpty ||
        badges.map((badge) => badge.id).toSet().length != badges.length) {
      throw const FormatException('Invalid achievement catalog');
    }
    return MemberAchievements(
      currentStreak: value['currentStreak'] as int,
      badges: badges,
      complete: value['complete'] as bool? ?? true,
    );
  }
}
