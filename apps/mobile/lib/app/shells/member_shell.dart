import '../../infrastructure/firebase/firebase_module9_repository.dart';
import '../../features/coaching/presentation/member/coaching_updates_screen.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/membership.dart';
import '../di/membership_factory.dart';
import '../../features/membership/data/mock_membership_commerce.dart';
import '../../features/analytics/application/member_progress_cubit.dart';
import 'package:gainpath_domain/analytics.dart';
import '../../features/content/presentation/member/member_announcements.dart';
import '../home/member_home_screen.dart';
import '../routing/member_progress_route.dart';
import '../routing/workout_prep_route.dart';
import '../di/local_member_progress_factory.dart';
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
      this.liveProfile,
      this.routineLoader,
      this.routineCatalogFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final Future<PublishedRoutine?> Function()? routineLoader;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final WidgetBuilder? memberSettingsBuilder;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;
  bool _directoryVisited = false;
  PublishedRoutineCatalogCubit? _catalog;
  MembershipCommerceRepository? _membership;
  AnnouncementReader? _announcements;
  final _announcementKey = GlobalKey<MemberAnnouncementsState>();
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.liveSession == null || _auth != null) return;
    _auth = context.read<AuthBloc>();
    _authSubscription = _auth!.stream.listen((state) {
      if (state.session?.scope != widget.liveSession?.scope ||
          !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})) {
        _catalog?.invalidate();
      }
    });
    _createCatalog();
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
    final repository =
        widget.routineCatalogFactory?.call(scope, _activeScope) ??
            SinglePublishedRoutineCatalog(
                scope: scope, loader: widget.routineLoader ?? () async => null);
    _catalog = PublishedRoutineCatalogCubit(
        repository: repository, activeScope: _activeScope);
    unawaited(_catalog!.refresh());
  }

  void _createMembership() {
    final session = widget.liveSession!;
    _membership = createMembershipCommerceRepository(
        session.scope,
        () =>
            identical(_auth?.state.session, session) &&
            _activeScope() == session.scope);
  }

  @override
  void didUpdateWidget(MemberShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveSession?.scope != widget.liveSession?.scope) {
      unawaited(_catalog?.close());
      _catalog = null;
      _membership = null;
      _announcements = null;
      if (widget.liveSession != null && _auth != null) _createCatalog();
      _index = 0;
      _directoryVisited = false;
    } else if (!identical(oldWidget.liveSession, widget.liveSession) &&
        widget.liveSession != null) {
      _createMembership();
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_catalog?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.liveSession == null) return _scaffold(_buildPages());
    return MemberProgressHost(
      key: ValueKey(widget.liveSession!.scope),
      scope: widget.liveSession!.scope,
      repositoryFactory: widget.progressRepositoryFactory ??
          createLocalMemberProgressRepository,
      builder: (context, progress, refresh, open, openWorkout) => BlocBuilder<
              PublishedRoutineCatalogCubit, PublishedRoutineCatalogState>(
          bloc: _catalog!,
          builder: (context, catalog) => _scaffold(
                  _buildPages(
                      progress: progress,
                      refresh: refresh,
                      open: open,
                      openWorkout: openWorkout,
                      catalog: catalog), onTabChanged: (index) {
                if (index == 0) refresh();
              })),
    );
  }

  // A single presentation tree. Data hosts above supply scoped state/actions.
  List<Widget> _buildPages(
      {MemberProgressState? progress,
      Future<void> Function()? refresh,
      void Function(MemberProgressView)? open,
      void Function(LocalWorkoutProgressRecord)? openWorkout,
      PublishedRoutineCatalogState? catalog}) {
    final session = widget.liveSession;
    final connected = session != null;
    return [
      MemberHomeScreen(
          liveSession: session,
          onOpenCoachingUpdates: session == null ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoachingUpdatesScreen(
            repository: FirebaseModule9Repository(scope: session.scope, isCurrent: () => _activeScope() == session.scope),
            isCurrent: () => _activeScope() == session.scope,
            onOpenBookings: () => openBookingList(context, session, factory: widget.bookingListFactory),
          ))),
          liveProfile: widget.liveProfile,
          localProgress: progress?.progress,
          progressError: progress?.error,
          progressWarnings: progress?.snapshot?.warnings ?? const [],
          onRefreshProgress: refresh,
          onRefreshRoutines: _catalog?.refresh,
          announcements: _announcements == null
              ? null
              : MemberAnnouncements(
                  key: _announcementKey, reader: _announcements!),
          onRefreshAnnouncements: connected
              ? () async => _announcementKey.currentState?.refresh()
              : null,
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
          publishedRoutine: catalog?.selected,
          routineStatusMessage: catalog == null ? null : _catalogLabel(catalog),
          onStartWorkout: () => setState(() => _index = 1)),
      WorkoutPrepRoute(
          live: connected,
          publishedRoutine: catalog?.selected,
          routineStatusMessage: catalog == null ? null : _catalogLabel(catalog),
          routineLoadFailed: catalog?.status == CatalogStatus.error,
          routineCatalogControls: catalog == null
              ? null
              : PublishedRoutineCatalogControls(
                  state: catalog,
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
      GamificationDashboardScreen(live: connected),
      session == null
          ? const BrowseCoachesScreen()
          : _directoryVisited
              ? buildFirebaseCoachDirectory(session,
                  factory: widget.coachDirectoryFactory,
                  bookingFactory: widget.bookingFactory,
                  bookingListFactory: widget.bookingListFactory,
                  availabilityFactory: widget.coachAvailabilityFactory)
              : const SizedBox.shrink(),
      MemberProfileScreen(
          liveSession: session,
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
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
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
