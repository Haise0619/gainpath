// All mock records for the GainPath frontend prototype.
// No backend is connected; every screen reads from here.

import 'package:flutter/material.dart' show IconData, Icons;

class Exercise {
  final String name;
  final String category;
  final int sets;
  final int reps;
  final String cue;
  final String imageUrl;
  final String muscleGroup;
  const Exercise(this.name, this.category, this.sets, this.reps, this.cue,
      this.imageUrl, this.muscleGroup);
}

class WorkoutRecord {
  final String exercise;
  final DateTime date;
  final int reps;
  final int accuracy;
  final int durationMin;
  const WorkoutRecord(
      this.exercise, this.date, this.reps, this.accuracy, this.durationMin);
}

class Coach {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int reviews;
  final String bio;
  final bool verified;
  const Coach(this.id, this.name, this.specialty, this.rating, this.reviews,
      this.bio, this.verified);
}

class Booking {
  final String id;
  final String coachName;
  final String memberName;
  final DateTime start;
  final String status;
  final double fee;
  final String? notes;
  const Booking(this.id, this.coachName, this.memberName, this.start,
      this.status, this.fee, this.notes);
}

class AchievementBadge {
  final String name;
  final String description;
  final bool unlocked;
  final IconData icon;

  /// Only set for locked badges — e.g. "12/14 days" — so the grid can show
  /// how close a member is rather than just a padlock.
  final String? progressLabel;
  final double? progressValue;

  const AchievementBadge(this.name, this.description, this.unlocked, this.icon,
      {this.progressLabel, this.progressValue});
}

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

class RewardItem {
  final String title;
  final int points;
  final int stock;
  final String imageUrl;
  const RewardItem(this.title, this.points, this.stock, this.imageUrl);
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String status;
  const Transaction(this.id, this.type, this.amount, this.date, this.status);
}

class ChatMessage {
  final String text;
  final bool fromUser;
  const ChatMessage(this.text, this.fromUser);
}

class RefundClaim {
  final String id;
  final String memberName;
  final String transactionId;
  final String transactionType;
  final double amount;
  final String reason;
  final String notes;
  final DateTime submitted;
  final String status;
  const RefundClaim(this.id, this.memberName, this.transactionId, this.transactionType,
      this.amount, this.reason, this.notes, this.submitted, this.status);
}

class UserAccount {
  final String name;
  final String email;
  final String role;
  final String status;
  const UserAccount(this.name, this.email, this.role, this.status);
}

class RiskLead {
  final String memberName;
  final String weakCategory;
  final int score;
  final String suggestion;
  const RiskLead(
      this.memberName, this.weakCategory, this.score, this.suggestion);
}

class MockData {
  // ---- Member identity -----------------------------------------------
  static const memberName = 'ZhengYang';
  static const memberEmail = 'zhengyang@example.com';
  static const memberTier = 'Premium';
  static const memberGender = 'Male';
  static const memberAge = 21;
  static const memberExperience = 'Intermediate';
  static const memberActivityLevel = 'Moderately active';
  static const memberHeight = 170;
  static const memberWeight = 58;
  static const memberTrainingFocus = <String>['Build muscle', 'Improve endurance'];

  static const coachName = 'Jason Lim';
  static const coachEmail = 'jason.lim@furyfitness.my';
  static const adminName = 'Muhammad Mustafah';
  static const adminEmail = 'admin@furyfitness.my';

  // ---- Module 2 -------------------------------------------------------
  static const routine = <Exercise>[
    Exercise(
      'Barbell Squat',
      'Compound Lower-Body',
      4,
      8,
      'Keep your chest up and drive your knees out.',
      'https://images.unsplash.com/photo-1534368959876-26bf04f2c947?auto=format&fit=crop&w=800&q=80',
      'Quads · Glutes',
    ),
    Exercise(
      'Romanian Deadlift',
      'Compound Lower-Body',
      3,
      10,
      'Keep a neutral spine, hinge from the hips.',
      'https://images.unsplash.com/photo-1583454110551-21f2fa2afe61?auto=format&fit=crop&w=800&q=80',
      'Hamstrings · Glutes',
    ),
    Exercise(
      'Overhead Press',
      'Compound Upper-Body',
      3,
      8,
      'Brace your core, avoid arching your lower back.',
      'https://images.unsplash.com/photo-1541534741688-6078c6bfb5c5?auto=format&fit=crop&w=800&q=80',
      'Shoulders · Triceps',
    ),
    Exercise(
      'Dumbbell Row',
      'Isolation Upper-Body',
      3,
      12,
      'Pull to the hip, keep your shoulder down.',
      'https://images.unsplash.com/photo-1601422407692-ec4eeec1d9b3?auto=format&fit=crop&w=800&q=80',
      'Back · Biceps',
    ),
  ];

