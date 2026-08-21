// All mock records for the GainPath frontend prototype.
// No backend is connected; every screen reads from here.

import 'package:flutter/material.dart' show IconData, Icons, TimeOfDay;

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

/// UC-2.6 — Equipment recognition catalogue. [category] deliberately uses
/// the same value space as [Exercise.category] (not a separate taxonomy)
/// so a scanned/browsed piece of equipment can pull real matching
/// exercises straight out of `MockData.routine` — see
/// `EquipmentDetailScreen`'s "Related exercises" section. Some equipment
/// has no exercise in the current routine sharing its category on
/// purpose (Cable Crossover, Treadmill), so that screen also has to
/// handle the honest "nothing matched" case, not just the happy path.
class GymEquipment {
  final String id;

  /// Mutable, along with the rest of the descriptive fields below, so
  /// the admin Equipment Catalog's Edit form can update a machine's
  /// record in place — same "mutate MockData in place" pattern used for
  /// [isActive].
  String name;
  String category;
  String description;
  List<String> howToUse;
  List<String> safetyTips;
  String imageUrl;
  String muscleGroup;

  /// Mutable so admin can unpublish a broken/removed machine without
  /// deleting its record — matches `gymEquipment.isActive` in the data
  /// dictionary. Inactive equipment stays out of the member scanner's
  /// match pool and the browse catalogue.
  bool isActive;

  GymEquipment({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.howToUse,
    required this.safetyTips,
    required this.imageUrl,
    required this.muscleGroup,
    this.isActive = true,
  });
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

class WeightEntry {
  final DateTime date;
  final double weightKg;
  const WeightEntry(this.date, this.weightKg);
}

class MuscleGroupShare {
  final String label;
  final double ratio;
  const MuscleGroupShare(this.label, this.ratio);
}

/// [bio], [specializationTags], and [fee] are mutable so a coach editing
/// their own professional profile (coach-side) updates the very same
/// object members browse in the directory — the "mutate MockData in
/// place" pattern already used for savedAdvice and Booking.
class Coach {
  final String id;
  final String name;
  final String specialty;
  List<String> specializationTags;
  final double rating;
  final int reviews;
  String bio;
  final bool verified;
  final String imageUrl;
  final String branch;
  double fee;
  final int yearsExperience;
  final int sessionsCompleted;
  final String responseTime;
  final List<CoachReview> topReviews;
  Coach({
    required this.id,
    required this.name,
    required this.specialty,
    required this.specializationTags,
    required this.rating,
    required this.reviews,
    required this.bio,
    required this.verified,
    required this.imageUrl,
    required this.branch,
    required this.fee,
    required this.yearsExperience,
    required this.sessionsCompleted,
    required this.responseTime,
    required this.topReviews,
  });
}

/// AD-M8.3 — a certification document a coach uploads for gym-staff
/// verification. [status] is one of Verified / Pending review / Rejected;
/// [rejectionReason] is set only when rejected. Mutable + stored in a
/// mutable list so uploading actually adds a Pending entry the coach can
/// then see, matching the CertificationDocument entity in the data
/// dictionary (without a backend behind it).
class CoachCertification {
  final String name;
  String status;
  final DateTime uploadedAt;
  final String? rejectionReason;
  CoachCertification(this.name, this.status, this.uploadedAt, {this.rejectionReason});
}

class CoachReview {
  final String memberName;
  final int stars;
  final String reviewText;
  final DateTime createdAt;
  const CoachReview(this.memberName, this.stars, this.reviewText, this.createdAt);
}

/// Embedded chat message for the member↔coach thread on a single booking,
/// mirroring the BookingMessage subcollection in the data dictionary
/// (senderRole, text, sentAt) without a backend behind it.
class BookingMessage {
  final String senderRole;
  final String text;
  final DateTime sentAt;
  const BookingMessage(this.senderRole, this.text, this.sentAt);
}

/// [start], [status], [notes], [rated], and [cancellationReason] are
/// mutable — rescheduling, cancelling, rating, and a coach publishing
/// consultation notes all mutate a booking in place rather than
/// replacing it in the list, the same pattern already used for
/// `MockData.savedAdvice` in the chatbot module.
class Booking {
  final String id;
  final String coachId;
  final String coachName;
  final String memberName;
  DateTime start;
  final int durationMin;
  final String branch;
  String status;
  final double fee;
  String? notes;
  bool rated;
  String? cancellationReason;
  final List<BookingMessage> messages;
  Booking({
    required this.id,
    required this.coachId,
    required this.coachName,
    required this.memberName,
    required this.start,
    this.durationMin = 60,
    required this.branch,
    required this.status,
    required this.fee,
    this.notes,
    this.rated = false,
    this.cancellationReason,
    List<BookingMessage>? messages,
  }) : messages = messages ?? [];
}

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

/// Fields are mutable so the admin Reward Catalog's Edit form can update
/// a listing in place instead of only ever creating new ones.
class RewardItem {
  String title;
  int points;
  int stock;
  String imageUrl;
  RewardItem(this.title, this.points, this.stock, this.imageUrl);
}

/// AD-M11.4 — one video in the Exercise Tutorial Library.
/// [coversExercise] names which `riskExercises` entry (if any) this
/// tutorial actually addresses, empty string if none — that link is
/// what makes `MockData.contentGaps` real instead of guessed from title
/// text. Fields are mutable so the admin Edit form can update a video
/// in place.
class TutorialVideo {
  String title;
  String category;
  String status;
  String coversExercise;
  TutorialVideo({required this.title, required this.category, required this.status, this.coversExercise = ''});
}

class MembershipPlan {
  final String id;
  final String name;
  final double price;
  final String tagline;
  final List<String> perks;
  final bool popular;
  const MembershipPlan(this.id, this.name, this.price, this.tagline, this.perks,
      {this.popular = false});
}

class Transaction {
  final String id;
  final String type;
  final double amount;
  final DateTime date;
  final String status;
  const Transaction(this.id, this.type, this.amount, this.date, this.status);
}

/// One prescribed exercise within a `RoutineDay` — deliberately just a
/// name/sets/reps triple rather than a reference to `Exercise`, since an
/// admin-authored template routinely calls for movements (leg press,
/// lat pulldown, curls) outside the small pose-tracked library the AI
/// coach demo covers; the two are related but not the same catalogue.
class RoutineExerciseRef {
  final String exerciseName;
  final int sets;
  final int reps;
  const RoutineExerciseRef(this.exerciseName, this.sets, this.reps);
}

class RoutineDay {
  final int dayNumber;
  final List<RoutineExerciseRef> exercises;
  const RoutineDay(this.dayNumber, this.exercises);
}

/// AD-M11.4 — an admin-authored `RoutineBlueprint` a coach or member can
/// be assigned. [assignedMembers] is illustrative — no assignment flow
/// is modelled yet — kept purely to give the admin catalogue a sense of
/// which templates are actually in use. [name], [level], and [days] are
/// mutable so the admin Edit form can replace them wholesale on save —
/// simpler than mutating the nested day/exercise structure in place.
class RoutineBlueprint {
  final String id;
  String name;
  String level;
  final int assignedMembers;
  List<RoutineDay> days;
  RoutineBlueprint({
    required this.id,
    required this.name,
    required this.level,
    required this.assignedMembers,
    required this.days,
  });
}

/// AD-M11.4 — the data dictionary's `Broadcast` entity: a member-facing
/// announcement with a validity window. [isActive] is computed from
/// [validFrom]/[validTo] against the current time rather than stored,
/// so it can never go stale.
class Announcement {
  final String id;
  final String title;
  final String body;
  final DateTime validFrom;
  final DateTime validTo;
  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.validFrom,
    required this.validTo,
  });

  bool get isActive {
    final now = DateTime.now();
    return now.isAfter(validFrom) && now.isBefore(validTo);
  }
}

