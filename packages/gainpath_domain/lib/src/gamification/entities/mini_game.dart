enum MiniGameIcon { bolt, shield, flash, boxing }

class MiniGame {
  final String name;
  final String tagline;
  final String imageUrl;
  final String difficulty;
  final int bestScore;
  final MiniGameIcon icon;
  final int plays;
  const MiniGame(this.name, this.tagline, this.imageUrl, this.difficulty, this.bestScore,
      this.icon, this.plays);
}
