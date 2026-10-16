import 'package:flutter/material.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/feature_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, FitnessProfile;
import 'account_settings_screen.dart';
import 'member_profile_photo.dart';
import 'activity_level_screen.dart';
import 'experience_level_screen.dart';
import 'goals_screen.dart';
import 'physical_profile_screen.dart';

class MemberProfileScreen extends StatelessWidget {
  const MemberProfileScreen(
      {super.key,
      this.liveSession,
      this.liveProfile,
      this.onOpenProgress,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final VoidCallback? onOpenProgress;
  final WidgetBuilder? memberSettingsBuilder;

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
                    MemberProfilePhoto(
                        key: ValueKey(liveSession), session: liveSession),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              context
                                  .read<MemberProfileRepository>()
                                  .memberName,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                              context
                                  .read<MemberProfileRepository>()
                                  .memberEmail,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 6),
                          if (liveSession == null)
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
                    _QuickStat(Icons.wc_rounded,
                        context.read<MemberProfileRepository>().memberGender),
                    _QuickStat(Icons.cake_outlined,
                        '${context.read<MemberProfileRepository>().memberAge} yrs'),
                    _QuickStat(Icons.height_rounded,
                        '${context.read<MemberProfileRepository>().memberHeight} cm'),
                    _QuickStat(Icons.monitor_weight_outlined,
                        '${context.read<MemberProfileRepository>().memberWeight} kg'),
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
                    '${context.read<MemberProfileRepository>().memberGender} · ${context.read<MemberProfileRepository>().memberAge} yrs · ${context.read<MemberProfileRepository>().memberHeight} cm · '
                        '${context.read<MemberProfileRepository>().memberWeight} kg',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => PhysicalProfileScreen(
                                liveProfile: liveProfile,
                                liveCubit: liveSession == null
                                    ? null
                                    : context.read<FitnessProfileCubit>())))),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.school_rounded,
                    'Experience level',
                    context.read<MemberProfileRepository>().memberExperience,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ExperienceLevelScreen(
                                liveProfile: liveProfile,
                                liveCubit: liveSession == null
                                    ? null
                                    : context.read<FitnessProfileCubit>())))),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.bolt_rounded,
                    'Activity level',
                    context.read<MemberProfileRepository>().memberActivityLevel,
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ActivityLevelScreen(
                                liveProfile: liveProfile,
                                liveCubit: liveSession == null
                                    ? null
                                    : context.read<FitnessProfileCubit>())))),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.flag_rounded,
                    'Fitness goals',
                    liveSession == null
                        ? '${context.read<MemberProfileRepository>().memberTrainingFocus.length} focus areas  ·  3 targets'
                        : '${context.read<MemberProfileRepository>().memberTrainingFocus.length} focus areas',
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => GoalsScreen(
                                liveProfile: liveProfile,
                                liveCubit: liveSession == null
                                    ? null
                                    : context.read<FitnessProfileCubit>())))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                    context,
                    Icons.card_membership_rounded,
                    'Membership',
                    liveSession == null
                        ? 'Premium  ·  renews 12 Oct'
                        : 'Being connected',
                    () => liveSession == null
                        ? Navigator.pushNamed(
                            context, FeatureNavigation.membership)
                        : showUnavailable(context)),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.insights_rounded,
                    'Progress and reports',
                    liveSession == null
                        ? 'Volume, form, and goals'
                        : 'Local sessions, repetitions and estimated form',
                    () => onOpenProgress != null
                        ? onOpenProgress!()
                        : Navigator.pushNamed(
                            context, FeatureNavigation.progress)),
                const Divider(height: 1, indent: 62),
                _row(
                    context,
                    Icons.settings_outlined,
                    'Settings',
                    'Password, notifications, privacy',
                    () => liveSession == null
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountSettingsScreen()))
                        : memberSettingsBuilder == null
                            ? showUnavailable(context)
                            : Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: memberSettingsBuilder!))),
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
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
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
  context.read<AuthBloc>().add(const LoggedOut());
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
              child: CircularProgressIndicator(
                  strokeWidth: 2.6, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            Text('Signing out…',
                style: Theme.of(context).textTheme.titleMedium),
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
          Text(label,
              style:
                  const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// AD-M1.3 — Physical profile: gender, age, height, and weight in one
/// workspace, since they are all "about you" attributes captured together
/// during onboarding and most naturally revisited together too.
