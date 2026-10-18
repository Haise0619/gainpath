import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// The canonical availability layout, shared by local and persisted data adapters.
class AvailabilityPage extends StatelessWidget {
  const AvailabilityPage(
      {super.key,
      required this.weekAtGlance,
      required this.workingHours,
      required this.timeOff,
      required this.limits,
      this.header = const [],
      this.actions,
      this.onAddTimeOff,
      this.workingHoursTitle = 'Working hours'});
  final Widget weekAtGlance;
  final List<Widget> workingHours, timeOff, limits, header;
  final List<Widget>? actions;
  final VoidCallback? onAddTimeOff;
  final String workingHoursTitle;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Availability'), actions: actions),
        body: PageBody(children: [
          ...header,
          const Eyebrow('This week at a glance'),
          weekAtGlance,
          const SizedBox(height: 20),
          Eyebrow(workingHoursTitle),
          ...workingHours,
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Eyebrow('Time off and breaks'),
            TextButton.icon(
                onPressed: onAddTimeOff,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add')),
          ]),
          ...timeOff,
          const SizedBox(height: 20),
          const Eyebrow('Roster scheduling limits'),
          ...limits,
        ]),
      );
}
