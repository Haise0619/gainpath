import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/features/analytics/data/in_memory/in_memory_analytics_repository.dart';
import 'package:gainpath/features/analytics/domain/repositories/analytics_repository.dart';
import 'package:gainpath/features/chatbot/data/in_memory/in_memory_chat_repository.dart';
import 'package:gainpath/features/chatbot/domain/repositories/chat_repository.dart';
import 'package:gainpath/features/coaching/data/in_memory/in_memory_availability_repository.dart';
import 'package:gainpath/features/coaching/data/in_memory/in_memory_booking_repository.dart';
import 'package:gainpath/features/coaching/domain/repositories/availability_repository.dart';
import 'package:gainpath/features/coaching/domain/repositories/booking_repository.dart';
import 'package:gainpath/features/content/data/in_memory/in_memory_content_repository.dart';
import 'package:gainpath/features/content/domain/repositories/content_repository.dart';
import 'package:gainpath/features/gamification/data/in_memory/in_memory_gamification_repository.dart';
import 'package:gainpath/features/gamification/domain/repositories/gamification_repository.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_coach_repository.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_member_profile_repository.dart';
import 'package:gainpath/features/identity/data/in_memory/in_memory_user_account_repository.dart';
import 'package:gainpath/features/identity/domain/repositories/coach_repository.dart';
import 'package:gainpath/features/identity/domain/repositories/member_profile_repository.dart';
import 'package:gainpath/features/identity/domain/repositories/user_account_repository.dart';
import 'package:gainpath/features/membership/data/in_memory/in_memory_membership_repository.dart';
import 'package:gainpath/features/membership/domain/repositories/membership_repository.dart';
import 'package:gainpath/features/recommendation/data/in_memory/in_memory_recommendation_repository.dart';
import 'package:gainpath/features/recommendation/domain/repositories/recommendation_repository.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_equipment_repository.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_routine_template_repository.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_tutorial_repository.dart';
import 'package:gainpath/features/workout/data/in_memory/in_memory_workout_repository.dart';
import 'package:gainpath/features/workout/domain/repositories/equipment_repository.dart';
import 'package:gainpath/features/workout/domain/repositories/routine_template_repository.dart';
import 'package:gainpath/features/workout/domain/repositories/tutorial_repository.dart';
import 'package:gainpath/features/workout/domain/repositories/workout_repository.dart';

/// Composition root for data access. Swap the in-memory implementations for
/// Firebase-backed ones here without touching any screen.
class AppRepositories extends StatelessWidget {
  const AppRepositories({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MemberProfileRepository>(create: (_) => InMemoryMemberProfileRepository()),
        RepositoryProvider<CoachRepository>(create: (_) => InMemoryCoachRepository()),
        RepositoryProvider<UserAccountRepository>(create: (_) => InMemoryUserAccountRepository()),
        RepositoryProvider<WorkoutRepository>(create: (_) => InMemoryWorkoutRepository()),
        RepositoryProvider<EquipmentRepository>(create: (_) => InMemoryEquipmentRepository()),
        RepositoryProvider<TutorialRepository>(create: (_) => InMemoryTutorialRepository()),
        RepositoryProvider<RoutineTemplateRepository>(create: (_) => InMemoryRoutineTemplateRepository()),
        RepositoryProvider<GamificationRepository>(create: (_) => InMemoryGamificationRepository()),
        RepositoryProvider<BookingRepository>(create: (_) => InMemoryBookingRepository()),
        RepositoryProvider<AvailabilityRepository>(create: (_) => InMemoryAvailabilityRepository()),
        RepositoryProvider<MembershipRepository>(create: (_) => InMemoryMembershipRepository()),
        RepositoryProvider<ChatRepository>(create: (_) => InMemoryChatRepository()),
        RepositoryProvider<AnalyticsRepository>(create: (_) => InMemoryAnalyticsRepository()),
        RepositoryProvider<RecommendationRepository>(create: (_) => InMemoryRecommendationRepository()),
        RepositoryProvider<ContentRepository>(create: (_) => InMemoryContentRepository()),
      ],
      child: child,
    );
}
