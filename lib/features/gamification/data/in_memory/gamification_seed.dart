import 'package:flutter/material.dart' show Icons;
import 'package:gainpath/features/gamification/domain/entities/achievement_badge.dart';
import 'package:gainpath/features/gamification/domain/entities/mini_game.dart';
import 'package:gainpath/features/gamification/domain/entities/reward_item.dart';

/// In-memory seed data for the gamification feature (frontend prototype).
class GamificationSeed {
  static int points = 1840;

  static int streak = 12;

  static int longestStreak = 21;

  static const _twemoji = 'https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72';

  static const badges = <AchievementBadge>[
    AchievementBadge(
        'First Session', 'Complete your first tracked workout.', true, '$_twemoji/1f6a9.png'),
    AchievementBadge('Week Warrior', 'Train 5 days in one week.', true, '$_twemoji/1f525.png'),
    AchievementBadge(
        'Form Focused', 'Hit 85% posture accuracy in a session.', true, '$_twemoji/1f3af.png'),
    AchievementBadge('Consistency', 'Reach a 14-day streak.', false, '$_twemoji/1f4c5.png',
        progressLabel: '12/14 days', progressValue: 12 / 14),
    AchievementBadge('Century', 'Log 100 total sessions.', false, '$_twemoji/1f3c6.png',
        progressLabel: '47/100 sessions', progressValue: 47 / 100),
  ];

  static const miniGames = <MiniGame>[
    MiniGame(
      'Squat Smash',
      'Smash through as many clean squats as you can before the clock hits zero.',
      'https://images.unsplash.com/photo-1546483875-ad9014c88eba?auto=format&fit=crop&w=800&q=80',
      'Medium',
      1200,
      Icons.bolt_rounded,
      2140,
    ),
    MiniGame(
      'Plank Master',
      'Lock in and hold the zone — the longer you hold, the higher you climb.',
      'https://images.unsplash.com/photo-1584464491033-06628f3a6b7b?auto=format&fit=crop&w=800&q=80',
      'Hard',
      1020,
      Icons.shield_rounded,
      1680,
    ),
    MiniGame(
      'Lunge Blitz',
      'React fast and lunge to the correct side before the prompt disappears.',
      'https://images.unsplash.com/photo-1517130038641-a774d04afb3c?auto=format&fit=crop&w=800&q=80',
      'Easy',
      840,
      Icons.flash_on_rounded,
      2960,
    ),
    MiniGame(
      'Combo Rush',
      'Chain punches on the beat for a fast-paced cardio combo streak.',
      'https://images.unsplash.com/photo-1554284126-aa88f22d8b74?auto=format&fit=crop&w=800&q=80',
      'Medium',
      660,
      Icons.sports_mma_rounded,
      1340,
    ),
  ];

  static final rewards = <RewardItem>[
    RewardItem('Protein Shake Voucher', 400, 24,
        'https://images.unsplash.com/photo-1553530666-ba11a7da3888?auto=format&fit=crop&w=800&q=80'),
    RewardItem('Gym Towel', 800, 12,
        'https://images.unsplash.com/photo-1591117207239-788bf8de6c3b?auto=format&fit=crop&w=800&q=80'),
    RewardItem('One Free Day Pass', 1200, 8,
        'https://images.unsplash.com/photo-1571902943202-507ec2618e8f?auto=format&fit=crop&w=800&q=80'),
    RewardItem('Branded Water Bottle', 1500, 5,
        'https://images.unsplash.com/photo-1523362628745-0c100150b504?auto=format&fit=crop&w=800&q=80'),
  ];

  static const leaderboard = <List<String>>[
    ['1', 'Farid Zainal', '3,120'],
    ['2', 'Wei Ling Tan', '2,780'],
    ['3', 'Daniel Wong', '2,410'],
    ['4', 'ZhengYang', '1,840'],
    ['5', 'Nurul Huda', '1,655'],
  ];
}
