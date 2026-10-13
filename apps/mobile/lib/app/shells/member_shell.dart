import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../home/member_home_screen.dart';
import '../routing/member_progress_route.dart';
import '../di/local_member_progress_factory.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/workout/data/published_routine.dart';
import '../../features/workout/presentation/member/workout_prep_screen.dart';
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
      this.progressRepositoryFactory,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final Future<PublishedRoutine?> Function()? routineLoader;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final WidgetBuilder? memberSettingsBuilder;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;
  Future<PublishedRoutine?>? _routineFuture;

  @override
  void initState() {
    super.initState();
    if (widget.liveSession != null) {
      _routineFuture = widget.routineLoader?.call();
    }
  }

  final _pages = const [
    MemberHomeScreen(),
    WorkoutPrepScreen(),
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
            FutureBuilder<PublishedRoutine?>(
              future: _routineFuture,
              builder: (context, snapshot) => _scaffold(<Widget>[
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
                    publishedRoutine: snapshot.data),
                WorkoutPrepScreen(
                    live: true,
                    publishedRoutine: snapshot.data,
                    routineLoadFailed: snapshot.hasError),
                const GamificationDashboardScreen(live: true),
                const BrowseCoachesScreen(live: true),
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

  Widget _scaffold(List<Widget> pages, {void Function(int)? onTabChanged}) {
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
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
