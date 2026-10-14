import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../home/member_home_screen.dart';
import '../routing/member_progress_route.dart';
import '../routing/workout_prep_route.dart';
import '../di/local_member_progress_factory.dart';
import '../di/published_routine_catalog_factory.dart';
import '../di/coach_profile_factory.dart';
import '../../features/workout/application/published_routine_catalog_cubit.dart';
import '../../features/workout/presentation/member/published_routine_catalog_controls.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/gamification/presentation/member/gamification_dashboard_screen.dart';
import '../../features/coaching/presentation/member/browse_coaches_screen.dart';
import '../../features/identity/presentation/member/member_profile_screen.dart';

/// Bottom-navigation shell for the Gym Member role (Modules 1 to 7).
class MemberShell extends StatefulWidget {
  const MemberShell(
      {super.key,
      this.liveSession,
      this.liveProfile,
      this.routineLoader,
      this.routineCatalogFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.progressRepositoryFactory,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final Future<PublishedRoutine?> Function()? routineLoader;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final WidgetBuilder? memberSettingsBuilder;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;
  bool _directoryVisited = false;
  PublishedRoutineCatalogCubit? _catalog;
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
    final scope = widget.liveSession!.scope;
    final repository =
        widget.routineCatalogFactory?.call(scope, _activeScope) ??
            SinglePublishedRoutineCatalog(
                scope: scope, loader: widget.routineLoader ?? () async => null);
    _catalog = PublishedRoutineCatalogCubit(
        repository: repository, activeScope: _activeScope);
    unawaited(_catalog!.refresh());
  }

  @override
  void didUpdateWidget(MemberShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.liveSession?.scope != widget.liveSession?.scope) {
      unawaited(_catalog?.close());
      _catalog = null;
      if (widget.liveSession != null && _auth != null) _createCatalog();
      _index = 0;
      _directoryVisited = false;
    }
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_catalog?.close());
    super.dispose();
  }

  final _pages = const [
    MemberHomeScreen(),
    WorkoutPrepRoute(live: false),
    GamificationDashboardScreen(),
    BrowseCoachesScreen(),
    MemberProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final live = widget.liveSession != null;
    if (!live) return _scaffold(_pages);
    return MemberProgressHost(
        key: ValueKey(widget.liveSession!.scope),
        scope: widget.liveSession!.scope,
        repositoryFactory: widget.progressRepositoryFactory ??
            createLocalMemberProgressRepository,
        builder: (context, progressState, refresh, open, openWorkout) =>
            BlocBuilder<PublishedRoutineCatalogCubit,
                PublishedRoutineCatalogState>(
              bloc: _catalog!,
              builder: (context, catalog) => _scaffold(<Widget>[
                MemberHomeScreen(
                    liveSession: widget.liveSession!,
                    liveProfile: widget.liveProfile!,
                    localProgress: progressState.progress,
                    progressError: progressState.error,
                    progressWarnings:
                        progressState.snapshot?.warnings ?? const [],
                    onRefreshProgress: refresh,
                    onOpenProgress: () => open(MemberProgressView.dashboard),
                    onOpenHistory: () => open(MemberProgressView.history),
                    onOpenWorkout: openWorkout,
                    publishedRoutine: catalog.selected,
                    routineStatusMessage: _catalogLabel(catalog),
                    onStartWorkout: () => setState(() => _index = 1)),
                WorkoutPrepRoute(
                    publishedRoutine: catalog.selected,
                    routineStatusMessage: _catalogLabel(catalog),
                    routineLoadFailed: catalog.status == CatalogStatus.error,
                    routineCatalogControls: PublishedRoutineCatalogControls(
                        state: catalog,
                        onRefresh: _catalog!.refresh,
                        onSelect: _catalog!.select,
                        onLoadMore: _catalog!.loadMore)),
                const GamificationDashboardScreen(live: true),
                _directoryVisited
                    ? buildFirebaseCoachDirectory(widget.liveSession!,
                        factory: widget.coachDirectoryFactory,
                        availabilityFactory: widget.coachAvailabilityFactory)
                    : const SizedBox.shrink(),
                MemberProfileScreen(
                    liveSession: widget.liveSession!,
                    liveProfile: widget.liveProfile!,
                    onOpenProgress: () => open(MemberProgressView.dashboard),
                    memberSettingsBuilder: widget.memberSettingsBuilder),
              ], onTabChanged: (index) {
                if (index == 0) refresh();
              }),
            ));
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
