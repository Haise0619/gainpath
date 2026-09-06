import 'package:flutter/material.dart' show IconData;

class MiniGame {
  final String name;
  final String tagline;
  final String imageUrl;
  final String difficulty;
  final int bestScore;
  final IconData icon;
  final int plays;
  const MiniGame(this.name, this.tagline, this.imageUrl, this.difficulty, this.bestScore,
      this.icon, this.plays);
}
