import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/gamification/data/in_memory/in_memory_gamification_repository.dart';

void main() {
  test('InMemoryGamificationRepository serves seed data', () {
    final repo = InMemoryGamificationRepository();
    expect(repo.badges, isNotEmpty);
    expect(repo.miniGames, isNotEmpty);
    expect(repo.rewards, isNotEmpty);
    expect(repo.leaderboard, isNotEmpty);
  });
}
