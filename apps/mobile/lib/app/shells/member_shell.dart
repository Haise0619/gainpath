import 'package:gainpath_data/gainpath_data.dart'
    show FypDatasetTransportFactory;
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../../infrastructure/firebase/firebase_demo_recommendation.dart';
import '../di/member_recommendation_factory.dart';
import '../../infrastructure/firebase/firebase_module9_repository.dart';
import '../notifications/member_notifications_screen.dart';
import '../notifications/member_notification_badge.dart';
import '../../infrastructure/local/member_announcement_read_store.dart';
import '../routing/app_check_in_host.dart';
import '../di/app_check_in_factory.dart';
import '../di/workout_backup_network_opportunities.dart';
import '../../infrastructure/firebase/firebase_app_check_in_repository.dart';
import '../../infrastructure/local/member_achievements_cache.dart';
import '../../features/gamification/application/member_achievements_controller.dart';
import '../../features/gamification/presentation/member/achievement_celebration_host.dart';
import '../../features/gamification/presentation/member/member_achievements_screen.dart';
import '../routing/workout_program_route.dart';
import '../../features/gamification/application/app_check_in_cubit.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart'
    show
        SupportRequestsPage,
        MemberGroupClassesScreen,
        MemberGroupClassDetails,
        UpcomingGroupClasses,
        UpcomingGroupClassesState;
import '../../infrastructure/firebase/firebase_function_transport.dart'
    show firebaseCallable;
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/coaching.dart' show Module9Repository;
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/membership.dart';
import '../../features/membership/application/membership_feature_host.dart';
import '../../infrastructure/local/mock_membership_commerce.dart';
import '../../features/analytics/application/member_progress_cubit.dart';
import 'package:gainpath_domain/analytics.dart';
import '../home/member_home_screen.dart';
import '../routing/member_progress_route.dart';
import '../routing/workout_prep_route.dart';
import '../di/local_member_progress_factory.dart';
import '../di/workout_backup_factory.dart';
import '../di/program_store_factory.dart';
import '../di/workout_store_factory.dart';
import '../../features/workout/domain/program_enrollment.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../di/published_routine_catalog_factory.dart';
import '../di/equipment_catalog_factory.dart';
import '../di/coach_profile_factory.dart';
import '../di/booking_factory.dart';
import '../../features/workout/application/published_routine_catalog_cubit.dart';
import '../../features/workout/presentation/member/published_routine_catalog_controls.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/gamification/presentation/member/gamification_dashboard_screen.dart';
import '../../features/coaching/presentation/member/browse_coaches_screen.dart';
import '../../features/identity/presentation/member/member_profile_screen.dart';
import '../../features/analytics/presentation/member/body_metrics_screen.dart';
import '../../features/membership/presentation/shared/membership_dashboard_screen.dart';

