import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/member_profile_repositories.dart';
import '../../../workout/domain/routine_attempt.dart';

/// A display difference only; observation semantics and achievement holds remain.
String goalRemainingLabel(FitnessGoalComparison comparison) {
  final observed = comparison.measuredValue;
  if (observed == null) return 'Remaining target unavailable';
  final difference = comparison.goal.targetValue - observed;
  if (comparison.goal.category == NumericGoalCategory.bodyWeight) {
    if (difference == 0) {
      return 'Profile weight matches target · self-reported, date unknown';
    }
    return 'Profile weight is ${difference.abs().toStringAsFixed(1)} kg ${difference < 0 ? 'above' : 'below'} target · direction is not configured';
  }
  if (difference <= 0) return 'Target met in this provisional observation';
  return 'Remaining: ${difference.toStringAsFixed(0)} ${comparison.goal.category == NumericGoalCategory.trainingFrequency ? 'workouts' : comparison.goal.unit}';
}

String _workoutSummary(
    MemberLocalProgress progress, List<WorkoutGoalObservation>? workouts) {
  // Reporting uses Malaysia calendar boundaries; saved numeric goals retain UTC.
  final local = progress.asOf.add(const Duration(hours: 8));
  final start = DateTime.utc(local.year, local.month, local.day)
      .subtract(Duration(days: local.weekday - 1, hours: 8));
  final end = start.add(const Duration(days: 7));
  bool inWeek(DateTime time) => !time.isBefore(start) && time.isBefore(end);
  final captures = progress.records.where((r) => inWeek(r.endedAt)).length;
  if (workouts == null) {
    return 'Malaysia reporting week (Monday–Sunday, UTC+08:00): $captures camera captures. '
        'Workout attempts, distinct training days and completed routine days unavailable.';
  }
  final eligible = workouts.where((w) => !w.observedAt.isAfter(progress.asOf));
  final attempts = eligible.where((w) => inWeek(w.startedAt)).toList();
  final trainingDays = attempts
      .map((w) {
        final date = w.startedAt.add(const Duration(hours: 8));
        return '${date.year}-${date.month}-${date.day}';
      })
      .toSet()
      .length;
  final completed =
      eligible.where((w) => w.completed && inWeek(w.observedAt)).length;
  return 'Malaysia reporting week (Monday–Sunday, UTC+08:00): '
      '$captures camera captures · ${attempts.length} workout attempts started · '
      '$trainingDays distinct training days · $completed completed routine-day attempts. '
      'Only attempts with tracked activity or self-reported sets and a known start time are counted. '
      'Untimed legacy attempts and empty starts are excluded. '
      'Manual sets stay self-reported; these are local observations, not verified workouts.';
}

class GoalComparisonHost extends StatelessWidget {
  const GoalComparisonHost(
      {super.key,
      this.progress,
      this.routineProgress,
      this.onEditTargets,
      this.compact = false,
      this.onView});
  final bool compact;
  final VoidCallback? onView;
  final MemberLocalProgress? progress;
  final RoutineProgress? routineProgress;
  final Future<void> Function()? onEditTargets;
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        final session = state.session;
        if (session == null ||
            !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member}) ||
            (progress != null && progress!.scope != session.scope)) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s targets.')));
        }
        final auth = context.read<AuthBloc>();
        bool current() =>
            identical(auth.state.session, session) &&
            AuthRolePolicy.canEnter(auth.state,
                allowed: const {AppRole.member});
        return GoalComparisonReport(
            compact: compact,
            onView: onView,
            key: ObjectKey(session),
            repository:
                createNumericFitnessGoalRepository(session.scope, current),
            progress: progress,
            routineProgress: routineProgress,
            onEditTargets: onEditTargets,
            profileRepository:
                createReportFitnessProfileRepository(session.scope, current),
            isCurrent: current);
      });
}

class GoalComparisonReport extends StatefulWidget {
  const GoalComparisonReport(
      {super.key,
      required this.repository,
      required this.progress,
      required this.isCurrent,
      this.compact = false,
      this.onView,
      this.profileRepository,
      this.routineProgress,
      this.onEditTargets});
  final bool compact;
  final VoidCallback? onView;
  final NumericFitnessGoalRepository repository;
  final MemberLocalProgress? progress;
  final RoutineProgress? routineProgress;
  final Future<void> Function()? onEditTargets;
  final bool Function() isCurrent;
  final FitnessProfileRepository? profileRepository;
  @override
  State<GoalComparisonReport> createState() => _GoalComparisonReportState();
}