/// A physical facility location, per the data dictionary's `Branch`
/// entity. Every `Coach.branch` / `Booking.branch` string is expected to
/// match one of these `name` values.
class Branch {
  final String id;
  final String name;
  final String address;
  final String contactPhone;
  final bool isActive;
  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.contactPhone,
    required this.isActive,
  });
}

/// A chatbot reply can carry a rich [attachment] alongside its [text] —
/// an equipment card with a photo, or a small progress chart — instead
/// of every answer being a plain text bubble.
class ChatMessage {
  final String text;
  final bool fromUser;
  final ChatAttachment? attachment;
  const ChatMessage(this.text, this.fromUser, {this.attachment});
}

sealed class ChatAttachment {
  const ChatAttachment();
}

/// A single piece of gym equipment surfaced inline, for questions like
/// "what machine works my chest?" — tapping it opens the full
/// `EquipmentDetailScreen` guide.
class EquipmentAttachment extends ChatAttachment {
  final GymEquipment equipment;
  const EquipmentAttachment(this.equipment);
}

/// A small trend chart surfaced inline, for questions like "how's my
/// workout going?" — reuses the same session-indexed series the
/// Progress tab charts are built from.
class ProgressChartAttachment extends ChatAttachment {
  final String title;
  final String unit;
  final List<int> values;
  final String delta;
  const ProgressChartAttachment(this.title, this.unit, this.values, this.delta);
}

class FaqPrompt {
  final String question;
  final String reply;
  const FaqPrompt(this.question, this.reply);
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

/// [status] is mutable — suspending a member, deactivating a coach, and
/// verifying/rejecting a coach's credentials all mutate the account in
/// place, the same pattern used for `GymEquipment.isActive` elsewhere.
/// [branch] and [specialty] are only meaningful for a `Coach` account —
/// a member's is always null. They're the account-shell counterpart to
/// `Coach.branch`/`Coach.specialty` in `MockData.coaches`: set the moment
/// a coach is provisioned, before their full public profile exists.
class UserAccount {
  final String name;
  final String email;
  final String role;
  String status;
  final String? branch;
  final String? specialty;
  UserAccount(this.name, this.email, this.role, this.status, {this.branch, this.specialty});
}

/// One labelled slice for a donut/pie chart — reused across the admin
/// Reports sections (risk distribution, reward mix, streak buckets)
/// instead of each section inventing its own tuple shape.
class ChartSlice {
  final String label;
  final double value;
  const ChartSlice(this.label, this.value);
}

class RiskLead {
  final String memberName;
  final String weakCategory;
  final int score;
  final String suggestion;
  const RiskLead(
      this.memberName, this.weakCategory, this.score, this.suggestion);
}

/// AD-M10.1 — one weekday's recurring working window. [start]/[end]/
/// [active] are all mutable and edited directly (real time pickers, not
/// static display text), the same "mutate MockData in place" pattern
/// used throughout this app's other mutable records.
class WorkingDay {
  final String day;
  TimeOfDay start;
  TimeOfDay end;
  bool active;
  WorkingDay(this.day, this.start, this.end, this.active);
}

/// AD-M10.1 — a single time-off entry. [type] distinguishes a recurring
/// daily interruption (a break) from a whole day being unavailable (an
/// off-day or approved leave) — members shouldn't be able to book into
/// any of the three, but they read and are edited differently.
enum BlockType { breakTime, offDay, leave }

extension BlockTypeLabel on BlockType {
  String get label => switch (this) {
        BlockType.breakTime => 'Break',
        BlockType.offDay => 'Off-day',
        BlockType.leave => 'Leave',
      };

  IconData get icon => switch (this) {
        BlockType.breakTime => Icons.free_breakfast_rounded,
        BlockType.offDay => Icons.weekend_rounded,
        BlockType.leave => Icons.flight_takeoff_rounded,
      };
}

class BlockedSlot {
  final String id;
  BlockType type;
  String reason;
  DateTime date;
  bool fullDay;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  BlockedSlot({
    required this.id,
    required this.type,
    required this.reason,
    required this.date,
    required this.fullDay,
    this.startTime,
    this.endTime,
  });
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
  static const coachPhone = '+60 12-345 6789';