  static const voiceCues = <String>[
    'Good depth. Hold that.',
    'Drive your knees out.',
    'Chest up.',
    'Nice rep. Keep the tempo.',
    'Slow the descent slightly.',
    'Brace your core.',
  ];

  // ---- Module 5 -------------------------------------------------------
  static final history = <WorkoutRecord>[
    WorkoutRecord('Barbell Squat', DateTime.now().subtract(const Duration(days: 1)), 32, 84, 42),
    WorkoutRecord('Overhead Press', DateTime.now().subtract(const Duration(days: 3)), 24, 79, 35),
    WorkoutRecord('Romanian Deadlift', DateTime.now().subtract(const Duration(days: 5)), 30, 71, 38),
    WorkoutRecord('Dumbbell Row', DateTime.now().subtract(const Duration(days: 8)), 36, 88, 30),
    WorkoutRecord('Barbell Squat', DateTime.now().subtract(const Duration(days: 11)), 28, 68, 40),
    WorkoutRecord('Overhead Press', DateTime.now().subtract(const Duration(days: 14)), 24, 74, 33),
  ];

  static const postureTrend = <int>[64, 68, 71, 69, 76, 79, 84];
  static const volumeTrend = <int>[2400, 2650, 2580, 2900, 3100, 3050, 3400];

  // ---- Module 3 -------------------------------------------------------
  static const points = 1840;
  static const streak = 12;
  static const longestStreak = 21;