class _GoalComparisonReportState extends State<GoalComparisonReport> {
  late Future<List<NumericFitnessGoal>> _goals;
  double? _profileWeightKg;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _goals = _read();
  }

  @override
  void didUpdateWidget(covariant GoalComparisonReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.profileRepository != widget.profileRepository) {
      _goals = _read();
    }
  }

  Future<List<NumericFitnessGoal>> _read() async {
    final generation = ++_generation;
    final repo = widget.repository;
    if (!widget.isCurrent() ||
        (widget.progress != null && widget.progress!.scope != repo.scope)) {
      throw StateError('Account changed');
    }
    _profileWeightKg = null;
    final values = await repo.loadActive();
    double? profileWeight;
    final profileRepo = widget.profileRepository;
    if (profileRepo != null && profileRepo.scope == repo.scope) {
      try {
        profileWeight = (await profileRepo.load())?.weightKg.toDouble();
      } catch (_) {
        /* A missing profile cannot fabricate or block workout facts. */
      }
    }
    if (!mounted ||
        generation != _generation ||
        !widget.isCurrent() ||
        repo != widget.repository ||
        profileRepo != widget.profileRepository) {
      throw StateError('Account changed');
    }
    _profileWeightKg = profileWeight;
    return values;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent() ||
        (widget.progress != null &&
            widget.progress!.scope != widget.repository.scope)) {
      return const Scaffold(
          body: Center(child: Text('Sign in to view this account’s targets.')));
    }
    final content = FutureBuilder<List<NumericFitnessGoal>>(
      future: _goals,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Targets could not be loaded.'),
            FilledButton(
                onPressed: () => setState(() {
                      _goals = _read();
                    }),
                child: const Text('Retry')),
          ]));
        }
        final targets = snapshot.data!
            .where((g) => g.status == NumericGoalStatus.active)
            .toList();
        final progress = widget.progress;
        final routineProgress = widget.routineProgress;
        final workouts = routineProgress == null
            ? null
            : [
                for (final attempt in routineProgress.records)
                  if (attempt.scope == widget.repository.scope &&
                      attempt.startedAtMicros != null &&
                      (attempt.trackedDurationMicros > 0 ||
                          attempt.selfReportedSets > 0))
                    WorkoutGoalObservation(
                      id: attempt.id,
                      startedAt: DateTime.fromMicrosecondsSinceEpoch(
                          attempt.startedAtMicros!,
                          isUtc: true),
                      observedAt: DateTime.fromMicrosecondsSinceEpoch(
                          attempt.finishedAtMicros ?? attempt.updatedAtMicros,
                          isUtc: true),
                      cameraRepetitions: attempt.trackedDurationMicros > 0
                          ? attempt.fullRepetitions
                          : null,
                      manualSets: attempt.selfReportedSets,
                      context: '${attempt.routine.title} · day ${attempt.day}',
                      completed: attempt.isComplete,
                    ),
              ];
        final comparisons = progress == null
            ? targets
                .map((g) => FitnessGoalComparison(
                    goal: g,
                    measuredValue: null,
                    measurementLabel: 'Saved workout measurements unavailable'))
                .toList()
            : compareFitnessGoals(progress, targets,
                profileWeightKg: _profileWeightKg, workouts: workouts);
        if (widget.compact) {
          return Panel(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                const Text('Goal summary',
                    style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                if (comparisons.isEmpty) const Text('No targets set yet.'),
                for (final comparison in comparisons.take(2))
                  Padding(
                      padding: const EdgeInsets.only(top: 14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(comparison.goal.category.label,
                                style: const TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                                comparison.measuredValue == null
                                    ? 'Current: unavailable'
                                    : 'Current: ${comparison.measuredValue!.toStringAsFixed(comparison.goal.category == NumericGoalCategory.bodyWeight ? 1 : 0)} ${comparison.goal.unit}',
                                style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 12, runSpacing: 4, children: [
                              Text('Target: ${comparison.goal.targetLabel}',
                                  style: const TextStyle(
                                      color: AppColors.primaryDark,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  comparison.measuredValue == null
                                      ? 'Remaining: unavailable'
                                      : comparison.goal.category ==
                                              NumericGoalCategory.bodyWeight
                                          ? 'Gap: ${(comparison.goal.targetValue - comparison.measuredValue!).abs().toStringAsFixed(1)} kg · direction unset'
                                          : 'Remaining: ${(comparison.goal.targetValue - comparison.measuredValue!).clamp(0, double.infinity).toStringAsFixed(0)} ${comparison.goal.unit}',
                                  style: const TextStyle(
                                      color: AppColors.inkSoft)),
                            ]),
                            const SizedBox(height: 6),
                            Text(
                                comparison.goal.category ==
                                        NumericGoalCategory.bodyWeight
                                    ? 'Self-reported profile · measurement date unavailable'
                                    : 'Provisional local observation',
                                style: const TextStyle(
                                    color: AppColors.inkSoft, fontSize: 12)),
                          ])),
                TextButton(
                    onPressed: widget.onView,
                    child: const Text('View / edit goals')),
              ]));
        }
        return PageBody(children: [
          const Text(
              'Your saved targets compared with available camera captures and self-reported profile facts.'),
          const SizedBox(height: 12),
          FilledButton.icon(
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Set / edit targets'),
              onPressed: widget.onEditTargets == null
                  ? null
                  : () async {
                      await widget.onEditTargets!.call();
                      if (mounted && widget.isCurrent()) {
                        setState(() {
                          _goals = _read();
                        });
                      }
                    }),
          const SizedBox(height: 12),
          const Panel(
              child: Text(
                  'Local camera measurements are provisional. No achievement or reward is granted by this comparison.')),
          if (progress != null)
            ExpansionTile(
                title: const Text('How this week is counted'),
                children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_workoutSummary(progress, workouts)))
                ]),
          if (targets.isEmpty)
            const Text(
                'No active numeric targets yet. Set targets in Profile.'),
          for (final comparison in comparisons)
            Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(comparison.goal.category.label,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('Target: ${comparison.goal.targetLabel}'),
                      Text(comparison.goal.category.periodLabel),
                      Text(comparison.measuredValue == null
                          ? 'No measured value available'
                          : comparison.goal.category ==
                                  NumericGoalCategory.bodyWeight
                              ? 'Profile (self-reported): ${comparison.measuredValue!.toStringAsFixed(1)} kg'
                              : 'Measured: ${comparison.measuredValue!.toStringAsFixed(0)} ${comparison.goal.unit}'),
                      Text(goalRemainingLabel(comparison)),
                      Text(comparison.measurementLabel),
                    ]))),
        ]);
      },
    );
    return widget.compact
        ? content
        : Scaffold(
            appBar: AppBar(title: const Text('Goal progress')), body: content);
  }
}
