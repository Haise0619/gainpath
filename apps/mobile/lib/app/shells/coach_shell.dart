import 'package:flutter/material.dart';
import '../../features/coaching/presentation/coach/roster_screen.dart';
import '../../features/coaching/presentation/coach/availability_screens.dart';
import '../../features/analytics/presentation/coach/earnings_screen.dart';
import '../../features/identity/presentation/coach/coach_account_screen.dart';
import '../di/coach_module8_dependencies.dart';

/// One Module 8 route tree; composition supplies Mock or Firebase data contracts.
class CoachShell extends StatefulWidget {
  const CoachShell(
      {super.key,
      this.module8,
      this.liveAvailabilityBuilder,
      this.liveRosterBuilder,
      this.restrictUnsupportedWorkflows = false,
      this.initialIndex = 0});
  final CoachModule8Dependencies? module8;
  final WidgetBuilder? liveAvailabilityBuilder, liveRosterBuilder;
  final bool restrictUnsupportedWorkflows;
  final int initialIndex;
  @override
  State<CoachShell> createState() => _CoachShellState();
}

class _CoachShellState extends State<CoachShell> {
  late int _index = widget.initialIndex;
  CoachModule8Dependencies? _module8;
  bool _availabilityVisited = false, _rosterVisited = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _module8 ??= widget.module8 ?? composeMockCoachModule8(context);
  }

  Widget unavailable(String title) => Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(
          child: Text(
              'Unavailable: this workflow is not connected to Firebase yet.')));
  @override
  Widget build(BuildContext context) {
    final dependencies = _module8!;
    return Scaffold(
        body: IndexedStack(index: _index, children: [
          widget.liveRosterBuilder != null
              ? (_rosterVisited
                  ? widget.liveRosterBuilder!(context)
                  : const SizedBox.shrink())
              : widget.restrictUnsupportedWorkflows
                  ? unavailable('Roster')
                  : const CoachRosterScreen(),
          widget.liveAvailabilityBuilder != null
              ? (_availabilityVisited
                  ? widget.liveAvailabilityBuilder!(context)
                  : const SizedBox.shrink())
              : widget.restrictUnsupportedWorkflows
                  ? unavailable('Availability')
                  : const AvailabilityScreen(),
          widget.restrictUnsupportedWorkflows
              ? unavailable('Earnings')
              : const EarningsScreen(),
          CoachAccountScreen(
              profileRepository: dependencies.profile,
              accountRepository: dependencies.account),
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() {
                  _index = i;
                  if (i == 1) _availabilityVisited = true;
                  if (i == 0) _rosterVisited = true;
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
            ]));
  }
}
