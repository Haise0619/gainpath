import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final Set<String> _focus = {...context.read<MemberProfileRepository>().memberTrainingFocus};
  final List<List<String>> _targets = [
    ['Train 4 times per week', 'Frequency'],
    ['Reach 85% average form', 'Technique'],
    ['Squat 70kg for 8 reps', 'Strength'],
  ];

  static const _focusOptions = [
    ['Lose weight', Icons.trending_down_rounded],
    ['Build muscle', Icons.fitness_center_rounded],
    ['Improve endurance', Icons.directions_run_rounded],
    ['Increase flexibility', Icons.self_improvement_rounded],
    ['General fitness', Icons.favorite_rounded],
    ['Reduce stress', Icons.spa_rounded],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fitness goals')),
      body: PageBody(
        children: [
          const Eyebrow('Training focus'),
          Text('Pick as many as apply. This shapes your recommended routines and content.',
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
              final icon = g[1] as IconData;
              final selected = _focus.contains(label);
              return ToggleChip(
                icon: icon,
                label: label,
                selected: selected,
                onTap: () => setState(() => selected ? _focus.remove(label) : _focus.add(label)),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Eyebrow('Specific targets'),
          Text('Measurable goals, tracked against your actuals on the Progress tab.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          ..._targets.map((g) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g[0],
                                style:
                                    Theme.of(context).textTheme.titleMedium),
                            Text(g[1],
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 19),
                        onPressed: () => setState(() => _targets.remove(g)),
                      ),
                    ],
                  ),
                ),
              )),
          OutlinedButton.icon(
            onPressed: () => showToast(context, 'Goal added.'),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add a goal'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              if (_focus.isEmpty) {
                showToast(context, 'Pick at least one training focus.');
                return;
              }
              Navigator.pop(context);
              showToast(context, 'Fitness goals updated.');
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}
