import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart'
    show BackendConfig, BackendMode, MockDataSession;
import 'package:gainpath_data/analytics.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_data/chatbot.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_data/coaching.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_data/content.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_data/gamification.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/membership.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_data/recommendation.dart';
import 'package:gainpath_domain/recommendation.dart';
import 'package:gainpath_data/workout.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, SessionScope, BookingListRepository;
import '../../infrastructure/firebase/firebase_booking_list_repository.dart';
import '../../infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import '../../infrastructure/firebase/firebase_routine_template_repository.dart';
import '../../infrastructure/firebase/firebase_coach_profile_admin_repository.dart';
import '../../infrastructure/firebase/firebase_coach_availability_repository.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'catalog_edit_session_guard.dart';
import '../../infrastructure/firebase/firebase_announcement_repository.dart';
import '../../infrastructure/firebase/firebase_chatbot_disclaimer_repository.dart';
import '../../infrastructure/firebase/firebase_compliance_document_repository.dart';
import '../../infrastructure/firebase/firebase_admin_account_contact_repository.dart';
import '../../infrastructure/firebase/firebase_equipment_repository.dart';
import '../../infrastructure/local/equipment_image_picker.dart';
import '../../infrastructure/local/account_photo_picker.dart';
import '../../infrastructure/firebase/firebase_admin_member_directory_repository.dart';
import '../../infrastructure/firebase/firebase_reward_catalog_repository.dart';
import '../../infrastructure/firebase/firebase_facility_settings_repository.dart';

/// Composition root for data access. Swap the in-memory implementations for
/// Firebase-backed ones here without touching any screen.
class AppRepositories extends StatefulWidget {
  const AppRepositories({
    super.key,
    required this.child,
    this.config = const BackendConfig(BackendMode.mock),
    this.session,
    this.tutorialRepositoryFactory,
    this.routineRepositoryFactory,
    this.coachRepositoryFactory,
    this.coachAvailabilityFactory,
    this.bookingListFactory,
    this.accountContactFactory,
    this.memberDirectoryFactory,
    this.rewardCatalogFactory,
    this.facilitySettingsFactory,
  });
  final Widget child;
  final BackendConfig config;
  final AuthSession? session;
  final TutorialRepository Function(SessionScope)? tutorialRepositoryFactory;
  final RoutineTemplateRepository Function(SessionScope, TutorialRepository)?
      routineRepositoryFactory;
  final CoachProfileAdminRepository Function(SessionScope, bool Function())?
      coachRepositoryFactory;
  final CoachAvailabilityRepository Function(SessionScope, bool Function())?
      coachAvailabilityFactory;
  final BookingListRepository Function(SessionScope, bool Function())?
      bookingListFactory;
  final AdminAccountContactRepository Function(SessionScope, bool Function())?
      accountContactFactory;
  final AdminMemberDirectoryRepository Function(SessionScope, bool Function())?
      memberDirectoryFactory;
  final RewardCatalogRepository Function(SessionScope, bool Function())?
      rewardCatalogFactory;
  final FacilitySettingsRepository Function(SessionScope, bool Function())?
      facilitySettingsFactory;

  @override
  State<AppRepositories> createState() => _AppRepositoriesState();
}

class _AppRepositoriesState extends State<AppRepositories> {
  late final MockDataSession session = MockDataSession();
  CatalogEditSessionGuard? _catalogGuard;
  CatalogEditSessionGuard? _routineGuard;
  CatalogEditSessionGuard? _coachGuard;
  CatalogEditSessionGuard? _availabilityGuard;
  CatalogEditSessionGuard? _bookingGuard;
  CatalogEditSessionGuard? _announcementGuard;
  CatalogEditSessionGuard? _disclaimerGuard;
  CatalogEditSessionGuard? _complianceGuard;
  CatalogEditSessionGuard? _accountContactGuard;
  CatalogEditSessionGuard? _memberDirectoryGuard;
  CatalogEditSessionGuard? _rewardGuard;
  CatalogEditSessionGuard? _facilityGuard;
  FacilitySettingsRepository _createFacilitySettings(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _facilityGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.facilitySettingsFactory
            ?.call(scope, _facilityGuard!.isCurrent) ??
        FirebaseFacilitySettingsRepository(
            scope: scope, isCurrent: _facilityGuard!.isCurrent);
  }

