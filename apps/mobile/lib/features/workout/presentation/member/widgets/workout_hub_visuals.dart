import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

/// Foreground/container pairs: normal text >=4.5:1 in both themes.
class WorkoutHubTone {
  const WorkoutHubTone(this.ink, this.fill);
  final Color ink, fill;
}

class WorkoutHubPalette {
  const WorkoutHubPalette(
      this.primary, this.info, this.success, this.caution, this.neutral);
  final WorkoutHubTone primary, info, success, caution, neutral;
  static const light = WorkoutHubPalette(
    WorkoutHubTone(Color(0xFF7434BF), Color(0xFFF1EAFE)),
    WorkoutHubTone(Color(0xFF626778), Color(0xFFF1F2F5)),
    WorkoutHubTone(Color(0xFF237A4B), Color(0xFFEAF7EF)),
    WorkoutHubTone(Color(0xFF92400E), Color(0xFFFEF3C7)),
    WorkoutHubTone(Color(0xFF514B62), Color(0xFFF2EDFB)),
  );
  static const dark = WorkoutHubPalette(
    WorkoutHubTone(Color(0xFFD8C5FF), Color(0xFF302046)),
    WorkoutHubTone(Color(0xFFA8C7FA), Color(0xFF142C51)),
    WorkoutHubTone(Color(0xFF86EFAC), Color(0xFF123526)),
    WorkoutHubTone(Color(0xFFFCD34D), Color(0xFF3A2B14)),
    WorkoutHubTone(Color(0xFFD4CDE0), Color(0xFF30283E)),
  );
  static WorkoutHubPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
  List<WorkoutHubTone> get tones => [primary, info, success, caution, neutral];
}

class WorkoutHubBadge extends StatelessWidget {
  const WorkoutHubBadge(
      {super.key, required this.icon, required this.label, required this.tone});
  final IconData icon;
  final String label;
  final WorkoutHubTone tone;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        constraints: const BoxConstraints(minHeight: 27),
        decoration: BoxDecoration(
            color: tone.fill, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 15, color: tone.ink)),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tone.ink,
                      fontSize: 12,
                      height: 1.25,
                      fontWeight: FontWeight.w600))),
        ]),
      );
}

/// Current workout summary with the primary action ahead of supporting facts.
class WorkoutHubOverview extends StatelessWidget {
  const WorkoutHubOverview(
      {super.key,
      required this.title,
      required this.eyebrow,
      required this.exerciseCount,
      required this.totalSets,
      required this.minutes,
      required this.completed,
      required this.total,
      required this.status,
      required this.action,
      required this.actionIcon,
      required this.onStart,
      required this.shortcuts,
      this.switcher,
      this.scheduleStatus,
      this.support,
      this.supportSemantics});
  final String title, eyebrow, status, action;
  final String? scheduleStatus, support, supportSemantics;
  final int exerciseCount, totalSets, completed, total;
  final int? minutes;
  final Widget? switcher;
  final Widget shortcuts;
  final IconData actionIcon;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = WorkoutHubPalette.of(context);
    final done = total > 0 && completed >= total;
    final tone = done ? palette.success : palette.neutral;
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow,
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: palette.primary.ink, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(title, style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 52),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: onStart,
                      icon: Icon(actionIcon),
                      label: Text(action, textAlign: TextAlign.center))),
              const SizedBox(height: 4),
              shortcuts,
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final stacked = constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 21;
                final progress = Row(children: [
                  Semantics(
                      label: '$completed of $total exercises completed',
                      excludeSemantics: true,
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Stack(alignment: Alignment.center, children: [
                            SizedBox.expand(
                                child: CircularProgressIndicator(
                                    key:
                                        const ValueKey('workout-progress-ring'),
                                    value: total <= 0
                                        ? 0
                                        : (completed / total).clamp(0.0, 1.0),
                                    strokeWidth: 4,
                                    backgroundColor: tone.fill,
                                    color: tone.ink)),
                            Icon(
                                done
                                    ? Icons.check_rounded
                                    : Icons.fitness_center_rounded,
                                size: 19,
                                color: tone.ink),
                          ]))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('$completed / $total',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        Text(status,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ])),
                ]);
                return stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [progress, if (switcher != null) switcher!])
                    : Row(children: [
                        Expanded(child: progress),
                        if (switcher != null) switcher!
                      ]);
              }),
              if (scheduleStatus != null) ...[
                const SizedBox(height: 8),
                Text(scheduleStatus!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 18, runSpacing: 12, children: [
                _Fact(
                    icon: Icons.fitness_center_rounded,
                    value: '$exerciseCount',
                    label: 'Exercises',
                    tone: palette.neutral),
                _Fact(
                    icon: Icons.layers_outlined,
                    value: '$totalSets',
                    label: 'Sets',
                    tone: palette.neutral),
                if (minutes != null)
                  _Fact(
                      icon: Icons.schedule_rounded,
                      value: '~$minutes',
                      label: 'Minutes',
                      tone: palette.info),
              ]),
              const SizedBox(height: 16),
              if (support != null) ...[
                const SizedBox(height: 10),
                Semantics(
                    label: supportSemantics ?? support,
                    excludeSemantics: true,
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                              done
                                  ? Icons.check_circle_outline
                                  : Icons.save_outlined,
                              size: 16,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(support!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          theme.colorScheme.onSurfaceVariant))),
                        ])),
              ],
            ])),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(
      {required this.icon,
      required this.value,
      required this.label,
      required this.tone});
  final IconData icon;
  final String value, label;
  final WorkoutHubTone tone;
  @override
  Widget build(BuildContext context) => Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: tone.ink),
        const SizedBox(width: 6),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(width: 4),
        Flexible(
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))),
      ]));
}
