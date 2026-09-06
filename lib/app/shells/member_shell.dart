import 'package:flutter/material.dart';
import 'package:gainpath/app/home/member_home_screen.dart';
import 'package:gainpath/features/workout/presentation/member/workout_prep_screen.dart';
import 'package:gainpath/features/gamification/presentation/member/gamification_screens.dart';
import 'package:gainpath/features/coaching/presentation/member/browse_coaches_screen.dart';
import 'package:gainpath/features/identity/presentation/member/profile_screens.dart';

/// Bottom-navigation shell for the Gym Member role (Modules 1 to 7).
class MemberShell extends StatefulWidget {
  const MemberShell({super.key});

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  int _index = 0;

  final _pages = const [
    MemberHomeScreen(),
    WorkoutPrepScreen(),
    GamificationDashboardScreen(),
    BrowseCoachesScreen(),
    MemberProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
