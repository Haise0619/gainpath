import 'package:gainpath_data/analytics.dart';
import 'package:gainpath_data/chatbot.dart';
import 'package:gainpath_data/coaching.dart';
import 'package:gainpath_data/content.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_data/membership.dart';
import 'package:gainpath_data/recommendation.dart';
import 'package:gainpath_data/src/fakes/mock_data_session.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:test/test.dart';

// Each case exercises a real mutation, including nested mutable entities/lists.
// Sharing a seed globally, ignoring injection, or copying an injected seed
// breaks the isolation or sharing behavior asserted here.
void verifyScope<R>(
  String name,
  R Function({MockDataSession? session}) create,
  void Function(R) mutate,
  Object Function(R) observe,
) {
  group(name, () {
    test('default repositories isolate mutations and start fresh', () {
      final writer = create();
      final other = create();
      final original = observe(other);

      mutate(writer);

      expect(observe(writer), isNot(original));
      expect(observe(other), original);
      expect(observe(create()), original);
    });

    test('only an explicitly shared session sees updates', () {
      final session = MockDataSession();
      final writer = create(session: session);
      final reader = create(session: session);
      final separate = create(session: MockDataSession());
      final original = observe(reader);

      mutate(writer);

      expect(observe(writer), isNot(original));
      expect(observe(reader), observe(writer));
      expect(observe(create(session: session)), observe(writer));
      expect(observe(separate), original);
      expect(observe(create(session: MockDataSession())), original);
    });
  });
}

