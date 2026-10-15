import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../../../navigation/auth_navigation.dart';

/// Guided setup and editing for a member's private fitness profile.
/// Firebase callers supply persistence; the prototype keeps its demo route.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, this.initialProfile, this.onSave, this.onExit, this.onReload});

  final FitnessProfile? initialProfile;
  final Future<void> Function(FitnessProfile)? onSave;
  final VoidCallback? onExit;
  final Future<void> Function()? onReload;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _steps = ['Gender', 'Age', 'Height', 'Weight', 'Goals', 'Activity', 'Experience'];
  static const _backdrop =
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=1200&q=80';

  int _step = 0;
  ProfileGender? _gender;
  double _age = 25;
  double _height = 165;
  double _weight = 65;
  final Set<String> _goals = {};
  String? _activity;
  TrainingExperience? _experience;
  bool _saving = false;
  String? _error;
  bool _reloadRequired = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _gender = profile.gender;
      _age = profile.age.toDouble();
      _height = profile.heightCm.toDouble();
      _weight = profile.weightKg.toDouble();
      _goals.addAll(profile.goals.map((goal) => goal.label));
      _activity = profile.activity.label;
      _experience = profile.experience;
    }
  }

  static const _goalOptions = [
    ['Lose weight', Icons.trending_down_rounded],
    ['Build muscle', Icons.fitness_center_rounded],
    ['Improve endurance', Icons.directions_run_rounded],
    ['Increase flexibility', Icons.self_improvement_rounded],
    ['General fitness', Icons.favorite_rounded],
    ['Reduce stress', Icons.spa_rounded],
  ];

  static const _activityOptions = [
    ['Sedentary', 'Little to no exercise', Icons.event_seat_rounded],
    ['Lightly active', 'Exercise 1–3 days a week', Icons.directions_walk_rounded],
    ['Moderately active', 'Exercise 3–5 days a week', Icons.directions_bike_rounded],
    ['Very active', 'Exercise 6–7 days a week', Icons.directions_run_rounded],
    ['Extremely active', 'Physical job plus daily training', Icons.bolt_rounded],
  ];

  bool get _canContinue {
    switch (_step) {
      case 0:
        return _gender != null;
      case 4:
        return _goals.isNotEmpty;
      case 5:
        return _activity != null;
      case 6:
        return _experience != null;
      default:
        return true;
    }
  }

  void _next() {
    if (!_canContinue || _saving || _reloadRequired) return;
    if (_step == _steps.length - 1) {
      _finish();
      return;
    }
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) return;
    setState(() => _step--);
  }

  Future<void> _finish() async {
    if (widget.onSave != null) {
      setState(() { _saving = true; _error = null; });
      try {
        await widget.onSave!(FitnessProfile(
          editBaseline: widget.initialProfile?.editBaseline,
          gender: _gender!, age: _age.round(), heightCm: _height.round(),
          weightKg: _weight.round(), experience: _experience!,
          activity: ActivityLevel.values.firstWhere((level) => level.label == _activity),
          goals: FitnessGoal.values.where((goal) => _goals.contains(goal.label)).toSet(),
        ));
      } catch (error) {
        if (mounted) {
          setState(() {
            _error = error is FitnessProfileException
                ? error.message : 'Could not save your profile. Please retry.';
            _reloadRequired = error is FitnessProfileException && error.reloadRequired;
          });
        }
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.member,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            _backdrop,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: AppColors.ink),
            errorBuilder: (context, error, stack) =>
                const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryDark.withValues(alpha: 0.72),
                  AppColors.primaryDark.withValues(alpha: 0.55),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _Header(step: _step, total: _steps.length,
                  onBack: _step > 0 && !_saving ? _back : null,
                  onExit: widget.initialProfile != null && _saving ? null : widget.onExit,
                  exitLabel: widget.initialProfile == null ? 'Sign out' : 'Cancel'),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Container(
                      key: ValueKey(_step),
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8),
                      decoration: const BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                              child: AbsorbPointer(absorbing: _saving, child: _stepContent(context)),
                            ),
                          ),
                          if (_error != null) Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Semantics(liveRegion: true, child: Text(_error!,
                              style: TextStyle(color: Theme.of(context).colorScheme.error))),
                          ),
                          if (_reloadRequired && widget.onReload != null) ...[
                            const Text('Reload discards this form.'),
                            TextButton(onPressed: widget.onReload,
                                child: const Text('Reload saved profile')),
                          ],
                          _Footer(
                            isLast: _step == _steps.length - 1,
                            enabled: _canContinue && !_saving && !_reloadRequired,
                            saving: _saving,
                            editing: widget.initialProfile != null,
                            onNext: _next,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepContent(BuildContext context) {
    switch (_step) {
      case 0:
        return _StepFrame(
          eyebrow: 'ABOUT YOU',
          title: "What's your gender?",
          subtitle: 'Choose what you are comfortable sharing in your private profile.',
          child: Column(
            children: [
              SelectableListCard(
                icon: Icons.female_rounded,
                label: 'Female',
                selected: _gender == ProfileGender.female,
                onTap: () => setState(() => _gender = ProfileGender.female),
              ),
              const SizedBox(height: 12),
              SelectableListCard(
                icon: Icons.male_rounded,
                label: 'Male',
                selected: _gender == ProfileGender.male,
                onTap: () => setState(() => _gender = ProfileGender.male),
              ),
              const SizedBox(height: 12),
              SelectableListCard(
                icon: Icons.remove_circle_outline_rounded,
                label: 'Prefer not to say',
                selected: _gender == ProfileGender.unspecified,
                onTap: () => setState(() => _gender = ProfileGender.unspecified),
              ),
            ],
          ),
        );
      case 1:
        return _StepFrame(
          eyebrow: 'ABOUT YOU',
          title: 'How old are you?',
          subtitle: 'Add your current age to your fitness profile.',
          child: NumberDial(
            value: _age,
            min: 13,
            max: 80,
            suffix: '',
            display: '${_age.round()}',
            captionUnit: 'years old',
            onChanged: (v) => setState(() => _age = v),
          ),
        );
      case 2:
        return _StepFrame(
          eyebrow: 'PHYSICAL METRICS',
          title: "What's your height?",
          subtitle: 'Record your height in centimetres.',
          child: NumberDial(
            value: _height,
            min: 130,
            max: 210,
            suffix: ' cm',
            display: '${_height.round()}',
            captionUnit: 'centimetres',
            onChanged: (v) => setState(() => _height = v),
          ),
        );
      case 3:
        return _StepFrame(
          eyebrow: 'PHYSICAL METRICS',
          title: "What's your weight?",
          subtitle: 'Record your current weight. Your profile is private.',
          child: NumberDial(
            value: _weight,
            min: 35,
            max: 160,
            suffix: ' kg',
            display: '${_weight.round()}',
            captionUnit: 'kilograms',
            onChanged: (v) => setState(() => _weight = v),
          ),
        );
      case 4:
        return _StepFrame(
          eyebrow: 'MOTIVATION',
          title: 'What are you working towards?',
          subtitle: 'Pick as many as apply. You can update your goals later.',
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.35,
            children: _goalOptions.map((g) {
              final label = g[0] as String;
              final icon = g[1] as IconData;
              final selected = _goals.contains(label);
              return ToggleChip(
                icon: icon,
                label: label,
                selected: selected,
                onTap: () => setState(() => selected ? _goals.remove(label) : _goals.add(label)),
              );
            }).toList(),
          ),
        );
      case 5:
        return _StepFrame(
          eyebrow: 'TRAINING RHYTHM',
          title: "What's your activity level?",
          subtitle: 'Sets a realistic starting point — you can change this any time.',
          child: Column(
            children: _activityOptions.map((a) {
              final label = a[0] as String;
              final desc = a[1] as String;
              final icon = a[2] as IconData;
              final selected = _activity == label;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableListCard(
                  icon: icon,
                  label: label,
                  description: desc,
                  selected: selected,
                  onTap: () => setState(() => _activity = label),
                ),
              );
            }).toList(),
          ),
        );
      default:
        return _StepFrame(
          eyebrow: 'TRAINING EXPERIENCE',
          title: 'How experienced are you?',
          subtitle: 'Choose your current level. You can change it as you progress.',
          child: Column(children: TrainingExperience.values.map((level) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SelectableListCard(
              icon: Icons.fitness_center_rounded, label: level.label,
              selected: _experience == level,
              onTap: () => setState(() => _experience = level),
            ),
          )).toList()),
        );
    }
  }
}

class _Header extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback? onBack;
  final VoidCallback? onExit;
  final String exitLabel;
  const _Header({required this.step, required this.total, this.onBack, this.onExit, required this.exitLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: onBack == null
                    ? null
                    : IconButton(
                        onPressed: onBack,
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16)),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                      ),
              ),
              const Spacer(),
              if (onExit != null) TextButton(
                onPressed: onExit,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(exitLabel),
              ),
              Text('Step ${step + 1} of $total',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(total, (i) {
              final done = i <= step;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: done ? AppColors.overlay : Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  final bool isLast;
  final bool enabled;
  final VoidCallback onNext;
  final bool saving;
  final bool editing;
  const _Footer({required this.isLast, required this.enabled, required this.onNext,
    required this.saving, required this.editing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: FilledButton(
        onPressed: enabled ? onNext : null,
        child: Text(saving ? 'Saving…' : isLast ? (editing ? 'Save changes' : 'Finish setup') : 'Continue'),
      ),
    );
  }
}

class _StepFrame extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String subtitle;
  final Widget child;
  const _StepFrame({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(eyebrow),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}
