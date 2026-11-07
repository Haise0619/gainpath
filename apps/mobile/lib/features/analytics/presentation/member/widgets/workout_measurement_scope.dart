import 'package:flutter/material.dart';

/// Presentation only: explains the existing report populations without merging
/// routine attempts, camera captures, timed activity or scoring versions.
class WorkoutMeasurementScope extends StatelessWidget {
  const WorkoutMeasurementScope({super.key, this.formOnly = false});
  final bool formOnly;
  @override
  Widget build(BuildContext context) => ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('What these numbers include'),
          childrenPadding: const EdgeInsets.only(bottom: 12),
          children: [
            Text(formOnly
                ? 'Only saved camera attempts with a supported form estimate contribute to a score. Unassessed attempts are shown separately and never counted as 0%. Scores remain separated by exercise, scoring version, detector and camera view. Timed and manual activity has no form score.'
                : 'Camera charts count saved exercise sessions and measured repetitions, not completed routines. Video Timed active duration and self-reported manual sets belong to routine progress and are kept separate. Use the displayed dates and filters for the measurement period; totals labelled all-time span the saved history. Saving locally does not mean a result is backed up or server-verified.')
          ]);
}