  RewardCatalogRepository _createRewardCatalog(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _rewardGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.rewardCatalogFactory?.call(scope, _rewardGuard!.isCurrent) ??
        FirebaseRewardCatalogRepository(
            scope: scope, isCurrent: _rewardGuard!.isCurrent);
  }

  AdminMemberDirectoryRepository _createMemberDirectory(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _memberDirectoryGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.memberDirectoryFactory
            ?.call(scope, _memberDirectoryGuard!.isCurrent) ??
        FirebaseAdminMemberDirectoryRepository(
            scope: scope, isCurrent: _memberDirectoryGuard!.isCurrent);
  }

  AdminAccountContactRepository _createAccountContact(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _accountContactGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.accountContactFactory
            ?.call(scope, _accountContactGuard!.isCurrent) ??
        FirebaseAdminAccountContactRepository(
            scope: scope, isCurrent: _accountContactGuard!.isCurrent);
  }

  ComplianceDocumentRepository _createCompliance(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _complianceGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseComplianceDocumentRepository(
        scope: scope, isCurrent: _complianceGuard!.isCurrent);
  }

  ChatbotDisclaimerRepository _createDisclaimer(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _disclaimerGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseChatbotDisclaimerRepository(
        scope: scope, isCurrent: _disclaimerGuard!.isCurrent);
  }

  CatalogEditSessionGuard? _equipmentGuard;
  EquipmentRepository _createEquipment(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _equipmentGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseEquipmentRepository(
        scope: scope, isCurrent: _equipmentGuard!.isCurrent);
  }

  ContentRepository _createAnnouncements(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _announcementGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseAnnouncementRepository(
        scope: scope, isCurrent: _announcementGuard!.isCurrent);
  }

  BookingListRepository _createBookingList(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _bookingGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.bookingListFactory?.call(scope, _bookingGuard!.isCurrent) ??
        FirebaseBookingListRepository(
            scope: scope, isCurrent: _bookingGuard!.isCurrent);
  }

  CoachAvailabilityRepository _createAvailability(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _availabilityGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.coachAvailabilityFactory
            ?.call(scope, _availabilityGuard!.isCurrent) ??
        FirebaseCoachAvailabilityRepository(
            scope: scope, isCurrent: _availabilityGuard!.isCurrent);
  }

  CoachProfileAdminRepository _createCoachDirectory(SessionScope scope) {
    final auth = context.read<AuthBloc>();
    _coachGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return widget.coachRepositoryFactory?.call(scope, _coachGuard!.isCurrent) ??
        FirebaseCoachProfileAdminRepository(
            scope: scope, isCurrent: _coachGuard!.isCurrent);
  }

  TutorialRepository _createCatalog(SessionScope scope) {
    final factory = widget.tutorialRepositoryFactory;
    if (factory != null) return factory(scope);
    final auth = context.read<AuthBloc>();
    _catalogGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseExerciseCatalogRepository(
        scope: scope, isSessionCurrent: _catalogGuard!.isCurrent);
  }

  RoutineTemplateRepository _createRoutines(
      SessionScope scope, TutorialRepository catalog) {
    final factory = widget.routineRepositoryFactory;
    if (factory != null) return factory(scope, catalog);
    final auth = context.read<AuthBloc>();
    _routineGuard = CatalogEditSessionGuard(
        expected: widget.session!,
        current: () => auth.state,
        changes: auth.stream);
    return FirebaseRoutineTemplateRepository(
        scope: scope,
        exerciseCatalog: catalog,
        isSessionCurrent: _routineGuard!.isCurrent);
  }