void main() {
  verifyScope<InMemoryAnalyticsRepository>(
    'analytics',
    InMemoryAnalyticsRepository.new,
    (repo) => repo.weightHistory.removeLast(),
    (repo) => repo.weightHistory.length,
  );
  verifyScope<InMemoryChatRepository>(
    'chat',
    InMemoryChatRepository.new,
    (repo) => repo.savedAdvice.add('Session-specific advice'),
    (repo) => repo.savedAdvice.length,
  );
  verifyScope<InMemoryAvailabilityRepository>(
    'availability',
    InMemoryAvailabilityRepository.new,
    (repo) =>
        repo.workingDays.first.start = const LocalTime(hour: 6, minute: 30),
    (repo) => repo.workingDays.first.start,
  );
  verifyScope<InMemoryBookingRepository>(
    'bookings',
    InMemoryBookingRepository.new,
    (repo) => repo.memberBookings.first.messages.clear(),
    (repo) => repo.memberBookings.first.messages.length,
  );
  verifyScope<InMemoryContentRepository>(
    'content',
    InMemoryContentRepository.new,
    (repo) => repo.announcements.removeLast(),
    (repo) => repo.announcements.length,
  );
  verifyScope<InMemoryGamificationRepository>(
    'gamification',
    InMemoryGamificationRepository.new,
    (repo) => repo.addPoints(123),
    (repo) => repo.points,
  );
  verifyScope<InMemoryCoachRepository>(
    'coaches',
    InMemoryCoachRepository.new,
    (repo) => repo.currentCoach.bio = 'Updated within this scope',
    (repo) => repo.currentCoach.bio,
  );
  verifyScope<InMemoryMemberProfileRepository>(
    'member profile',
    InMemoryMemberProfileRepository.new,
    (repo) => repo.memberTrainingFocus.add('Session-specific goal'),
    (repo) => repo.memberTrainingFocus.length,
  );
  verifyScope<InMemoryUserAccountRepository>(
    'accounts',
    InMemoryUserAccountRepository.new,
    (repo) => repo.users.removeLast(),
    (repo) => repo.users.length,
  );
  verifyScope<InMemoryMembershipRepository>(
    'membership',
    InMemoryMembershipRepository.new,
    (repo) => repo.currentPlanId = 'elite',
    (repo) => repo.currentPlanId,
  );
  verifyScope<InMemoryRecommendationRepository>(
    'recommendations',
    InMemoryRecommendationRepository.new,
    (repo) => repo.postureRiskThreshold = 85,
    (repo) => repo.postureRiskThreshold,
  );
  verifyScope<InMemoryEquipmentRepository>(
    'equipment',
    InMemoryEquipmentRepository.new,
    (repo) => repo.gymEquipment.first.safetyTips.clear(),
    (repo) => repo.gymEquipment.first.safetyTips.length,
  );
  verifyScope<InMemoryRoutineTemplateRepository>(
    'routine templates',
    InMemoryRoutineTemplateRepository.new,
    (repo) => repo.routineTemplates.first.days.first.exercises.clear(),
    (repo) => repo.routineTemplates.first.days.first.exercises.length,
  );
  verifyScope<InMemoryTutorialRepository>(
    'tutorials',
    InMemoryTutorialRepository.new,
    (repo) => repo.tutorials.first.title = 'Updated within this scope',
    (repo) => repo.tutorials.first.title,
  );
  verifyScope<InMemoryWorkoutRepository>(
    'workouts',
    InMemoryWorkoutRepository.new,
    (repo) => repo.history.removeLast(),
    (repo) => repo.history.length,
  );

  test('member and coach booking views share edits only within their session',
      () {
    final session = MockDataSession();
    final member = InMemoryBookingRepository(session: session);
    final coach = InMemoryBookingRepository(session: session);
    final booking = member.memberBookings.firstWhere((b) => b.id == 'bk1');
    final coachBooking = coach.coachRoster.firstWhere((b) => b.id == 'bk1');

    booking.messages
        .add(BookingMessage('Member', 'See you soon', DateTime(2026)));
    coachBooking.notes = 'Updated coaching notes';
    coachBooking.status = BookingStatus.completed;

    expect(coachBooking.messages.last.text, 'See you soon');
    expect(booking.notes, 'Updated coaching notes');
    expect(booking.status, BookingStatus.completed);
    expect(member.allBookings.firstWhere((b) => b.id == 'bk1'), same(booking));
    final fresh = InMemoryBookingRepository(session: MockDataSession());
    expect(fresh.memberBookings.first.status, BookingStatus.confirmed);
    expect(fresh.memberBookings.first.notes, isNull);
    expect(fresh.memberBookings.first.messages, hasLength(2));
  });

  test('editing a coach profile updates the shared public directory', () {
    final session = MockDataSession();
    final coach = InMemoryCoachRepository(session: session);
    final directory = InMemoryCoachRepository(session: session);
    coach.currentCoach.fee = 199;

    expect(
        directory.coaches.firstWhere((c) => c.id == coach.currentCoach.id).fee,
        199);
    expect(InMemoryCoachRepository().currentCoach.fee, 120);
  });

  test('tutorial edits refresh content gaps only in the shared session', () {
    final session = MockDataSession();
    final tutorials = InMemoryTutorialRepository(session: session);
    final recommendations = InMemoryRecommendationRepository(session: session);
    final isolated = InMemoryRecommendationRepository();
    expect(recommendations.contentGaps.map((gap) => gap.first),
        contains('Lunges'));

    tutorials.tutorials.add(TutorialVideo(
      title: 'Lunge tutorial',
      category: 'Lower Body',
      status: TutorialStatus.active,
      coversExercise: 'Lunges',
    ));

    expect(recommendations.contentGaps.map((gap) => gap.first),
        isNot(contains('Lunges')));
    expect(isolated.contentGaps.map((gap) => gap.first), contains('Lunges'));
    expect(
        InMemoryRecommendationRepository(session: MockDataSession())
            .contentGaps
            .map((gap) => gap.first),
        contains('Lunges'));
  });

  test('default tutorial edits cannot affect a default recommendation repo',
      () {
    final tutorials = InMemoryTutorialRepository();
    final recommendations = InMemoryRecommendationRepository();
    tutorials.tutorials.clear();

    expect(recommendations.contentGaps.map((gap) => gap.first),
        isNot(contains('Barbell Squat')));
  });

  test('chat audit reads live analytics and workouts from its session', () {
    final session = MockDataSession();
    final chat = InMemoryChatRepository(session: session);
    final other = InMemoryChatRepository();
    final original = chat.buildProgressAuditReply();
    final analytics = InMemoryAnalyticsRepository(session: session);
    final workouts = InMemoryWorkoutRepository(session: session);

    analytics.postureTrend
      ..clear()
      ..addAll([50, 80]);
    analytics.volumeTrend
      ..clear()
      ..addAll([1000, 1500]);
    workouts.history.add(WorkoutRecord('Lunges', DateTime(2026), 10, 20, 5));

    final reply = chat.buildProgressAuditReply();
    expect(reply, contains('last 2 sessions'));
    expect(reply, contains('up 30 points'));
    expect(reply, contains('50%'));
    expect(
        reply, contains('Lunges is currently your lowest-scoring lift at 20%'));
    expect(other.buildProgressAuditReply(), original);
    expect(
        InMemoryChatRepository(session: MockDataSession())
            .buildProgressAuditReply(),
        original);
  });
}