/// Bottom-navigation shell for the Gym Member role (Modules 1 to 7).
class MemberShell extends StatefulWidget {
  const MemberShell(
      {super.key,
      this.liveSession,
      this.datasetTransportFactory,
      this.liveProfile,
      this.routineLoader,
      this.routineCatalogFactory,
      this.programStoreFactory,
      this.routineJourneyStoreFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.progressGoalSummaryBuilder,
      this.backupFactory,
      this.memberRewardsBuilder,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FypDatasetTransportFactory? datasetTransportFactory;
  final FitnessProfile? liveProfile;
  final Future<PublishedRoutine?> Function()? routineLoader;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final Future<ProgramEnrollmentStore> Function(SessionScope)?
      programStoreFactory;
  final Future<RoutineJourneyStore> Function(SessionScope)?
      routineJourneyStoreFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final ProgressGoalSummaryBuilder? progressGoalSummaryBuilder;
  final WorkoutBackupFactory? backupFactory;
  final WidgetBuilder? memberSettingsBuilder;
  final WidgetBuilder? memberRewardsBuilder;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _directoryVisited = false;
  PublishedRoutineCatalogCubit? _catalog;
  MembershipCommerceRepository? _membership;
  AnnouncementReader? _announcements;
  Module9Repository? _notificationInbox;
  MemberNotificationBadge? _notificationBadge;
  GlobalKey<UpcomingGroupClassesState> _upcomingClassesKey = GlobalKey();

  Future<void> _refreshAnnouncements() async {
    final badge = _notificationBadge;
    if (badge == null) return;
    await Future.wait(
        [badge.refreshAnnouncements(clearFirst: true), badge.refreshInbox()]);
  }

  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<void>? _achievementNetworkSubscription;
  MemberAchievementsController? _achievements;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.liveSession == null || _auth != null) return;
    _auth = context.read<AuthBloc>();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = _auth!.stream.listen((state) {
      if (state.session?.scope != widget.liveSession?.scope ||
          !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})) {
        _catalog?.invalidate();
        _achievements?.invalidate();
        _notificationBadge?.clear();
      } else if (appCheckInEnabled) {
        unawaited(_achievements?.loadIfNeeded());
      }
    });
    _createCatalog();
    _createAchievements();
  }

  SessionScope? _activeScope() => _auth != null &&
          _auth!.state.session?.scope == widget.liveSession?.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.liveSession!.scope
      : null;

  void _createCatalog() {
    final session = widget.liveSession!;
    final scope = session.scope;
    _createMembership();
    _announcements =
        widget.announcementReaderFactory?.call(scope, _activeScope);
    _createNotificationBadge(scope);
    final repository =
        widget.routineCatalogFactory?.call(scope, _activeScope) ??
            SinglePublishedRoutineCatalog(
                scope: scope, loader: widget.routineLoader ?? () async => null);
    _catalog = PublishedRoutineCatalogCubit(
        repository: repository, activeScope: _activeScope);
    unawaited(_catalog!.refresh());
  }

  void _createNotificationBadge(SessionScope scope) {
    bool current() => mounted && _activeScope() == scope;
    final inbox = scope.datasetScope == null
        ? FirebaseModule9Repository(scope: scope, isCurrent: current)
        : FirebaseDemoInboxRepository((widget.datasetTransportFactory ??
            firebaseFypDatasetTransport)(scope, current));
    final readStore = MemberAnnouncementReadStore(scope);
    final badge = MemberNotificationBadge(
      announcements: _announcements,
      inbox: inbox,
      isCurrent: current,
      loadSeen: readStore.read,
      saveSeen: readStore.save,
    );
    _notificationInbox = inbox;
    _notificationBadge = badge;
    badge.watchInbox();
    unawaited(badge.refreshAnnouncements());
    unawaited(badge.refreshInbox());
  }

  Future<Map<String, dynamic>> _classCall(
      String action, Map<String, dynamic> input) async {
    final session = widget.liveSession;
    if (session == null ||
        session.datasetScope != null ||
        _activeScope() != session.scope) {
      throw StateError('Group classes are unavailable for this session.');
    }
    final response = await firebaseCallable(action == 'instructorPhoto'
            ? 'getCoachPublishedPhotoCommand'
            : 'groupClassesCommand')
        .call<Map<String, dynamic>>({
      ...input,
      'schemaVersion': 1,
      'organizationId': session.organizationId,
      if (action != 'instructorPhoto') 'action': action,
    });
    if (_activeScope() != session.scope) {
      throw StateError('Member session changed.');
    }
    return response.data;
  }

  void _openClassMembership() {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const MembershipDashboardScreen(connected: true)));
  }

  Future<void> _openClassDetails(String id) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => MemberGroupClassDetails(
            call: _classCall, id: id, onUpgrade: _openClassMembership)));
  }

  Future<void> _exploreClasses() => _openClasses();

  Future<void> _openClasses({bool registered = false}) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => MemberGroupClassesScreen(
        call: _classCall,
        onUpgrade: _openClassMembership,
        startInMyClasses: registered,
      ),
    ));
  }

  Future<void> _openNotifications() async {
    final session = widget.liveSession;
    final badge = _notificationBadge;
    final reader = _announcements;
    final inbox = _notificationInbox;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => session == null
            ? MemberNotificationsScreen(isCurrent: () => mounted)
            : buildMemberRecommendationNotifications(
                session,
                datasetTransport: session.datasetScope == null
                    ? null
                    : (widget.datasetTransportFactory ??
                            firebaseFypDatasetTransport)(
                        session.scope, () => _activeScope() == session.scope),
                inbox: inbox,
                coachDirectory: widget.coachDirectoryFactory?.call(
                    session.scope, () => _activeScope() == session.scope),
                catalog: widget.routineCatalogFactory
                    ?.call(session.scope, _activeScope),
                announcements: reader,
                notificationBadge: badge,
                onOpenGroupClass:
                    session.datasetScope == null ? _openClassDetails : null,
                bookingFactory: widget.bookingFactory,
                bookingListFactory: widget.bookingListFactory,
                availabilityFactory: widget.coachAvailabilityFactory,
              ),
      ),
    );
    unawaited(badge?.refreshAnnouncements());
    unawaited(badge?.refreshInbox());
  }

  void _createMembership() {
    final session = widget.liveSession!;
    _membership = createMembershipCommerceRepository(
        session.scope,
        () =>
            identical(_auth?.state.session, session) &&
            _activeScope() == session.scope);
  }

  void _createAchievements() {
    final scope = widget.liveSession?.scope;
    if (scope == null) return;
    final repository =
        FirebaseAppCheckInRepository(scope: scope, activeScope: _activeScope);
    final cache = MemberAchievementsCache(scope);
    _achievements = MemberAchievementsController(
        load: repository.achievements,
        isCurrent: () => scope.datasetScope == null && _activeScope() == scope,
        readCache: cache.read,
        saveCache: cache.save);
    if (appCheckInEnabled) unawaited(_achievements!.loadIfNeeded());
    _achievementNetworkSubscription ??=
        workoutBackupNetworkOpportunities().listen((_) {
      final achievements = _achievements;
      if (achievements != null && (achievements.stale || achievements.failed)) {
        unawaited(achievements.refresh());
      }
    }, onError: (Object _) {});
  }

  void _refreshAchievementsAfterEvent() {
    final achievements = _achievements;
    if (achievements != null) unawaited(achievements.refresh(changed: true));
  }

  void _openAchievements() {
    final controller = _achievements;
    if (controller == null) return;
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => MemberAchievementsScreen(controller: controller)));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_notificationBadge?.refreshAnnouncements());
    unawaited(_notificationBadge?.refreshInbox());
    if (appCheckInEnabled || _index == 2 || _index == 4) {
      unawaited(_achievements?.loadIfNeeded());
    }
  }

  @override
  void didUpdateWidget(MemberShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveSession?.scope != widget.liveSession?.scope) {
      _upcomingClassesKey = GlobalKey();
      unawaited(_catalog?.close());
      _catalog = null;
      _membership = null;
      _announcements = null;
      _notificationBadge?.dispose();
      _notificationBadge = null;
      _notificationInbox = null;
      _achievements?.dispose();
      _achievements = null;
      if (widget.liveSession != null && _auth != null) {
        _createCatalog();
        _createAchievements();
      }
      _index = 0;
      _directoryVisited = false;
    } else if (!identical(oldWidget.liveSession, widget.liveSession) &&
        widget.liveSession != null) {
      _createMembership();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_achievementNetworkSubscription?.cancel());
    _achievements?.dispose();
    _notificationBadge?.dispose();
    unawaited(_authSubscription?.cancel());
    unawaited(_catalog?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveSession == null) return _scaffold(_buildPages());
    return AppCheckInHost(
        key: ValueKey(widget.liveSession!.scope),
        scope: widget.liveSession!.scope,
        builder: (checkIn, refreshCheckIn, claimCheckIn) => MemberProgressHost(
              key: ValueKey(widget.liveSession!.scope),
              scope: widget.liveSession!.scope,
              backupFactory: widget.backupFactory,
              onWorkoutBackupChanged: _refreshAchievementsAfterEvent,
              goalSummaryBuilder: widget.progressGoalSummaryBuilder,
              repositoryFactory: widget.progressRepositoryFactory ??
                  createLocalMemberProgressRepository,
              builder: (context, progress, refresh, open, openWorkout) =>
                  BlocBuilder<PublishedRoutineCatalogCubit,
                          PublishedRoutineCatalogState>(
                      bloc: _catalog!,
                      builder: (context, catalog) => _scaffold(
                              _buildPages(
                                  progress: progress,
                                  checkIn: checkIn,
                                  refreshCheckIn: refreshCheckIn,
                                  claimCheckIn: () async {
                                    final achievements = _achievements;
                                    await claimCheckIn();
                                    if (achievements != null &&
                                        achievements.current) {
                                      unawaited(
                                          achievements.refresh(changed: true));
                                    }
                                  },
                                  refresh: refresh,
                                  open: open,
                                  openWorkout: openWorkout,
                                  catalog: catalog), onTabChanged: (index) {
                            if (index == 0) {
                              refresh();
                              unawaited(
                                  _notificationBadge?.refreshAnnouncements());
                            }
                            if (index == 0 || index == 2) refreshCheckIn();
                            if (index == 2 || index == 4) {
                              unawaited(_achievements?.loadIfNeeded());
                            }
                          })),
            ));
  }

  // A single presentation tree. Data hosts above supply scoped state/actions.
  List<Widget> _buildPages(
      {MemberProgressState? progress,
      AppCheckInState? checkIn,
      Future<void> Function()? refreshCheckIn,
      Future<void> Function()? claimCheckIn,
      Future<void> Function()? refresh,
      void Function(MemberProgressView)? open,
      void Function(LocalWorkoutProgressRecord)? openWorkout,
      PublishedRoutineCatalogState? catalog}) {
    final session = widget.liveSession;
    final connected = session != null;
    return [
      MemberHomeScreen(
          liveSession: session,
          recommendations: session == null
              ? null
              : MemberRecommendationHost(
                  key: ValueKey(session.scope),
                  session: session,
                  compact: true,
                  visible: _index == 0,
                  isCurrent: () => _activeScope() == session.scope,
                  datasetTransport: session.datasetScope == null
                      ? null
                      : (widget.datasetTransportFactory ??
                              firebaseFypDatasetTransport)(
                          session.scope, () => _activeScope() == session.scope),
                  coachDirectory: widget.coachDirectoryFactory?.call(
                      session.scope, () => _activeScope() == session.scope),
                  catalog: widget.routineCatalogFactory
                      ?.call(session.scope, _activeScope),
                  bookingFactory: widget.bookingFactory,
                  bookingListFactory: widget.bookingListFactory,
                  availabilityFactory: widget.coachAvailabilityFactory),
          onOpenRewards: () {
            setState(() => _index = 2);
            refreshCheckIn?.call();
            unawaited(_achievements?.loadIfNeeded());
          },
          appCheckIn: checkIn,
          onAppClaim: claimCheckIn,
          onRefreshCheckIn: refreshCheckIn,
          unreadNotifications: _notificationBadge,
          upcomingClasses: session != null && session.datasetScope == null
              ? UpcomingGroupClasses(
                  key: _upcomingClassesKey,
                  call: _classCall,
                  active: _index == 0,
                  onExplore: _exploreClasses,
                  onViewAll: () => _openClasses(registered: true),
                  onOpen: _openClassDetails)
              : null,
          onRefreshClasses: () async {
            await _upcomingClassesKey.currentState?.refresh();
          },
          onOpenNotifications: _openNotifications,
          liveProfile: widget.liveProfile,
          localProgress: progress?.progress,
          routineProgress: progress?.routines,
          onOpenRoutineHistory:
              open == null ? null : () => open(MemberProgressView.routines),
          onOpenRoutine: refresh == null
              ? null
              : (a) => openRoutineAttempt(context, a, refresh,
                  sessionRecords: progress?.progress?.records ?? const [],
                  onOpenSession: openWorkout),
          progressError: progress?.error,
          progressWarnings: progress?.snapshot?.warnings ?? const [],
          onRefreshProgress: refresh,
          onRefreshRoutines: _catalog?.refresh,
          onRefreshAnnouncements: _refreshAnnouncements,
          onOpenProgress:
              open == null ? null : () => open(MemberProgressView.dashboard),
          onOpenHistory:
              open == null ? null : () => open(MemberProgressView.history),
          onOpenEquipment: session == null
              ? null
              : () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => buildMemberEquipmentScanner(session,
                          factory: widget.equipmentReaderFactory))),
          onOpenCoaches: () => setState(() {
                _index = 3;
                _directoryVisited = true;
              }),
          onOpenBookings: session == null
              ? null
              : () => openBookingList(context, session,
                  factory: widget.bookingListFactory),
          onOpenWorkout: openWorkout,
          onLoadUpcomingCoaching: session == null
              ? null
              : () async {
                  final source = createBookingList(
                      session,
                      () => _activeScope() == session.scope,
                      widget.bookingListFactory);
                  BookingCursor? cursor;
                  do {
                    final page =
                        await source.load(dayCount: 30, cursor: cursor);
                    if (_activeScope() != session.scope) return null;
                    final records = page.records
                        .where((b) =>
                            b.memberId == session.userId &&
                            b.status == BookingStatus.confirmed &&
                            b.startAtMillis > page.serverNowMillis)
                        .toList()
                      ..sort(
                          (a, b) => a.startAtMillis.compareTo(b.startAtMillis));
                    if (records.isNotEmpty) return records.first;
                    cursor = page.nextCursor;
                  } while (cursor != null);
                  return null;
                },
          onOpenPlan: session == null
              ? null
              : () async {
                  final auth = context.read<AuthBloc>();
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => BlocProvider.value(
                              value: auth,
                              child: WorkoutProgramRoute(
                                  scope: session.scope,
                                  storeFactory: widget.programStoreFactory ??
                                      createProgramEnrollmentStore,
                                  routineStoreFactory:
                                      widget.routineJourneyStoreFactory ??
                                          createRoutineJourneyStore))));
                  if (mounted && _activeScope() == session.scope) {
                    await refresh?.call();
                    await _catalog?.refresh();
                  }
                },
          publishedRoutine: catalog?.selected,
          routineStatusMessage: catalog == null ? null : _catalogLabel(catalog),
          onStartWorkout: () => setState(() => _index = 1)),
      WorkoutPrepRoute(
        live: connected,
        equipmentReaderFactory: widget.equipmentReaderFactory,
        programStoreFactory:
            widget.programStoreFactory ?? createProgramEnrollmentStore,
        routineStoreFactory:
            widget.routineJourneyStoreFactory ?? createRoutineJourneyStore,
        progressRepositoryFactory: widget.progressRepositoryFactory ??
            createLocalMemberProgressRepository,
        publishedRoutine: catalog?.selected,
        routineStatusMessage: catalog == null ? null : _catalogLabel(catalog),
        routineLoadFailed: catalog?.status == CatalogStatus.error,
        routineCatalogControls: catalog == null
            ? null
            : PublishedRoutineCatalogControls(
                state: catalog,
                catalogCubit: _catalog,
                onRefresh: _catalog!.refresh,
                onSelect: _catalog!.select,
                onLoadMore: _catalog!.loadMore),
        onOpenEquipment: session == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => buildMemberEquipmentScanner(session,
                        factory: widget.equipmentReaderFactory))),
      ),
      widget.memberRewardsBuilder?.call(context) ??
          GamificationDashboardScreen(
              live: connected,
              checkIn: checkIn,
              achievements: _achievements,
              onClaim: claimCheckIn,
              onRefreshCheckIn: refreshCheckIn),
      if (session == null)
        const BrowseCoachesScreen()
      else if (!_directoryVisited)
        const SizedBox.shrink()
      else
        buildFirebaseCoachDirectory(
          session,
          factory: widget.coachDirectoryFactory,
          bookingFactory: widget.bookingFactory,
          bookingListFactory: widget.bookingListFactory,
          availabilityFactory: widget.coachAvailabilityFactory,
          onOpenGroupClasses:
              session.datasetScope == null ? _exploreClasses : null,
        ),
      MemberProfileScreen(
          liveSession: session,
          supportBuilder: session == null || session.datasetScope != null
              ? null
              : (_) => SupportRequestsPage(call: (action, input) async {
                    if (!mounted ||
                        _auth?.state.session?.scope != session.scope) {
                      throw StateError('Support session changed.');
                    }
                    final result =
                        await firebaseCallable('supportRequestCommand')
                            .call<Map<String, dynamic>>({
                      ...input,
                      'schemaVersion': 1,
                      'organizationId': session.organizationId,
                      'action': action,
                    });
                    if (!mounted ||
                        _auth?.state.session?.scope != session.scope) {
                      throw StateError('Support session changed.');
                    }
                    return result.data;
                  }),
          liveProfile: widget.liveProfile,
          membershipRepository: session == null
              ? MockMembershipCommerce.forRepository(
                  context.read<MembershipRepository>())
              : _membership,
          bodyMetricsBuilder: session == null
              ? null
              : (_) => BodyMetricsScreen(
                  live: true,
                  weightKg: widget.liveProfile?.weightKg.toDouble(),
                  heightCm: widget.liveProfile?.heightCm.toDouble()),
          membershipBuilder: session == null
              ? null
              : (_) => const MembershipDashboardScreen(connected: true),
          onOpenProgress:
              open == null ? null : () => open(MemberProgressView.dashboard),
          onOpenAchievements: _achievements == null ? null : _openAchievements,
          memberSettingsBuilder: widget.memberSettingsBuilder),
    ];
  }

  String? _catalogLabel(PublishedRoutineCatalogState state) =>
      state.selected != null
          ? null
          : switch (state.status) {
              CatalogStatus.loading => 'Loading published routines…',
              CatalogStatus.error ||
              CatalogStatus.unavailable =>
                'Routines unavailable',
              CatalogStatus.empty => 'No published routine yet',
              CatalogStatus.ready => 'Choose a published routine',
            };

  Widget _scaffold(List<Widget> pages, {void Function(int)? onTabChanged}) {
    final achievements = _achievements;
    final tabs = IndexedStack(index: _index, children: pages);
    return Scaffold(
      body: achievements == null
          ? tabs
          : AchievementCelebrationHost(controller: achievements, child: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() {
            _index = i;
            if (i == 3) _directoryVisited = true;
          });
          onTabChanged?.call(i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center_rounded),
              label: 'Workout'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined),
              selectedIcon: Icon(Icons.emoji_events_rounded),
              label: 'Rewards'),
          NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded),
              label: 'Coaches'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}
