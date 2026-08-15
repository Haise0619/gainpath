import 'package:flutter/material.dart';
import '../../app/theme.dart';
import 'login_screen.dart';

/// Prototype entry point for Windows desktop and mobile. In the real system
/// a single login resolves the role from the account record; this screen
/// exists so the prototype can be walked through as either a Gym Member or
/// a Fitness Coach. The Admin / Staff surface is reached only by running
/// the app on Web, see main.dart.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            _Hero(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CONTINUE AS', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 12),
                    _RoleCard(
                      icon: Icons.fitness_center_rounded,
                      title: 'Gym Member',
                      subtitle: 'Track workouts, earn rewards, book coaches',
                      onTap: () => _go(context, AppRole.member),
                    ),
                    const SizedBox(height: 10),
                    _RoleCard(
                      icon: Icons.sports_rounded,
                      title: 'Fitness Coach',
                      subtitle: 'Manage your roster, availability, and earnings',
                      onTap: () => _go(context, AppRole.coach),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Text(
                        'Frontend prototype. No account is required.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _go(BuildContext context, AppRole role) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen(role: role)));
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                ),
                child: const Icon(Icons.accessibility_new_rounded, color: AppColors.overlay, size: 24),
              ),
              const SizedBox(width: 12),
              Text('GainPath',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      )),
            ],
          ),
          const SizedBox(height: 40),
          Text(
            'Train with a coach\nin your pocket.',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                  fontSize: 32,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            'Real-time posture correction, progress you can see, and access to '
            'certified coaches at your gym.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.hairline),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppColors.inkSoft),
          ],
        ),
      ),
    );
  }
}

enum AppRole { member, coach, admin }
