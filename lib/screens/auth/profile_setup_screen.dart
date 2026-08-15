import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../widgets/shared.dart';
import '../member/member_shell.dart';

/// AD-M1.1 — ProfileSetupScreen. Shown once, immediately after a new Gym
/// Member account is created, so the AI Virtual Coach and recommendation
/// engine have a starting profile before the member reaches the app itself.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

enum _Gender { female, male, unspecified }

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const _steps = ['Gender', 'Age', 'Height', 'Weight', 'Goals', 'Activity'];
  static const _backdrop =
      'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?auto=format&fit=crop&w=1200&q=80';

  int _step = 0;
  _Gender? _gender;
  double _age = 25;
  double _height = 165;
  double _weight = 65;
  final Set<String> _goals = {};
  String? _activity;

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
      default:
        return true;
    }
  }

  void _next() {
    if (!_canContinue) return;
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

  void _finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MemberShell()),
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
                _Header(step: _step, total: _steps.length, onBack: _step > 0 ? _back : null),
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
                              child: _stepContent(context),
                            ),
                          ),
                          _Footer(
                            isLast: _step == _steps.length - 1,
                            enabled: _canContinue,
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
          subtitle: 'This helps calibrate posture and rep-scoring baselines.',
          child: Column(
            children: [
              SelectableListCard(
                icon: Icons.female_rounded,
                label: 'Female',
                selected: _gender == _Gender.female,
                onTap: () => setState(() => _gender = _Gender.female),
              ),
              const SizedBox(height: 12),
              SelectableListCard(
                icon: Icons.male_rounded,
                label: 'Male',
                selected: _gender == _Gender.male,
                onTap: () => setState(() => _gender = _Gender.male),
              ),
              const SizedBox(height: 12),
              SelectableListCard(
                icon: Icons.remove_circle_outline_rounded,
                label: 'Prefer not to say',
                selected: _gender == _Gender.unspecified,
                onTap: () => setState(() => _gender = _Gender.unspecified),
              ),
            ],
          ),
        );
      case 1:
        return _StepFrame(
          eyebrow: 'ABOUT YOU',
          title: 'How old are you?',
          subtitle: 'Used to keep training intensity and cues age-appropriate.',
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
          subtitle: 'Helps the pose model set expected joint proportions.',
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
          subtitle: 'Used for load suggestions and progress tracking, never shared publicly.',
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
          subtitle: 'Pick as many as apply. This shapes your recommended routines.',
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
      default:
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
    }
  }
}

class _Header extends StatelessWidget {
  final int step;
  final int total;
  final VoidCallback? onBack;
  const _Header({required this.step, required this.total, this.onBack});

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
  const _Footer({required this.isLast, required this.enabled, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: FilledButton(
        onPressed: enabled ? onNext : null,
        child: Text(isLast ? 'Finish setup' : 'Continue'),
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

