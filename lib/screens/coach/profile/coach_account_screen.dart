import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../../auth/role_select_screen.dart';
import '../../member/coach_booking/coach_profile_screen.dart' as public;
import '../../member/coach_booking/widgets/coach_card.dart' show networkAvatar;
import 'certifications_screen.dart';
import 'coach_settings_screen.dart';
import 'edit_coach_profile_screen.dart';

/// AD-M8.3 — Coach Account & Profile Management hub. Deliberately framed
/// as a *professional identity* screen, not a personal one: where the
/// member profile leads with body stats and a "Premium member" badge,
/// this leads with directory status, verification, and business metrics —
/// what a coach running a practice actually cares about. Renamed from the
/// old `CoachProfileScreen` so it no longer collides with the
/// member-facing public coach page, which this screen can now open as a
/// live preview.
class CoachAccountScreen extends StatefulWidget {
  const CoachAccountScreen({super.key});

  @override
  State<CoachAccountScreen> createState() => _CoachAccountScreenState();
}

class _CoachAccountScreenState extends State<CoachAccountScreen> {
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {}); // refresh cert counts / edited bio on return
  }

  @override
  Widget build(BuildContext context) {
    final coach = MockData.currentCoach;
    final verifiedCerts =
        MockData.coachCertifications.where((c) => c.status == 'Verified').length;
    final pendingCerts =
        MockData.coachCertifications.where((c) => c.status == 'Pending review').length;

    return Scaffold(
      appBar: AppBar(title: const Text('My account')),
      body: PageBody(
        children: [
          _ProHeader(coach: coach),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: StatTile('${coach.rating}', 'Rating', valueColor: AppColors.accent)),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${coach.sessionsCompleted}', 'Sessions')),
              const SizedBox(width: 10),
              Expanded(child: StatTile('${coach.yearsExperience}y', 'Experience')),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => public.CoachProfileScreen(coach: coach))),
              icon: const Icon(Icons.visibility_outlined, size: 19),
              label: const Text('Preview public profile'),
            ),
          ),
          const SizedBox(height: 22),
          const Eyebrow('Professional profile'),
          Panel(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _row(
                  context,
                  Icons.edit_note_rounded,
                  'Bio & specialties',
                  'What members see in the directory',
                  () => _open(const EditCoachProfileScreen()),
                ),
                const Divider(height: 1, indent: 62),
                _row(
                  context,
                  Icons.workspace_premium_rounded,
                  'Certifications',
                  '$verifiedCerts verified'
                      '${pendingCerts > 0 ? ', $pendingCerts pending review' : ''}',
                  () => _open(const CertificationsScreen()),
                ),
                const Divider(height: 1, indent: 62),
                _row(
                  context,
                  Icons.photo_camera_rounded,
                  'Profile photo',
                  'Update your directory picture',
                  () => showToast(context, 'Photo upload is not part of this prototype.'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Eyebrow('Account'),
          Panel(
            padding: EdgeInsets.zero,
            child: _row(
              context,
              Icons.settings_outlined,
              'Settings',
              'Contact details, notifications, security',
              () => _open(const CoachSettingsScreen()),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded, size: 19),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    final ok = await confirmSheet(context,
        title: 'Sign out?',
        message: 'You will need to sign in again next time.',
        confirmLabel: 'Sign out',
        destructive: true);
    if (ok && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
        (r) => false,
      );
    }
  }

  Widget _row(BuildContext context, IconData icon, String title, String subtitle,
      VoidCallback onTap) {
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

/// Professional hero: online photo, name + verification, specialty, and a
/// live directory-status pill — the trust signal that distinguishes a
/// coach's account from a member's personal card.
class _ProHeader extends StatelessWidget {
  final Coach coach;
  const _ProHeader({required this.coach});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(width: 68, height: 68, child: networkAvatar(coach.imageUrl)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(coach.name,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                        ),
                        if (coach.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified_rounded, size: 18, color: Colors.white),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(coach.specialty,
                        style: const TextStyle(color: Colors.white70, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(coach.branch,
                        style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Live in directory',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
                ),
                Text('${coach.reviews} reviews',
                    style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
