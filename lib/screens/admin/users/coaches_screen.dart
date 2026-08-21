import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';
import 'user_action_dialogs.dart';

/// AD-M11.3 — the Coach half of Manage User Accounts. Coaches are few
/// (a handful per branch) and organised by which physical location they
/// work out of, so this reads as branch sections of roster cards rather
/// than the dense searchable table Members uses.
class CoachesScreen extends StatefulWidget {
  const CoachesScreen({super.key});

  @override
  State<CoachesScreen> createState() => _CoachesScreenState();
}

class _CoachesScreenState extends State<CoachesScreen> {
  void _refresh() => setState(() {});

  List<UserAccount> get _coaches => MockData.users.where((u) => u.role == 'Coach').toList();

  Coach? _profileFor(UserAccount user) {
    for (final c in MockData.coaches) {
      if (c.name == user.name) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final coaches = _coaches;
    final pendingCount = coaches.where((c) => c.status == 'Pending').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatChip(icon: Icons.sports_rounded, label: 'Total coaches', value: '${coaches.length}'),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending review',
                    value: '$pendingCount',
                    color: AppColors.warning),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => provisionCoachFlow(context, _refresh),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 17),
                  label: const Text('Add a coach'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            ...MockData.branches.map((branch) {
              final roster = coaches.where((c) => c.branch == branch.name).toList();
              if (roster.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.storefront_outlined, size: 15, color: AppColors.inkSoft),
                        const SizedBox(width: 6),
                        Text('${branch.name}  ·  ${roster.length}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: roster
                          .map((c) => _CoachCard(
                                user: c,
                                profile: _profileFor(c),
                                onTap: () => _manage(context, c),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _manage(BuildContext context, UserAccount user) {
    showRecordActionsDialog(
      context,
      title: user.name,
      subtitle: user.email,
      actions: [
        if (user.status == 'Pending')
          RecordActionItem(
            icon: Icons.verified_rounded,
            color: AppColors.success,
            label: 'Review certifications',
            onTap: () {
              Navigator.pop(context);
              verifyCoachFlow(context, user, _refresh);
            },
          ),
        RecordActionItem(
          icon: Icons.lock_reset_rounded,
          color: AppColors.primary,
          label: 'Reset password',
          onTap: () {
            Navigator.pop(context);
            resetPasswordFlow(context, user);
          },
        ),
        if (user.status != 'Deactivated')
          RecordActionItem(
            icon: Icons.person_off_rounded,
            color: AppColors.danger,
            label: 'Deactivate coach',
            onTap: () {
              Navigator.pop(context);
              deactivateCoachFlow(context, user, _refresh);
            },
          ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  final UserAccount user;
  final Coach? profile;
  final VoidCallback onTap;
  const _CoachCard({required this.user, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: AppColors.accentTint, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.sports_rounded, size: 18, color: AppColors.warning),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(user.specialty ?? 'No specialty on file',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
            const SizedBox(height: 8),
            if (profile != null)
              Row(
                children: [
                  const Icon(Icons.star_rounded, size: 15, color: AppColors.accent),
                  const SizedBox(width: 3),
                  Text('${profile!.rating}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                  Text('${profile!.sessionsCompleted} sessions',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
                ],
              )
            else
              const Text('Not yet onboarded — no public profile',
                  style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            statusPill(user.status),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;
  const _StatChip({required this.icon, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      width: 190,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
