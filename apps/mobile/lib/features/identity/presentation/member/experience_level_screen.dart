import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';

class ExperienceLevelScreen extends StatefulWidget {
  const ExperienceLevelScreen({super.key});

  @override
  State<ExperienceLevelScreen> createState() => _ExperienceLevelScreenState();
}

class _ExperienceLevelScreenState extends State<ExperienceLevelScreen> {
  late String _level = context.read<MemberProfileRepository>().memberExperience;

  static const _options = [
    ['Beginner', 'New to lifting, or returning after a long break', Icons.spa_outlined],
    ['Intermediate', 'Comfortable with the main lifts', Icons.trending_up_rounded],
    ['Advanced', 'Years of consistent training', Icons.military_tech_outlined],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Experience level')),
      body: PageBody(
        children: [
          Text('This changes how detailed your coaching cues are.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          ..._options.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableListCard(
                  icon: o[2] as IconData,
                  label: o[0] as String,
                  description: o[1] as String,
                  selected: _level == o[0],
                  onTap: () => setState(() => _level = o[0] as String),
                ),
              )),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Experience level set to $_level.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// New — Activity level was captured during onboarding (AD-M1.1) but had no
/// home to be revisited afterward; this closes that gap.