  /// The signed-in coach's own directory record — the same [Coach] object
  /// members browse. Editing the professional profile coach-side mutates
  /// this instance, so the public directory reflects the change.
  static Coach get currentCoach =>
      coaches.firstWhere((c) => c.name == coachName);

  /// AD-M8.3 — the signed-in coach's uploaded credentials. Mutable so an
  /// upload adds a Pending entry that then shows in the list.
  static final coachCertifications = <CoachCertification>[
    CoachCertification('NASM Certified Personal Trainer', 'Verified',
        DateTime.now().subtract(const Duration(days: 210))),
    CoachCertification('First Aid & CPR (Red Crescent)', 'Verified',
        DateTime.now().subtract(const Duration(days: 120))),
    CoachCertification('Strength Specialist Level 2', 'Pending review',
        DateTime.now().subtract(const Duration(days: 3))),
  ];

  static const adminName = 'Muhammad Mustafah';
  static const adminEmail = 'admin@gainpath.com';

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

  // ---- Module 2: Equipment scanner (UC-2.6) ----------------------------
  static final gymEquipment = <GymEquipment>[
    GymEquipment(
      id: 'eq1',
      name: 'Squat Rack',
      category: 'Compound Lower-Body',
      description:
          'A fixed barbell rack with adjustable safety arms, used for barbell squats, rack pulls, '
          'and overhead presses started from a supported position.',
      howToUse: [
        'Set the J-hooks to just below shoulder height.',
        'Set the safety arms roughly at your lowest squat depth.',
        'Step under the bar, unrack by standing up, then step back clear of the hooks.',
        'Re-rack by walking forward until the bar contacts the hooks.',
      ],
      safetyTips: [
        'Always set the safety arms before loading the bar.',
        'Load and unload plates evenly on both sides.',
        'Ask for a spot on heavy attempts if the rack has no arms set.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1585152968992-d2b9444408cc?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Quads · Glutes · Hamstrings',
    ),
    GymEquipment(
      id: 'eq2',
      name: 'Standing Press Station',
      category: 'Compound Upper-Body',
      description:
          'An open barbell station for standing presses — no rack arms overhead, so the bar is '
          'lifted from the floor or a low rack into the starting position.',
      howToUse: [
        'Clean the bar to shoulder height or unrack it from a low set of hooks.',
        'Brace your core and press straight overhead, moving your head back slightly to clear the bar.',
        'Lower back to the shoulders under control before the next rep.',
      ],
      safetyTips: [
        'Keep the bar path close to your face on the way up.',
        'Avoid leaning back excessively — brace the core instead.',
        'Use a lighter warm-up set to confirm the bar path before loading up.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1517344884509-a0c97ec11bcc?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Shoulders · Triceps',
    ),
    GymEquipment(
      id: 'eq3',
      name: 'Adjustable Bench',
      category: 'Isolation Upper-Body',
      description:
          'A flat-to-incline bench used to support single-arm or bent-over dumbbell work, letting you '
          'brace one side of the body while the other moves freely.',
      howToUse: [
        'Set the bench flat or at a slight incline depending on the exercise.',
        'Brace your supporting knee and hand on the bench for a bent-over row.',
        'Keep your back flat and pull with your elbow, not your hand.',
      ],
      safetyTips: [
        'Check the incline pin is fully locked before loading weight.',
        'Keep the working weight close to the bench, not extended out.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Back · Chest · Shoulders',
    ),
    GymEquipment(
      id: 'eq4',
      name: 'Dumbbell Rack',
      category: 'Isolation Upper-Body',
      description:
          'A tiered rack holding paired dumbbells across a full weight range, used for rows, presses, '
          'curls, and most single-limb accessory work.',
      howToUse: [
        'Select a pair from the rack matching the exercise and rep target.',
        'Return dumbbells to their matching slot after your set.',
        'Choose a weight that lets you complete every rep with control.',
      ],
      safetyTips: [
        'Lift dumbbells off the rack with a neutral spine, not a rounded back.',
        'Re-rack with both hands rather than dropping them.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1638536532686-d610adfc8e5c?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Full body accessory work',
    ),
    GymEquipment(
      id: 'eq5',
      name: 'Cable Crossover Machine',
      category: 'Cable & Machine',
      description:
          'A dual-tower cable station with adjustable pulley height, used for crossovers, face pulls, '
          'tricep pushdowns, and other constant-tension cable work.',
      howToUse: [
        'Select the pin weight and pulley height for your exercise.',
        'Keep tension on the cable throughout the full range of motion.',
        'Move slowly through the stretch position rather than letting the weight stack slam.',
      ],
      safetyTips: [
        'Check the carabiner clip is fully closed before pulling.',
        'Stand with a staggered stance for stability on heavier pulls.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1540497077202-7c8a3999166f?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Chest · Back · Shoulders',
    ),
    GymEquipment(
      id: 'eq6',
      name: 'Treadmill',
      category: 'Cardio',
      description:
          'A motorised running belt with adjustable speed and incline, used for warm-ups, steady-state '
          'cardio, or interval work.',
      howToUse: [
        'Straddle the belt and start it moving before stepping on.',
        'Clip the safety key to your clothing before you begin.',
        'Increase speed gradually rather than jumping straight to pace.',
      ],
      safetyTips: [
        'Never step off a moving belt from the front — reduce speed to zero first.',
        'Keep the safety key attached at all times.',
      ],
      imageUrl: 'https://images.unsplash.com/photo-1576678927484-cc907957088c?auto=format&fit=crop&w=900&q=80',
      muscleGroup: 'Cardiovascular',
    ),
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

  // ---- Module 5: Progress & Reports (report-specific series) ----------
  static const heightCm = 170;

  static final weightHistory = <WeightEntry>[
    WeightEntry(DateTime.now().subtract(const Duration(days: 49)), 60.4),
    WeightEntry(DateTime.now().subtract(const Duration(days: 42)), 60.1),
    WeightEntry(DateTime.now().subtract(const Duration(days: 35)), 59.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 28)), 59.3),
    WeightEntry(DateTime.now().subtract(const Duration(days: 21)), 58.9),
    WeightEntry(DateTime.now().subtract(const Duration(days: 14)), 58.6),
    WeightEntry(DateTime.now().subtract(const Duration(days: 7)), 58.3),
    WeightEntry(DateTime.now(), 58.0),
  ];

  static const muscleGroupSplit = <MuscleGroupShare>[
    MuscleGroupShare('Legs', 0.42),
    MuscleGroupShare('Back', 0.24),
    MuscleGroupShare('Chest', 0.18),
    MuscleGroupShare('Shoulders', 0.16),
  ];

  static const sessionsPerWeek = <int>[3, 4, 3, 5, 4, 4, 5];
  static const sessionWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];

  static const pointsHistory = <int>[180, 220, 195, 260, 240, 310, 275, 290];
  static const pointsWeekLabels = <String>['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'];

  // ---- Module 3 -------------------------------------------------------
  static const points = 1840;
  static const streak = 12;
  static const longestStreak = 21;

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

  // ---- Module 4 -------------------------------------------------------
  static final transactions = <Transaction>[
    Transaction('TXN-2087', 'Coaching session', 140.00,
        DateTime.now().subtract(const Duration(days: 2)), 'Cleared'),
    Transaction('TXN-2041', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 12)), 'Cleared'),
    Transaction('TXN-1988', 'Coaching session', 120.00,
        DateTime.now().subtract(const Duration(days: 26)), 'Cleared'),
    Transaction('TXN-1902', 'Membership renewal', 89.00,
        DateTime.now().subtract(const Duration(days: 42)), 'Cleared'),
  ];

  /// The refund policy window (AD-M4.4): only charges within this many days
  /// are eligible. TXN-2087 above is deliberately recent so the demo can
  /// show both the eligible and the policy-locked states.
  static const refundWindowDays = 7;

  static const currentPlanId = 'premium';

  static const membershipPlans = <MembershipPlan>[
    MembershipPlan(
      'basic',
      'Basic',
      49,
      'Everything you need to train smart.',
      [
        'AI form tracking and rep counting',
        'Full gym floor access',
        'Weekly progress reports',
        'Community leaderboard',
      ],
    ),
    MembershipPlan(
      'premium',
      'Premium',
      89,
      "Most members' favourite.",
      [
        'Everything in Basic',
        'Book certified coaches',
        'Deep-dive posture and volume analytics',
        'Priority reward-shop drops',
      ],
      popular: true,
    ),
    MembershipPlan(
      'elite',
      'Elite',
      149,
      'Train with a coach in your corner.',
      [
        'Everything in Premium',
        '2 free coaching sessions every month',
        'Priority booking slots',
        '2x gamification points',
      ],
    ),
  ];

  // ---- Module 7 / 8 ---------------------------------------------------
  static final coaches = <Coach>[
    Coach(
      id: 'c1',
      name: 'Jason Lim',
      specialty: 'Strength and Conditioning',
      specializationTags: const ['Strength Training', 'Powerlifting', 'Beginner Friendly'],
      rating: 4.8,
      reviews: 47,
      bio:
          'Six years coaching compound lifts, with a focus on safe progression for beginners. '
          'I care most about you leaving every session moving better than you arrived.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1633332755192-727a05c4013d?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Kulim',
      fee: 120,
      yearsExperience: 6,
      sessionsCompleted: 312,
      responseTime: 'Usually responds within 2 hours',
      topReviews: [
        CoachReview('Daniel Wong', 5, 'Jason completely fixed my deadlift form in two sessions.',
            DateTime.now().subtract(const Duration(days: 14))),
        CoachReview('Farid Zainal', 5, 'Patient and clear with cues. Highly recommend for beginners.',
            DateTime.now().subtract(const Duration(days: 30))),
      ],
    ),
    Coach(
      id: 'c2',
      name: 'Priya Menon',
      specialty: 'Rehabilitation and Mobility',
      specializationTags: const ['Injury Recovery', 'Mobility', 'Physiotherapy'],
      rating: 4.9,
      reviews: 33,
      bio:
          'Physiotherapy background, specialising in returning to training after injury. '
          'Programming is built around what your body can safely handle this week, not last year.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1594381898411-846e7d193883?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Sungai Petani',
      fee: 140,
      yearsExperience: 8,
      sessionsCompleted: 260,
      responseTime: 'Usually responds within 1 hour',
      topReviews: [
        CoachReview('Wei Ling Tan', 5, 'Helped me return to squatting pain-free after a knee injury.',
            DateTime.now().subtract(const Duration(days: 8))),
        CoachReview('Nurul Huda', 5, 'Extremely knowledgeable, explains the why behind every drill.',
            DateTime.now().subtract(const Duration(days: 22))),
      ],
    ),
    Coach(
      id: 'c3',
      name: 'Hafiz Aziz',
      specialty: 'Hypertrophy',
      specializationTags: const ['Bodybuilding', 'Hypertrophy', 'Nutrition Coaching'],
      rating: 4.6,
      reviews: 58,
      bio:
          'Bodybuilding-oriented programming and technique refinement. '
          'I track your numbers every session so progression is never a guess.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1567013127542-490d757e51fc?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Kulim',
      fee: 110,
      yearsExperience: 4,
      sessionsCompleted: 401,
      responseTime: 'Usually responds within 3 hours',
      topReviews: [
        CoachReview('Daniel Wong', 4, 'Great programming, gym can get noisy during peak hours though.',
            DateTime.now().subtract(const Duration(days: 5))),
        CoachReview('Farid Zainal', 5, 'Put on visible size in 8 weeks following his plan.',
            DateTime.now().subtract(const Duration(days: 40))),
      ],
    ),
    Coach(
      id: 'c4',
      name: 'Michelle Chan',
      specialty: 'Calisthenics',
      specializationTags: const ['Calisthenics', 'Mobility', 'Skill Progressions'],
      rating: 4.7,
      reviews: 21,
      bio:
          'Bodyweight progressions from first pull-up to advanced skills. '
          'Every plan is broken into small, testable milestones so you always know what to work on next.',
      verified: true,
      imageUrl:
          'https://images.unsplash.com/photo-1548690312-e3b507d8c110?auto=format&fit=crop&w=400&q=80',
      branch: 'GainPath Sungai Petani',
      fee: 130,
      yearsExperience: 5,
      sessionsCompleted: 148,
      responseTime: 'Usually responds within 4 hours',
      topReviews: [
        CoachReview('Wei Ling Tan', 5, 'Got my first strict pull-up under her programme.',
            DateTime.now().subtract(const Duration(days: 10))),
        CoachReview('Nurul Huda', 4, 'Sessions are tough but she scales everything well.',
            DateTime.now().subtract(const Duration(days: 26))),
      ],
    ),
  ];

  /// The single source of truth for every booking in the system, coach or
  /// member side. `memberBookings` and `coachRoster` below are filtered
  /// *views* over this one list, not separate data — Jason Lim (c1) and
  /// ZhengYang's actual shared session is one `Booking` object here, not
  /// two disconnected copies that could drift out of sync. That's what
  /// makes coach↔member messaging real: a reply either side adds lands in
  /// the same `messages` list the other side reads.
  static final allBookings = <Booking>[
    Booking(
      id: 'bk1',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().add(const Duration(days: 2, hours: 3)),
      branch: 'GainPath Kulim',
      status: 'Confirmed',
      fee: 120,
      messages: [
        BookingMessage('Member', 'Hi Jason, should I bring my own knee sleeves?',
            DateTime.now().subtract(const Duration(hours: 5))),
        BookingMessage(
            'Coach',
            'Not necessary, but bring them if you have them — we will be doing heavy squats.',
            DateTime.now().subtract(const Duration(hours: 4))),
      ],
    ),
    Booking(
      id: 'bk2',
      coachId: 'c2',
      coachName: 'Priya Menon',
      memberName: 'ZhengYang',
      start: DateTime.now().add(const Duration(days: 6)),
      branch: 'GainPath Sungai Petani',
      status: 'Confirmed',
      fee: 140,
    ),
    Booking(
      id: 'bk3',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 9)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
      notes: 'Good squat depth this session. Work on keeping the chest up during the ascent.',
      rated: true,
    ),
    Booking(
      id: 'bk4',
      coachId: 'c3',
      coachName: 'Hafiz Aziz',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 20)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 110,
    ),
    Booking(
      id: 'bk5',
      coachId: 'c4',
      coachName: 'Michelle Chan',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 3)),
      branch: 'GainPath Sungai Petani',
      status: 'Cancelled',
      fee: 130,
      cancellationReason: 'Member requested — scheduling conflict.',
    ),
    Booking(
      id: 'bk6',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().add(const Duration(days: 2, hours: 5)),
      branch: 'GainPath Kulim',
      status: 'Confirmed',
      fee: 120,
      messages: [
        BookingMessage('Member', 'Can we push my session 30 minutes later?',
            DateTime.now().subtract(const Duration(hours: 20))),
      ],
    ),
    Booking(
      id: 'bk7',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().add(const Duration(days: 4)),
      branch: 'GainPath Kulim',
      status: 'Pending',
      fee: 120,
    ),
    Booking(
      id: 'bk8',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 1)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    // ---- Additional history for Jason Lim (c1), spanning the last ~7
    // weeks, so the Earnings screen's weekly chart reflects real booking
    // dates rather than an illustrative static array. Deliberately spread
    // 2-3 sessions per week rather than aligned to exact week boundaries —
    // the chart buckets these by real calendar week itself, so the exact
    // spread only needs to be plausible, not hand-aligned.
    Booking(
      id: 'bk9',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 4)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk10',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 12)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk11',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 15)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk12',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 18)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk13',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 22)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk14',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 25)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk15',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Aina Rahman',
      start: DateTime.now().subtract(const Duration(days: 26)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk16',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 29)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk17',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Farid Zainal',
      start: DateTime.now().subtract(const Duration(days: 33)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk18',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'ZhengYang',
      start: DateTime.now().subtract(const Duration(days: 36)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk19',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Kevin Tan',
      start: DateTime.now().subtract(const Duration(days: 39)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk20',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Nurul Huda',
      start: DateTime.now().subtract(const Duration(days: 43)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk21',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Daniel Wong',
      start: DateTime.now().subtract(const Duration(days: 46)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
    Booking(
      id: 'bk22',
      coachId: 'c1',
      coachName: 'Jason Lim',
      memberName: 'Aina Rahman',
      start: DateTime.now().subtract(const Duration(days: 47)),
      branch: 'GainPath Kulim',
      status: 'Completed',
      fee: 120,
    ),
  ];

  /// A member's own bookings, across every coach.
  static List<Booking> get memberBookings =>
      allBookings.where((b) => b.memberName == memberName).toList();

  /// The signed-in coach's own client roster, across every member.
  static List<Booking> get coachRoster =>
      allBookings.where((b) => b.coachId == currentCoach.id).toList();

  // ---- Module 6 -------------------------------------------------------
  static const chatSeed = <ChatMessage>[
    ChatMessage('How do I stop my knees caving in during squats?', true),
    ChatMessage(
        'Knee valgus usually comes from weak glute medius or a stance that is too narrow. Try widening your stance slightly and consciously pushing your knees out as you descend. Adding banded side-steps before your session can help too.\n\nThis is general educational guidance, not medical advice.',
        false),
  ];

  static final savedAdvice = <String>[
    'Widen your stance slightly and push the knees out on the descent.',
    'Aim for a neutral spine on deadlifts, brace before the pull.',
    'Progressive overload works best in small weekly increments.',
  ];

  static const faqPrompts = <FaqPrompt>[
    FaqPrompt(
      'How do I fix my squat depth?',
      'Depth usually gets limited by tight ankles or hips rather than weak '
      'legs. Try elevating your heels slightly on a small plate and pause '
      'for two seconds at the bottom of each rep to build control there.\n\n'
      'This is general educational guidance, not medical advice.',
    ),
    FaqPrompt(
      'What should I eat after a workout?',
      'Aim for a mix of protein and carbs within a couple of hours of '
      'training — think grilled chicken with rice, or a protein shake with '
      'a banana. Protein supports muscle repair, carbs refill the energy '
      'you just used.\n\n'
      'This is general nutrition guidance, not a personalised meal plan.',
    ),
    FaqPrompt(
      'How many rest days do I need per week?',
      'Most people training 4-5 days a week do well with at least 1-2 full '
      'rest days, plus lighter days for any muscle group you hit hard. '
      'Watch for ongoing soreness or dropping performance — that is '
      'usually a sign to add another rest day.\n\n'
      'This is general guidance, not medical advice.',
    ),
    FaqPrompt(
      'Why do my knees hurt during lunges?',
      'Knee discomfort in lunges is often about tracking — check that your '
      'front knee stays roughly over your ankle rather than drifting '
      'inward or past your toes, and shorten your stride if it still '
      'bothers you.\n\n'
      'If the pain is sharp or persistent, stop and see a physiotherapist '
      'rather than pushing through it.',
    ),
    FaqPrompt(
      'How do I know when to increase my weights?',
      'A good rule of thumb: if you can complete all your sets and reps '
      'with good form and have 2+ reps left in the tank, add a small '
      'amount of weight next session. Keep increases small and consistent '
      'rather than jumping up all at once.\n\n'
      'This is general programming guidance, not personalised coaching.',
    ),
  ];

  static String buildProgressAuditReply() {
    final formChange = postureTrend.last - postureTrend.first;
    final volumeChangePct =
        ((volumeTrend.last - volumeTrend.first) / volumeTrend.first * 100).round();
    final weakest = history.reduce((a, b) => a.accuracy < b.accuracy ? a : b);
    return 'Over the last ${postureTrend.length} sessions your average form score '
        'is up $formChange points, and lifting volume has grown about '
        '$volumeChangePct% over that span. ${weakest.exercise} is currently your '
        'lowest-scoring lift at ${weakest.accuracy}%, so that is the best place to '
        'focus next.\n\n'
        'This is general educational guidance, not medical advice.';
  }

  // ---- Module 10 (AD-M10.1/10.2 — Availability & scheduling limits) ---
  static final workingDays = <WorkingDay>[
    WorkingDay('Monday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Tuesday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Wednesday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 17, minute: 0), true),
    WorkingDay('Thursday', const TimeOfDay(hour: 10, minute: 0), const TimeOfDay(hour: 19, minute: 0), true),
    WorkingDay('Friday', const TimeOfDay(hour: 8, minute: 0), const TimeOfDay(hour: 15, minute: 0), true),
    WorkingDay('Saturday', const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 13, minute: 0), true),
    WorkingDay('Sunday', const TimeOfDay(hour: 9, minute: 0), const TimeOfDay(hour: 13, minute: 0), false),
  ];

  static final blockedSlots = <BlockedSlot>[
    BlockedSlot(
      id: 'bl1',
      type: BlockType.leave,
      reason: 'Medical leave',
      date: DateTime.now().add(const Duration(days: 5)),
      fullDay: true,
    ),
    BlockedSlot(
      id: 'bl2',
      type: BlockType.breakTime,
      reason: 'Lunch break',
      date: DateTime.now().add(const Duration(days: 1)),
      fullDay: false,
      startTime: const TimeOfDay(hour: 13, minute: 0),
      endTime: const TimeOfDay(hour: 14, minute: 0),
    ),
  ];

  static int dailyBookingCap = 4;
  static int advanceBookingDays = 30;

  // ---- Module 11 ------------------------------------------------------
  /// Every coach account here has a matching public profile in
  /// [coaches] (matched by name) except newly `Invited` ones, which
  /// haven't completed onboarding yet and so have no profile there —
  /// the Coaches admin page shows those with a "not yet onboarded" state.
  static final users = <UserAccount>[
    UserAccount('ZhengYang', 'zhengyang@example.com', 'Member', 'Active'),
    UserAccount('Daniel Wong', 'daniel.w@example.com', 'Member', 'Active'),
    UserAccount('Farid Zainal', 'farid.z@example.com', 'Member', 'Suspended'),
    UserAccount('Jason Lim', 'jason.lim@furyfitness.my', 'Coach', 'Verified',
        branch: 'GainPath Kulim', specialty: 'Strength and Conditioning'),
    UserAccount('Priya Menon', 'priya.m@furyfitness.my', 'Coach', 'Verified',
        branch: 'GainPath Sungai Petani', specialty: 'Rehabilitation and Mobility'),
    UserAccount('Hafiz Aziz', 'hafiz.a@furyfitness.my', 'Coach', 'Pending',
        branch: 'GainPath Kulim', specialty: 'Hypertrophy'),
    UserAccount('Michelle Chan', 'michelle.c@furyfitness.my', 'Coach', 'Verified',
        branch: 'GainPath Sungai Petani', specialty: 'Calisthenics'),
    ..._generatedMembers(),
  ];

  /// A realistically-sized member roster (~55 accounts) so the Members
  /// admin page has enough rows to actually demonstrate search and
  /// pagination — the 3 hand-authored members above aren't enough on
  /// their own. Deterministic, not random, so the list is stable and
  /// reviewable.
  static List<UserAccount> _generatedMembers() {
    const firstNames = [
      'Aisyah', 'Kumar', 'Siti', 'Arif', 'Ravi', 'Azlan', 'Fatimah', 'Choon Hui',
      'Suresh', 'Amirah', 'Zulkifli', 'Mei Ling', 'Chong', 'Ismail', 'Kavitha',
      'Yusof', 'Chandra', 'Aiman', 'Balqis', 'Haziq', 'Sofea', 'Danish', 'Iman',
      'Naveen', 'Aina', 'Firdaus', 'Poh Ling', 'Shamsul',
    ];
    const lastNames = [
      'Rahman', 'Subramaniam', 'Yusoff', 'Lee', 'Krishnan', 'Ibrahim', 'Tan',
      'Osman', 'Pillai', 'Ong', 'Hassan', 'Chew', 'Nair', 'Abdullah', 'Lim',
      'Ganesan', 'Wan', 'Sivakumar', 'Bakar', 'Loh',
    ];
    final members = <UserAccount>[];
    var idx = 0;
    for (var i = 0; i < firstNames.length; i++) {
      for (var j = 0; j < 2; j++) {
        final last = lastNames[(i * 2 + j) % lastNames.length];
        final name = '${firstNames[i]} $last';
        final email =
            '${firstNames[i].toLowerCase().replaceAll(' ', '')}.${last.toLowerCase()}$idx@example.com';
        final status = idx % 8 == 0 ? 'Suspended' : 'Active';
        members.add(UserAccount(name, email, 'Member', status));
        idx++;
      }
    }
    return members;
  }

  /// AD-M11.4 — `Broadcast` records. Previously the Announcements screen
  /// was write-only: a compose form with no way to see what had already
  /// been published or when it stops showing. Mutable so publishing a
  /// new one actually appends here instead of just toasting.
  static final announcements = <Announcement>[
    Announcement(
      id: 'an1',
      title: 'Merdeka Day operating hours',
      body: '31 August: all branches open 8am-2pm only. Normal hours resume 1 September.',
      validFrom: DateTime.now().subtract(const Duration(days: 2)),
      validTo: DateTime.now().add(const Duration(days: 5)),
    ),
    Announcement(
      id: 'an2',
      title: 'New squat rack at Sungai Petani',
      body: 'A second squat rack is now installed at the Sungai Petani branch to reduce peak-hour waiting.',
      validFrom: DateTime.now().subtract(const Duration(days: 20)),
      validTo: DateTime.now().subtract(const Duration(days: 6)),
    ),
  ];

  // ---- Module 12 ------------------------------------------------------
  static const adminStats = <List<String>>[
    ['Active members', '284', '+12 this month'],
    ['Verified coaches', '9', '1 pending review'],
    ['Sessions this week', '1,206', '+8% vs last week'],
    ['Revenue this month', 'RM 24,180', '+5% vs last month'],
  ];

  /// AD-M11.1-adjacent — formalises the `Branch` entity from the data
  /// dictionary, which previously only existed as bare strings scattered
  /// across `Coach.branch` / `Booking.branch`. Member and coach counts
  /// are computed live from those same records rather than duplicated
  /// here, so they can never drift out of sync with the roster.
  static const branches = <Branch>[
    Branch(
      id: 'br1',
      name: 'GainPath Kulim',
      address: '12 Jalan Kulim Perdana, 09000 Kulim, Kedah',
      contactPhone: '+60 4-490 1122',
      isActive: true,
    ),
    Branch(
      id: 'br2',
      name: 'GainPath Sungai Petani',
      address: '88 Jalan Ibrahim, 08000 Sungai Petani, Kedah',
      contactPhone: '+60 4-421 5580',
      isActive: true,
    ),
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

  /// `[name, avgScorePct including '%', category]`. The tier ("High" /
  /// "Moderate" / "Low") used to be a 3rd stored field, but that made it
  /// impossible to actually implement AD-M13.1's "Configure Risk
  /// Threshold" — a stored tier can't react to an admin moving a
  /// threshold slider. Tier is now always computed from [postureRiskThreshold]
  /// via [riskTierFor] instead.
  static const riskExercises = <List<String>>[
    ['Romanian Deadlift', '61%', 'Lower Body'],
    ['Barbell Squat', '68%', 'Lower Body'],
    ['Overhead Press', '74%', 'Upper Body'],
    ['Lunges', '76%', 'Lower Body'],
    ['Dumbbell Row', '86%', 'Upper Body'],
    ['Plank', '82%', 'Core'],
  ];

  /// AD-M13.1 — `RiskThresholdConfig.postureRiskThresholdPercent`. Mutable
  /// so the admin's slider genuinely reclassifies exercises live rather
  /// than just changing a label.
  static int postureRiskThreshold = 70;

  static String riskTierFor(int avgScorePct) {
    if (avgScorePct < postureRiskThreshold) return 'High';
    if (avgScorePct < postureRiskThreshold + 12) return 'Moderate';
    return 'Low';
  }

  static const atRiskLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'Priya Menon'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Jason Lim'),
    RiskLead('Wei Ling Tan', 'Overhead Press', 65, 'Hafiz Aziz'),
  ];

  /// AD-M13.2 — leads not yet surfaced. Tapping "Refresh queue" reveals
  /// the next one, simulating the `LeadEvaluator` background job the
  /// sequence diagram describes generating new leads over time, since
  /// there's no real background job here to generate them.
  static const trainerLeadsPool = <RiskLead>[
    RiskLead('Farid Zainal', 'Lunges', 66, 'Michelle Chan'),
    RiskLead('Kavitha Raj', 'Dumbbell Row', 63, 'Priya Menon'),
  ];

  /// Illustrative — the platform doesn't snapshot a historical form-score
  /// series anywhere, so this is a plausible 8-week trend for the
  /// Posture Accuracy Trend report's line chart, not derived data.
  static const postureWeeklyTrend = <int>[71, 73, 72, 75, 77, 76, 79, 81];

  /// Illustrative distribution of the full member base by dropout-risk
  /// tier, sized against the same ~284-member figure the Revenue report
  /// already quotes elsewhere — the 3 `atRiskLeads` above are a sample
  /// of the "High risk" slice, not the whole picture.
  static const retentionRiskMix = <ChartSlice>[
    ChartSlice('Low risk', 214),
    ChartSlice('Medium risk', 47),
    ChartSlice('High risk', 23),
  ];

  /// Illustrative weekly redemption counts for the Reward Redemptions
  /// trend chart.
  static const rewardWeeklyRedemptions = <int>[9, 11, 14, 10, 16, 19, 17, 22];

  /// Real counts behind the "Most claimed rewards" breakdown — matches
  /// the 118 total redeemed figure already shown in the Rewards report.
  static const rewardRedemptionMix = <ChartSlice>[
    ChartSlice('Protein Shake Voucher', 61),
    ChartSlice('Gym Towel', 33),
    ChartSlice('Free Day Pass', 17),
    ChartSlice('Water Bottle', 7),
  ];

  /// Illustrative — how many members currently sit in each workout-streak
  /// bucket, for the Gamification Engagement donut.
  static const streakDistribution = <ChartSlice>[
    ChartSlice('0-3 days', 89),
    ChartSlice('4-7 days', 62),
    ChartSlice('1-2 weeks', 41),
    ChartSlice('2+ weeks', 24),
  ];

  static const contentLeads = <RiskLead>[
    RiskLead('Nurul Huda', 'Romanian Deadlift', 58, 'RDL Form Basics'),
    RiskLead('Daniel Wong', 'Barbell Squat', 62, 'Fixing Knee Valgus'),
  ];

  static const contentLeadsPool = <RiskLead>[
    RiskLead('Chong Wei Ming', 'Lunges', 66, 'Lunge Mechanics Explained'),
  ];

  /// AD-M13.1 — "compare leaderboard against tutorial library, filter to
  /// missing exercise videos." Computed live from [riskExercises] and
  /// [tutorials] rather than a separately hand-curated list, so it can
  /// never drift out of sync with either — the old static version listed
  /// "Bulgarian Split Squat", which isn't even a tracked exercise.
  static List<List<String>> get contentGaps {
    final covered = tutorials.map((t) => t.coversExercise).where((name) => name.isNotEmpty).toSet();
    return riskExercises
        .where((e) => !covered.contains(e[0]))
        .map((e) => [e[0], e[1], 'No tutorial linked'])
        .toList();
  }

  static final tutorials = <TutorialVideo>[
    TutorialVideo(
        title: 'Squat Form Fundamentals',
        category: 'Compound Lower-Body',
        status: 'Active',
        coversExercise: 'Barbell Squat'),
    TutorialVideo(title: 'Fixing Knee Valgus', category: 'Compound Lower-Body', status: 'Active'),
    TutorialVideo(
        title: 'RDL Form Basics',
        category: 'Compound Lower-Body',
        status: 'Active',
        coversExercise: 'Romanian Deadlift'),
    TutorialVideo(
        title: 'Overhead Press Setup',
        category: 'Compound Upper-Body',
        status: 'Active',
        coversExercise: 'Overhead Press'),
  ];

  // ---- Module 11: Routine templates (RoutineBlueprint) -----------------
  static final routineTemplates = <RoutineBlueprint>[
    RoutineBlueprint(
      id: 'rt1',
      name: 'Beginner Full Body',
      level: 'Beginner',
      assignedMembers: 62,
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Barbell Squat', 3, 8),
          RoutineExerciseRef('Dumbbell Row', 3, 12),
          RoutineExerciseRef('Plank', 3, 30),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Romanian Deadlift', 3, 10),
          RoutineExerciseRef('Overhead Press', 3, 8),
          RoutineExerciseRef('Lat Pulldown', 3, 12),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt2',
      name: 'Push / Pull / Legs',
      level: 'Intermediate',
      assignedMembers: 84,
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Overhead Press', 4, 8),
          RoutineExerciseRef('Incline Bench Press', 4, 10),
          RoutineExerciseRef('Tricep Pushdown', 3, 12),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Dumbbell Row', 4, 10),
          RoutineExerciseRef('Lat Pulldown', 4, 10),
          RoutineExerciseRef('Bicep Curl', 3, 12),
        ]),
        RoutineDay(3, [
          RoutineExerciseRef('Barbell Squat', 4, 8),
          RoutineExerciseRef('Romanian Deadlift', 3, 10),
          RoutineExerciseRef('Leg Press', 3, 12),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt3',
      name: 'Upper / Lower Split',
      level: 'Intermediate',
      assignedMembers: 47,
      days: [
        RoutineDay(1, [
          RoutineExerciseRef('Overhead Press', 4, 8),
          RoutineExerciseRef('Dumbbell Row', 4, 10),
        ]),
        RoutineDay(2, [
          RoutineExerciseRef('Barbell Squat', 4, 8),
          RoutineExerciseRef('Romanian Deadlift', 4, 10),
        ]),
      ],
    ),
    RoutineBlueprint(
      id: 'rt4',
      name: '5-Day Body Part Split',
      level: 'Advanced',
      assignedMembers: 19,
      days: [
        RoutineDay(1, [RoutineExerciseRef('Barbell Squat', 5, 6)]),
        RoutineDay(2, [RoutineExerciseRef('Overhead Press', 5, 6)]),
        RoutineDay(3, [RoutineExerciseRef('Dumbbell Row', 5, 8)]),
        RoutineDay(4, [RoutineExerciseRef('Romanian Deadlift', 5, 6)]),
        RoutineDay(5, [RoutineExerciseRef('Incline Bench Press', 5, 8)]),
      ],
    ),
  ];
}
