import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show ActivityLevel, FitnessProfile;
import 'package:gainpath_identity/gainpath_identity.dart'
    show FitnessProfileCubit;
import 'save_live_profile.dart';

class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key, this.liveProfile, this.liveCubit});
  final FitnessProfile? liveProfile;
  final FitnessProfileCubit? liveCubit;

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  late String _activity = widget.liveProfile?.activity.label ??
      context.read<MemberProfileRepository>().memberActivityLevel;

  static const _options = [
    ['Sedentary', 'Little to no exercise', Icons.event_seat_rounded],
    [
      'Lightly active',
      'Exercise 1–3 days a week',
      Icons.directions_walk_rounded
    ],
    [
      'Moderately active',
      'Exercise 3–5 days a week',
      Icons.directions_bike_rounded
    ],
    ['Very active', 'Exercise 6–7 days a week', Icons.directions_run_rounded],
    [
      'Extremely active',
      'Physical job plus daily training',
      Icons.bolt_rounded
    ],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity level')),
      body: PageBody(
        children: [
          Text('Sets a realistic starting point for routine intensity.',
              style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          ..._options.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableListCard(
                  icon: a[2] as IconData,
                  label: a[0] as String,
                  description: a[1] as String,
                  selected: _activity == a[0],
                  onTap: () => setState(() => _activity = a[0] as String),
                ),
              )),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () async {
              if (widget.liveCubit != null) {
                await saveLiveProfile(
                    context,
                    widget.liveCubit!,
                    widget.liveProfile!.copyWith(
                      activity: ActivityLevel.values
                          .firstWhere((value) => value.label == _activity),
                    ));
                return;
              }
              Navigator.pop(context);
              showToast(context, 'Activity level set to $_activity.');
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// AD-M1.3 — Fitness goals. Two distinct, complementary concepts live here:
/// broad training focus (the categories chosen at onboarding, shaping
/// routine and content recommendations) and specific SMART targets (tracked
/// week to week against actuals on GoalProgressScreen).
