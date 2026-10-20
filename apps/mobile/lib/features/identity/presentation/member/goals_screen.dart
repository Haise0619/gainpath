import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart'
    show FitnessProfileCubit;
import 'save_live_profile.dart';
import 'numeric_fitness_targets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen(
      {super.key,
      this.liveProfile,
      this.liveCubit,
      this.goalRepository,
      this.liveSession,
      this.isSessionCurrent});
  final FitnessProfile? liveProfile;
  final FitnessProfileCubit? liveCubit;
  final NumericFitnessGoalRepository? goalRepository;
  final AuthSession? liveSession;
  final bool Function()? isSessionCurrent;
  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final Set<String> _focus = {
    ...?widget.liveProfile?.goals.map((goal) => goal.label),
    if (widget.liveProfile == null)
      ...context.read<MemberProfileRepository>().memberTrainingFocus,
  };
  late final Set<String> _initialFocus = {..._focus};
  bool _saving = false;
  bool _allowPop = false;
  bool get _dirty =>
      _focus.length != _initialFocus.length ||
      !_focus.containsAll(_initialFocus);

  static const _focusOptions = [
    ['Lose weight', Icons.trending_down_rounded],
    ['Build muscle', Icons.fitness_center_rounded],
    ['Improve endurance', Icons.directions_run_rounded],
    ['Increase flexibility', Icons.self_improvement_rounded],
    ['General fitness', Icons.favorite_rounded],
    ['Reduce stress', Icons.spa_rounded],
  ];

  Future<void> _back(bool didPop) async {
    if (didPop || _saving) return;
    final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Discard training-focus changes?'),
                content: const Text(
                    'Numeric targets already saved will stay saved.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep editing')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Discard'))
                ]));
    if (discard == true && mounted) {
      setState(() => _allowPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving && (!_dirty || _allowPop),
      onPopInvokedWithResult: (didPop, _) => _back(didPop),
      child: Scaffold(
        appBar: AppBar(title: const Text('Fitness goals')),
        body: PageBody(children: [
          const Eyebrow('Training focus'),
          Text(
              'Pick as many as apply. This shapes your recommended routines and content.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.7,
              children: _focusOptions.map((g) {
                final label = g[0] as String;
                final selected = _focus.contains(label);
                return ToggleChip(
                    icon: g[1] as IconData,
                    label: label,
                    selected: selected,
                    onTap: () {
                      if (!_saving) {
                        setState(() => selected
                            ? _focus.remove(label)
                            : _focus.add(label));
                      }
                    });
              }).toList()),
          const SizedBox(height: 20),
          FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_focus.isEmpty) {
                        showToast(context, 'Pick at least one training focus.');
                        return;
                      }
                      if (widget.liveCubit != null) {
                        setState(() {
                          _saving = true;
                          _allowPop = true;
                        });
                        await saveLiveProfile(
                            context,
                            widget.liveCubit!,
                            widget.liveProfile!.copyWith(
                                goals: FitnessGoal.values
                                    .where(
                                        (goal) => _focus.contains(goal.label))
                                    .toSet()));
                        if (mounted) {
                          setState(() {
                            _saving = false;
                            _allowPop = false;
                          });
                        }
                        return;
                      }
                      final mockFocus = context
                          .read<MemberProfileRepository>()
                          .memberTrainingFocus;
                      mockFocus
                        ..clear()
                        ..addAll(_focus);
                      setState(() => _allowPop = true);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          Navigator.pop(context);
                          showToast(context, 'Preview training focus updated.');
                        }
                      });
                    },
              child: Text(_saving ? 'Saving…' : 'Save changes')),
          const SizedBox(height: 24),
          NumericFitnessTargets(
              live: widget.liveProfile != null,
              session: widget.liveSession,
              repository: widget.goalRepository,
              isSessionCurrent: widget.isSessionCurrent),
        ]),
      ));
}
