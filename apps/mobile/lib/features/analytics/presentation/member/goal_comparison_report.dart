import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../infrastructure/firebase/member_profile_repositories.dart';

class GoalComparisonHost extends StatelessWidget {
  const GoalComparisonHost({super.key, this.progress});
  final MemberLocalProgress? progress;
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
            auth.state.session?.scope == session.scope &&
            AuthRolePolicy.canEnter(auth.state,
                allowed: const {AppRole.member});
        return GoalComparisonReport(
            key: ValueKey(session.scope),
            repository:
                createNumericFitnessGoalRepository(session.scope, current),
            progress: progress,
            isCurrent: current);
      });
}

class GoalComparisonReport extends StatefulWidget {
  const GoalComparisonReport(
      {super.key,
      required this.repository,
      required this.progress,
      required this.isCurrent});
  final NumericFitnessGoalRepository repository;
  final MemberLocalProgress? progress;
  final bool Function() isCurrent;
  @override
  State<GoalComparisonReport> createState() => _GoalComparisonReportState();
}

class _GoalComparisonReportState extends State<GoalComparisonReport> {
  late Future<List<NumericFitnessGoal>> _goals;
  @override
  void initState() {
    super.initState();
    _goals = _read();
  }

  @override
  void didUpdateWidget(covariant GoalComparisonReport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) _goals = _read();
  }

  Future<List<NumericFitnessGoal>> _read() async {
    final repo = widget.repository;
    if (!widget.isCurrent() ||
        (widget.progress != null && widget.progress!.scope != repo.scope)) {
      throw StateError('Account changed');
    }
    final values = await repo.loadActive();
    if (!mounted || !widget.isCurrent() || repo != widget.repository) {
      throw StateError('Account changed');
    }
    return values;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isCurrent()) {
      return const Scaffold(
          body: Center(child: Text('Sign in to view this account’s targets.')));
    }
    return Scaffold(
        appBar: AppBar(title: const Text('Goal progress')),
        body: FutureBuilder<List<NumericFitnessGoal>>(
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
            final comparisons = progress == null
                ? targets
                    .map((g) => FitnessGoalComparison(
                        goal: g,
                        measuredValue: null,
                        measurementLabel:
                            'Saved workout measurements unavailable'))
                    .toList()
                : compareFitnessGoals(progress, targets);
            return PageBody(children: [
              const Text(
                  'Your saved numeric targets compared with available camera captures.'),
              const SizedBox(height: 12),
              const Panel(
                  child: Text(
                      'Local camera measurements are provisional. No achievement or reward is granted by this comparison.')),
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
                          Text(comparison.measuredValue == null
                              ? 'No measured value available'
                              : 'Measured: ${comparison.measuredValue!.toStringAsFixed(0)} ${comparison.goal.unit}'),
                          Text(comparison.measurementLabel),
                        ]))),
            ]);
          },
        ));
  }
}
