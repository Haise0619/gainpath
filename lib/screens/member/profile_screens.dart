import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/change_password_sheet.dart';
import '../../widgets/shared.dart';
import '../auth/role_select_screen.dart';
import 'membership_screens.dart';
import 'reports_screens.dart';

/// AD-M1.3 — Fitness Profile Management, plus account settings and logout.
class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: AppColors.heroGradient,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(
                            child: Text('ZY',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                        Positioned(
                          right: -4,
                          bottom: -4,
                          child: Material(
                            color: AppColors.surface,
                            shape: const CircleBorder(),
                            elevation: 1,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () =>
                                  showToast(context, 'Photo upload is not part of this prototype.'),
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.hairline),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, size: 13, color: AppColors.primary),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(MockData.memberName,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(MockData.memberEmail,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accentTint,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Text('Premium member',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warning)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _QuickStat(Icons.wc_rounded, MockData.memberGender),
                    _QuickStat(Icons.cake_outlined, '${MockData.memberAge} yrs'),
                    _QuickStat(Icons.height_rounded, '${MockData.memberHeight} cm'),
                    _QuickStat(Icons.monitor_weight_outlined, '${MockData.memberWeight} kg'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Fitness profile'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                    context,
                    Icons.badge_outlined,
                    'Physical profile',
                    '${MockData.memberGender} · ${MockData.memberAge} yrs · ${MockData.memberHeight} cm · '
                        '${MockData.memberWeight} kg',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const PhysicalProfileScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.school_rounded, 'Experience level',
                    MockData.memberExperience,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ExperienceLevelScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.bolt_rounded, 'Activity level',
                    MockData.memberActivityLevel,
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ActivityLevelScreen()))),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.flag_rounded,
                    'Fitness goals',
                    '${MockData.memberTrainingFocus.length} focus areas  ·  3 targets',
                    () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GoalsScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(context, Icons.card_membership_rounded, 'Membership',
                    'Premium  ·  renews 12 Oct',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MembershipScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.insights_rounded, 'Progress and reports',
                    'Volume, form, and goals',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProgressDashboardScreen()))),
                const Divider(height: 1, indent: 62),
                _row(context, Icons.settings_outlined, 'Settings',
                    'Password, notifications, privacy',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AccountSettingsScreen()))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 19, color: AppColors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
    );
  }
}

/// AD-M1.2 — Gym Member logout is the one deliberate exception in this
/// system that skips a confirmation dialog: it is immediate and
/// irreversible once tapped. The brief in-progress overlay stands in for
/// background session-listener teardown, so the transition still reads as
/// deliberate rather than an instant jarring cut.
Future<void> _signOut(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SigningOutOverlay(),
  );
  await Future.delayed(const Duration(milliseconds: 550));
  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
    (r) => false,
  );
}

class _SigningOutOverlay extends StatelessWidget {
  const _SigningOutOverlay();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text('Signing out…', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickStat(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.inkSoft),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// AD-M1.3 — Physical profile: gender, age, height, and weight in one
/// workspace, since they are all "about you" attributes captured together
/// during onboarding and most naturally revisited together too.
class PhysicalProfileScreen extends StatefulWidget {
  const PhysicalProfileScreen({super.key});

  @override
  State<PhysicalProfileScreen> createState() => _PhysicalProfileScreenState();
}

class _PhysicalProfileScreenState extends State<PhysicalProfileScreen> {
  late String _gender = MockData.memberGender;
  double _age = MockData.memberAge.toDouble();
  double _height = MockData.memberHeight.toDouble();
  double _weight = MockData.memberWeight.toDouble();

  static const _genders = ['Female', 'Male', 'Prefer not to say'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Physical profile')),
      body: PageBody(
        children: [
          const Eyebrow('Gender'),
          Panel(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: _genders.map((g) {
                final selected = g == _gender;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(11),
                      onTap: () => setState(() => _gender = g),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Text(
                          g == 'Prefer not to say' ? 'Other' : g,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : AppColors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Age'),
          NumberDial(
            value: _age,
            min: 13,
            max: 80,
            suffix: '',
            display: '${_age.round()}',
            captionUnit: 'years old',
            onChanged: (v) => setState(() => _age = v),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Height'),
          NumberDial(
            value: _height,
            min: 130,
            max: 210,
            suffix: ' cm',
            display: '${_height.round()}',
            captionUnit: 'centimetres',
            onChanged: (v) => setState(() => _height = v),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Weight'),
          NumberDial(
            value: _weight,
            min: 35,
            max: 160,
            suffix: ' kg',
            display: '${_weight.round()}',
            captionUnit: 'kilograms',
            onChanged: (v) => setState(() => _weight = v),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Physical profile updated.');
            },
            child: const Text('Save changes'),
          ),
        ],
      ),
    );
  }
}

class ExperienceLevelScreen extends StatefulWidget {
  const ExperienceLevelScreen({super.key});

  @override
  State<ExperienceLevelScreen> createState() => _ExperienceLevelScreenState();
}

class _ExperienceLevelScreenState extends State<ExperienceLevelScreen> {
  String _level = MockData.memberExperience;

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
class ActivityLevelScreen extends StatefulWidget {
  const ActivityLevelScreen({super.key});

  @override
  State<ActivityLevelScreen> createState() => _ActivityLevelScreenState();
}

class _ActivityLevelScreenState extends State<ActivityLevelScreen> {
  late String _activity = MockData.memberActivityLevel;

  static const _options = [
    ['Sedentary', 'Little to no exercise', Icons.event_seat_rounded],
    ['Lightly active', 'Exercise 1–3 days a week', Icons.directions_walk_rounded],
    ['Moderately active', 'Exercise 3–5 days a week', Icons.directions_bike_rounded],
    ['Very active', 'Exercise 6–7 days a week', Icons.directions_run_rounded],
    ['Extremely active', 'Physical job plus daily training', Icons.bolt_rounded],
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
            onPressed: () {
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
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final Set<String> _focus = {...MockData.memberTrainingFocus};
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

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  bool _push = true;
  bool _email = false;
  bool _voice = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PageBody(
        children: [
          const Eyebrow('Notifications'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  value: _push,
                  onChanged: (v) => setState(() => _push = v),
                  title: const Text('Push notifications'),
                  subtitle: const Text('Session reminders and streak alerts'),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  value: _email,
                  onChanged: (v) => setState(() => _email = v),
                  title: const Text('Email updates'),
                  subtitle: const Text('Weekly progress summary'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Workout'),
          Panel(
            padding: EdgeInsets.zero,
            child: SwitchListTile(
              value: _voice,
              onChanged: (v) => setState(() => _voice = v),
              title: const Text('Voice coaching'),
              subtitle: const Text('Spoken cues during tracked sessions'),
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Security'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text('Change password'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showChangePasswordSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy and data'),
                  trailing:
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  onTap: () => showToast(context, 'Privacy settings.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deactivate account',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppColors.danger)),
                const SizedBox(height: 6),
                Text(
                  'Your account is held for 30 days before everything is permanently '
                  'deleted. You can sign back in during that window to keep it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: () => confirmSheet(context,
                      title: 'Deactivate your account?',
                      message:
                          'Access stops immediately. Everything is deleted for good after 30 days.',
                      confirmLabel: 'Deactivate',
                      destructive: true),
                  child: const Text('Deactivate account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
