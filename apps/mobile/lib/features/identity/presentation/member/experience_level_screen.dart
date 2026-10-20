import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show FitnessProfile, TrainingExperience;
import 'package:gainpath_identity/gainpath_identity.dart'
    show FitnessProfileCubit;
import 'save_live_profile.dart';
import 'module1_edit_guard.dart';

class ExperienceLevelScreen extends StatefulWidget {
  const ExperienceLevelScreen({super.key, this.liveProfile, this.liveCubit});
  final FitnessProfile? liveProfile;
  final FitnessProfileCubit? liveCubit;

  @override
  State<ExperienceLevelScreen> createState() => _ExperienceLevelScreenState();
}

class _ExperienceLevelScreenState extends State<ExperienceLevelScreen> {
  late String _level = widget.liveProfile?.experience.label ??
      context.read<MemberProfileRepository>().memberExperience;
  late final String _initialLevel = _level;
  bool _saving = false;

  static const _options = [
    [
      'Beginner',
      'New to lifting, or returning after a long break',
      Icons.spa_outlined
    ],
    [
      'Intermediate',
      'Comfortable with the main lifts',
      Icons.trending_up_rounded
    ],
    ['Advanced', 'Years of consistent training', Icons.military_tech_outlined],
  ];

  @override
  Widget build(BuildContext context) {
    return Module1EditGuard(
        dirty: _level != _initialLevel,
        busy: _saving,
        child: Scaffold(
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
                      onTap: () {
                        if (!_saving) setState(() => _level = o[0] as String);
                      },
                    ),
                  )),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        if (widget.liveCubit != null) {
                          setState(() => _saving = true);
                          await saveLiveProfile(
                              context,
                              widget.liveCubit!,
                              widget.liveProfile!.copyWith(
                                experience: TrainingExperience.values
                                    .firstWhere(
                                        (value) => value.label == _level),
                              ));
                          if (mounted) setState(() => _saving = false);
                          return;
                        }
                        Navigator.pop(context);
                        showToast(context,
                            'Preview experience level set to $_level.');
                      },
                child: Text(_saving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ));
  }
}

/// New — Activity level was captured during onboarding (AD-M1.1) but had no
/// home to be revisited afterward; this closes that gap.