  @override
  void dispose() {
    _catalogGuard?.dispose();
    _routineGuard?.dispose();
    _coachGuard?.dispose();
    _availabilityGuard?.dispose();
    _bookingGuard?.dispose();
    _announcementGuard?.dispose();
    _disclaimerGuard?.dispose();
    _complianceGuard?.dispose();
    _accountContactGuard?.dispose();
    _memberDirectoryGuard?.dispose();
    _rewardGuard?.dispose();
    _facilityGuard?.dispose();
    _equipmentGuard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.config.validate();
    if (widget.config.isFirebase && widget.session == null) return widget.child;
    final scope = widget.session?.scope;
    if (widget.config.isFirebase) {
      return MultiRepositoryProvider(providers: [
        RepositoryProvider<FacilitySettingsRepository>(
            create: (_) => _createFacilitySettings(scope!)),
        RepositoryProvider<RewardCatalogRepository>(
            create: (_) => _createRewardCatalog(scope!)),
        RepositoryProvider<AdminMemberDirectoryRepository>(
            create: (_) => _createMemberDirectory(scope!)),
        RepositoryProvider<AccountPhotoPicker>(
            create: (_) => LocalAccountPhotoPicker()),
        RepositoryProvider<AdminAccountContactRepository>(
            create: (_) => _createAccountContact(scope!)),
        RepositoryProvider<ComplianceDocumentRepository>(
            create: (_) => _createCompliance(scope!)),
        RepositoryProvider<ChatbotDisclaimerRepository>(
            create: (_) => _createDisclaimer(scope!)),
        RepositoryProvider<EquipmentImagePicker>(
            create: (_) => LocalEquipmentImagePicker()),
        RepositoryProvider<EquipmentRepository>(
            create: (_) => _createEquipment(scope!)),
        RepositoryProvider<ContentRepository>(
            create: (_) => _createAnnouncements(scope!)),
        RepositoryProvider<BookingListRepository>(
            create: (_) => _createBookingList(scope!)),
        RepositoryProvider<CoachAvailabilityRepository>(
            create: (_) => _createAvailability(scope!)),
        RepositoryProvider<CoachProfileAdminRepository>(
            create: (_) => _createCoachDirectory(scope!)),
        RepositoryProvider<TutorialRepository>(
            create: (_) => _createCatalog(scope!)),
        RepositoryProvider<RoutineTemplateRepository>(
            create: (context) =>
                _createRoutines(scope!, context.read<TutorialRepository>())),
      ], child: widget.child);
    }
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<MemberProfileRepository>(
            create: (_) => InMemoryMemberProfileRepository(session: session)),
        RepositoryProvider<CoachRepository>(
            create: (_) => InMemoryCoachRepository(session: session)),
        RepositoryProvider<UserAccountRepository>(
            create: (_) => InMemoryUserAccountRepository(session: session)),
        RepositoryProvider<WorkoutRepository>(
            create: (_) => InMemoryWorkoutRepository(session: session)),
        RepositoryProvider<EquipmentRepository>(
            create: (_) => InMemoryEquipmentRepository(session: session)),
        RepositoryProvider<TutorialRepository>(
            create: (_) => widget.config.isFirebase
                ? FirebaseExerciseCatalogRepository(scope: scope!)
                : InMemoryTutorialRepository(session: session)),
        RepositoryProvider<RoutineTemplateRepository>(
            create: (context) => widget.config.isFirebase
                ? FirebaseRoutineTemplateRepository(
                    scope: scope!,
                    exerciseCatalog: context.read<TutorialRepository>())
                : InMemoryRoutineTemplateRepository(session: session)),
        RepositoryProvider<GamificationRepository>(
            create: (_) => InMemoryGamificationRepository(session: session)),
        RepositoryProvider<BookingRepository>(
            create: (_) => InMemoryBookingRepository(session: session)),
        RepositoryProvider<AvailabilityRepository>(
            create: (_) => InMemoryAvailabilityRepository(session: session)),
        RepositoryProvider<MembershipRepository>(
            create: (_) => InMemoryMembershipRepository(session: session)),
        RepositoryProvider<ChatRepository>(
            create: (_) => InMemoryChatRepository(session: session)),
        RepositoryProvider<AnalyticsRepository>(
            create: (_) => InMemoryAnalyticsRepository(session: session)),
        RepositoryProvider<RecommendationRepository>(
            create: (_) => InMemoryRecommendationRepository(session: session)),
        RepositoryProvider<ContentRepository>(
            create: (_) => InMemoryContentRepository(session: session)),
      ],
      child: widget.child,
    );
  }
}
