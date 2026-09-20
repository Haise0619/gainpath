class AchievementBadge {
  final String name;
  final String description;
  final bool unlocked;

  /// A small cartoon badge illustration (Twemoji, via jsdelivr) instead
  /// of a flat Material icon — replaces what used to be a plain `IconData`
  /// here, so the badge grid actually looks like something worth earning.
  final String imageUrl;

  /// Only set for locked badges — e.g. "12/14 days" — so the grid can show
  /// how close a member is rather than just a padlock.
  final String? progressLabel;
  final double? progressValue;

  const AchievementBadge(this.name, this.description, this.unlocked, this.imageUrl,
      {this.progressLabel, this.progressValue});
}
