import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../../gamification/application/member_achievements_controller.dart';
import '../../../../gamification/domain/member_achievements.dart';
import '../../../../gamification/presentation/member/member_achievements_screen.dart';
import '../../../domain/workout_backup.dart';

class WorkoutAchievementFeedback extends StatefulWidget {
  const WorkoutAchievementFeedback({
    super.key,
    required this.controller,
    required this.status,
    required this.syncEnabled,
  });

  final MemberAchievementsController controller;
  final BackupRecordStatus status;
  final bool? syncEnabled;

  @override
  State<WorkoutAchievementFeedback> createState() =>
      _WorkoutAchievementFeedbackState();
}

class _WorkoutAchievementFeedbackState
    extends State<WorkoutAchievementFeedback> {
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshAfterBackup();
  }

  @override
  void didUpdateWidget(covariant WorkoutAchievementFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status ||
        oldWidget.controller != widget.controller) {
      _refreshAfterBackup();
    }
  }

  void _refreshAfterBackup() {
    if (widget.status != BackupRecordStatus.backedUp) return;
    _refreshing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_refresh());
    });
  }

  Future<void> _refresh() async {
    final controller = widget.controller;
    setState(() => _refreshing = true);
    await controller.refresh(changed: true);
    if (mounted && identical(controller, widget.controller)) {
      setState(() => _refreshing = false);
    }
  }

  String _message(MemberAchievements? data) {
    if (widget.status != BackupRecordStatus.backedUp) {
      if (widget.status == BackupRecordStatus.conflict ||
          widget.status == BackupRecordStatus.retryNeeded) {
        return 'Check the backup status above so your achievements can update.';
      }
      return widget.syncEnabled == false
          ? 'Turn on workout backup in Settings to update training achievements.'
          : 'Training achievements update after your workout syncs.';
    }
    if (_refreshing) return 'Checking your achievement progress…';
    if (data == null || widget.controller.stale || !data.complete) {
      return 'Your workout is synced. Achievement progress could not be confirmed.';
    }
    return 'Latest confirmed training progress';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          if (!widget.controller.current) return const SizedBox.shrink();
          final data = widget.controller.snapshot;
          final training = data?.badges
                  .where((badge) => badge.category == 'workout')
                  .toList() ??
              <MemberAchievement>[];
          final pending = training.where((badge) => !badge.unlocked).toList()
            ..sort((a, b) => b.fraction.compareTo(a.fraction));
          final showProgress = widget.status == BackupRecordStatus.backedUp &&
              !_refreshing &&
              !widget.controller.stale &&
              data?.complete == true;
          final next = showProgress ? pending.firstOrNull : null;
          return Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.military_tech_outlined,
                      color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Training achievements',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ]),
                const SizedBox(height: 8),
                Semantics(liveRegion: true, child: Text(_message(data))),
                if (next != null) ...[
                  const SizedBox(height: 12),
                  Text(next.title,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                      value: next.fraction,
                      semanticsLabel: next.title,
                      semanticsValue: next.progressLabel),
                  const SizedBox(height: 4),
                  Text(next.progressLabel),
                ] else if (showProgress && training.isNotEmpty)
                  const Text('All training badges unlocked'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilledButton.tonal(
                        onPressed: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                                builder: (_) => MemberAchievementsScreen(
                                    controller: widget.controller))),
                        child: const Text('View achievements')),
                    if (widget.status == BackupRecordStatus.backedUp &&
                        !_refreshing &&
                        !showProgress)
                      TextButton(
                          onPressed: _refresh, child: const Text('Retry')),
                  ],
                ),
              ],
            ),
          );
        },
      );
}