  static const badges = <AchievementBadge>[
    AchievementBadge('First Session', 'Complete your first tracked workout.', true, Icons.flag_rounded),
    AchievementBadge('Week Warrior', 'Train 5 days in one week.', true, Icons.local_fire_department_rounded),
    AchievementBadge('Form Focused', 'Hit 85% posture accuracy in a session.', true, Icons.verified_rounded),
    AchievementBadge('Consistency', 'Reach a 14-day streak.', false, Icons.calendar_month_rounded,
        progressLabel: '12/14 days', progressValue: 12 / 14),
    AchievementBadge('Century', 'Log 100 total sessions.', false, Icons.emoji_events_rounded,
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

  static const rewards = <RewardItem>[
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

  // ---- Module 4 -------------------------------------------------------
  static final transactions = <Transaction>[
    Transaction('TXN-2041', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 12)), 'Cleared'),
    Transaction('TXN-1988', 'Coaching session', 120.00,
        DateTime.now().subtract(const Duration(days: 26)), 'Cleared'),
    Transaction('TXN-1902', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 42)), 'Cleared'),
  ];

  static const membershipPlans = <List<String>>[
    ['Basic', 'RM 49', 'Gym access and AI form tracking'],
    ['Premium', 'RM 89', 'Everything in Basic, plus coach booking and reports'],
  ];

  // ---- Module 7 / 8 ---------------------------------------------------
  static const coaches = <Coach>[
    Coach('c1', 'Jason Lim', 'Strength and Conditioning', 4.8, 47,
        'Six years coaching compound lifts, with a focus on safe progression for beginners.', true),
    Coach('c2', 'Priya Menon', 'Rehabilitation and Mobility', 4.9, 33,
        'Physiotherapy background, specialising in returning to training after injury.', true),
    Coach('c3', 'Hafiz Aziz', 'Hypertrophy', 4.6, 58,
        'Bodybuilding-oriented programming and technique refinement.', true),
    Coach('c4', 'Michelle Chan', 'Calisthenics', 4.7, 21,
        'Bodyweight progressions from first pull-up to advanced skills.', true),
  ];

  static final memberBookings = <Booking>[
    Booking('b1', 'Jason Lim', 'ZhengYang',
        DateTime.now().add(const Duration(days: 2, hours: 3)), 'Confirmed', 120, null),
    Booking('b2', 'Priya Menon', 'ZhengYang',
        DateTime.now().add(const Duration(days: 6)), 'Confirmed', 140, null),
    Booking('b3', 'Jason Lim', 'ZhengYang',
        DateTime.now().subtract(const Duration(days: 9)), 'Completed', 120,
        'Good squat depth this session. Work on keeping the chest up during the ascent.'),
  ];

  static final coachRoster = <Booking>[
    Booking('r1', 'Jason Lim', 'ZhengYang',
        DateTime.now().add(const Duration(days: 2, hours: 3)), 'Confirmed', 120, null),
    Booking('r2', 'Jason Lim', 'Daniel Wong',
        DateTime.now().add(const Duration(days: 2, hours: 5)), 'Confirmed', 120, null),
    Booking('r3', 'Jason Lim', 'Nurul Huda',
        DateTime.now().add(const Duration(days: 4)), 'Pending', 120, null),
    Booking('r4', 'Jason Lim', 'Farid Zainal',
        DateTime.now().subtract(const Duration(days: 1)), 'Completed', 120, null),
  ];

  // ---- Module 6 -------------------------------------------------------
  static const chatSeed = <ChatMessage>[
    ChatMessage('How do I stop my knees caving in during squats?', true),
    ChatMessage(
        'Knee valgus usually comes from weak glute medius or a stance that is too narrow. Try widening your stance slightly and consciously pushing your knees out as you descend. Adding banded side-steps before your session can help too.\n\nThis is general educational guidance, not medical advice.',
        false),
  ];

  static const savedAdvice = <String>[
    'Widen your stance slightly and push the knees out on the descent.',
    'Aim for a neutral spine on deadlifts, brace before the pull.',
    'Progressive overload works best in small weekly increments.',
  ];

  // ---- Module 10 ------------------------------------------------------
  static const workingHours = <List<String>>[
    ['Monday', '08:00', '17:00', 'true'],
    ['Tuesday', '08:00', '17:00', 'true'],
    ['Wednesday', '08:00', '17:00', 'true'],
    ['Thursday', '10:00', '19:00', 'true'],
    ['Friday', '08:00', '15:00', 'true'],
    ['Saturday', '09:00', '13:00', 'true'],
    ['Sunday', '00:00', '00:00', 'false'],
  ];

  static final blockedSlots = <List<String>>[
    ['Medical leave', 'Fri, 12 Sep', 'Full day'],
    ['Lunch break', 'Daily', '13:00 to 14:00'],
  ];

  // ---- Module 11 ------------------------------------------------------
  static const users = <UserAccount>[
    UserAccount('ZhengYang', 'zhengyang@example.com', 'Member', 'Active'),
    UserAccount('Daniel Wong', 'daniel.w@example.com', 'Member', 'Active'),
    UserAccount('Farid Zainal', 'farid.z@example.com', 'Member', 'Suspended'),
    UserAccount('Jason Lim', 'jason.lim@furyfitness.my', 'Coach', 'Verified'),
    UserAccount('Priya Menon', 'priya.m@furyfitness.my', 'Coach', 'Verified'),
    UserAccount('Hafiz Aziz', 'hafiz.a@furyfitness.my', 'Coach', 'Pending'),
  ];

  // ---- Module 12 ------------------------------------------------------
  static const adminStats = <List<String>>[
    ['Active members', '284', '+12 this month'],
    ['Verified coaches', '9', '1 pending review'],
    ['Sessions this week', '1,206', '+8% vs last week'],
    ['Revenue this month', 'RM 24,180', '+5% vs last month'],
  ];

  static const usageByHour = <int>[
    2, 1, 1, 0, 1, 4, 12, 22, 26, 18, 14, 16,
    19, 17, 15, 20, 28, 42, 48, 39, 26, 15, 8, 4,
  ];

  static final refundClaims = <RefundClaim>[
    RefundClaim('CLM-3092', 'Farid Zainal', 'TXN-1902', 'Membership renewal', 89.00,
        'Charged after cancelling',
        'I cancelled my auto-renewal on the app before the charge date but was billed anyway.',
        DateTime.now().subtract(const Duration(days: 3)), 'Pending'),
    RefundClaim('CLM-3088', 'Daniel Wong', 'TXN-1988', 'Coaching session', 120.00,
        'Coach cancelled the session',
        'Jason had to cancel last minute due to an emergency and the session was never rescheduled.',
        DateTime.now().subtract(const Duration(days: 5)), 'Pending'),
  ];

  static const riskExercises = <List<String>>[
    ['Romanian Deadlift', '61%', 'High'],
    ['Barbell Squat', '68%', 'High'],
    ['Overhead Press', '74%', 'Moderate'],
    ['Lunges', '76%', 'Moderate'],
    ['Dumbbell Row', '86%', 'Low'],
  ];

  static const atRiskLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'Priya Menon'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Jason Lim'),
    RiskLead('Wei Ling Tan', 'Overhead Press', 65, 'Hafiz Aziz'),
  ];

  static const contentLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'RDL Form Basics'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Fixing Knee Valgus'),
  ];

  static const contentGaps = <List<String>>[
    ['Lunges', '76%', 'No tutorial linked'],
    ['Bulgarian Split Squat', '72%', 'No tutorial linked'],
  ];

  static const tutorials = <List<String>>[
    ['Squat Form Fundamentals', 'Compound Lower-Body', 'Active'],
    ['Fixing Knee Valgus', 'Compound Lower-Body', 'Active'],
    ['RDL Form Basics', 'Compound Lower-Body', 'Active'],
    ['Overhead Press Setup', 'Compound Upper-Body', 'Active'],
  ];
}
