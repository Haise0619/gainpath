import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import '../../features/coaching/presentation/coach/roster_screen.dart';
import '../../features/coaching/presentation/coach/availability_screens.dart';
import '../../features/analytics/presentation/coach/earnings_screen.dart';
import '../../features/identity/presentation/coach/coach_account_screen.dart';
import '../../features/identity/application/coach_profile_cubit.dart';

/// Bottom-navigation shell for the Fitness Coach role (Modules 8 to 10).
class CoachShell extends StatefulWidget {
  const CoachShell(
      {super.key,
      this.liveRepository,
      this.isCurrent,
      this.onOpenLiveEditor,
      this.liveAvailabilityBuilder});
  final CoachProfileRepository? liveRepository;
  final bool Function()? isCurrent;
  final void Function(CoachProfileCubit)? onOpenLiveEditor;
  final WidgetBuilder? liveAvailabilityBuilder;

  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  late int _index = widget.liveRepository == null ? 0 : 3;
  bool _availabilityVisited = false;

  final _pages = const [
    CoachRosterScreen(),
    AvailabilityScreen(),
    EarningsScreen(),
    CoachAccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
          index: _index,
          children: widget.liveRepository == null
              ? _pages
              : [
                  for (final title in ['Roster', 'Availability', 'Earnings'])
                    if (title == 'Availability' &&
                        widget.liveAvailabilityBuilder != null)
                      _availabilityVisited
                          ? widget.liveAvailabilityBuilder!(context)
                          : const SizedBox.shrink()
                    else
                      Scaffold(
                          appBar: AppBar(title: Text(title)),
                          body: const Center(
                              child: Text(
                                  'Unavailable: this workflow is not connected to Firebase yet.'))),
                  CoachAccountScreen(
                      liveRepository: widget.liveRepository,
                      isCurrent: widget.isCurrent,
                      onOpenLiveEditor: widget.onOpenLiveEditor),
                ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == 1) _availabilityVisited = true;
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note_rounded),
              label: 'Roster'),
          NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Availability'),
          NavigationDestination(
              icon: Icon(Icons.payments_outlined),
              selectedIcon: Icon(Icons.payments_rounded),
              label: 'Earnings'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}
