import 'package:flutter/material.dart';

/// Both lists stay mounted so returning to a tab keeps its filters and scroll.
class WorkoutHistoryTabs extends StatefulWidget {
  const WorkoutHistoryTabs(
      {super.key,
      required this.routines,
      required this.sessions,
      required this.openSessions,
      required this.onRefresh,
      required this.onBackup});

  final Widget routines, sessions;
  final bool openSessions;
  final VoidCallback onRefresh, onBackup;

  @override
  State<WorkoutHistoryTabs> createState() => _WorkoutHistoryTabsState();
}

class _WorkoutHistoryTabsState extends State<WorkoutHistoryTabs> {
  late int _selected = widget.openSessions ? 1 : 0;

  @override
  Widget build(BuildContext context) {
    final scrollable = MediaQuery.textScalerOf(context).scale(14) > 21;
    return DefaultTabController(
        length: 2,
        initialIndex: _selected,
        child: Scaffold(
            appBar: AppBar(
                title: const Text('Workout history'),
                actions: [
                  IconButton(
                      tooltip: 'Workout backup',
                      onPressed: widget.onBackup,
                      icon: const Icon(Icons.cloud_upload_outlined)),
                  IconButton(
                      tooltip: 'Refresh history',
                      onPressed: widget.onRefresh,
                      icon: const Icon(Icons.refresh_rounded)),
                ],
                bottom: TabBar(
                    isScrollable: scrollable,
                    onTap: (index) => setState(() => _selected = index),
                    tabs: const [
                      Tab(text: 'Routines'),
                      Tab(text: 'Exercise sessions'),
                    ])),
            body: IndexedStack(index: _selected, children: [
              widget.routines,
              widget.sessions,
            ])));
  }
}
