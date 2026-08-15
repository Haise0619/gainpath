import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';

/// AD-M11.3 — Manage User Accounts.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  String _role = 'All';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    var visible = MockData.users.where((u) {
      final matchesRole = _role == 'All' || u.role == _role;
      final matchesQuery = _query.isEmpty ||
          u.name.toLowerCase().contains(_query.toLowerCase()) ||
          u.email.toLowerCase().contains(_query.toLowerCase());
      return matchesRole && matchesQuery;
    }).toList();

    final memberCount = MockData.users.where((u) => u.role == 'Member').length;
    final coachCount = MockData.users.where((u) => u.role == 'Coach').length;
    final pendingCount = MockData.users.where((u) => u.status == 'Pending').length;
    final suspendedCount = MockData.users.where((u) => u.status == 'Suspended').length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                _StatChip(icon: Icons.person_rounded, label: 'Members', value: '$memberCount'),
                _StatChip(icon: Icons.sports_rounded, label: 'Coaches', value: '$coachCount'),
                _StatChip(
                    icon: Icons.hourglass_top_rounded,
                    label: 'Pending review',
                    value: '$pendingCount',
                    color: AppColors.warning),
                _StatChip(
                    icon: Icons.block_rounded,
                    label: 'Suspended',
                    value: '$suspendedCount',
                    color: AppColors.danger),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search by name or email',
                      prefixIcon: Icon(Icons.search_rounded, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ...['All', 'Member', 'Coach'].map((r) {
                  final selected = r == _role;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(r),
                      selected: selected,
                      onSelected: (_) => setState(() => _role = r),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : AppColors.ink,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                        side: const BorderSide(color: AppColors.hairline),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _provision(context),
                  icon: const Icon(Icons.person_add_alt_rounded, size: 18),
                  label: const Text('Add a coach'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  const _TableHeader(),
                  const Divider(height: 1),
                  if (visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text('No users match that search.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    )
                  else
                    ...List.generate(visible.length, (i) {
                      final u = visible[i];
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1),
                          _UserRow(user: u, onManage: () => _manage(context, u)),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text('${visible.length} of ${MockData.users.length} accounts',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }

  void _manage(BuildContext context, UserAccount user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: Theme.of(ctx).textTheme.titleLarge),
            Text('${user.role}  ·  ${user.email}',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 18),
            if (user.role == 'Coach' && user.status == 'Pending')
              ListTile(
                leading: const Icon(Icons.verified_rounded,
                    color: AppColors.success),
                title: const Text('Review certifications'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => VerifyCoachScreen(user: user)));
                },
              ),
            if (user.role == 'Member')
              ListTile(
                leading: const Icon(Icons.block_rounded,
                    color: AppColors.danger),
                title: Text(user.status == 'Suspended'
                    ? 'Lift suspension'
                    : 'Suspend account'),
                onTap: () {
                  Navigator.pop(ctx);
                  showToast(context, 'Account updated.');
                },
              ),
            if (user.role == 'Coach')
              ListTile(
                leading: const Icon(Icons.person_off_rounded,
                    color: AppColors.danger),
                title: const Text('Deactivate coach'),
                onTap: () {
                  Navigator.pop(ctx);
                  confirmSheet(context,
                      title: 'Deactivate ${user.name}?',
                      message:
                          'Their profile is removed from the directory and upcoming sessions are cancelled.',
                      confirmLabel: 'Deactivate',
                      destructive: true);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _provision(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add a coach', style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text('They will get an email invitation to set their password.',
                style: Theme.of(ctx).textTheme.bodyMedium),
            const SizedBox(height: 18),
            const TextField(
                decoration: InputDecoration(labelText: 'Full name')),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(labelText: 'Work email')),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(labelText: 'Specialty')),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                showToast(context, 'Invitation sent.');
              },
              child: const Text('Send invitation'),
            ),
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
      width: 200,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: c.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: c),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.4);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          const Expanded(flex: 3, child: Text('ACCOUNT', style: style)),
          const SizedBox(width: 110, child: Text('ROLE', style: style)),
          const SizedBox(width: 120, child: Text('STATUS', style: style)),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final UserAccount user;
  final VoidCallback onManage;
  const _UserRow({required this.user, required this.onManage});

  @override
  Widget build(BuildContext context) {
    final isCoach = user.role == 'Coach';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManage,
        hoverColor: AppColors.surfaceAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isCoach ? AppColors.accentTint : AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(isCoach ? Icons.sports_rounded : Icons.person_rounded,
                          size: 17, color: isCoach ? AppColors.warning : AppColors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                          Text(user.email,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 110,
                child: Text(user.role, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              SizedBox(width: 120, child: statusPill(user.status)),
              SizedBox(
                width: 44,
                child: IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 19),
                  onPressed: onManage,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VerifyCoachScreen extends StatelessWidget {
  final UserAccount user;
  const VerifyCoachScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify credentials')),
      body: PageBody(
        children: [
          Panel(
            child: Column(
              children: [
                DetailRow('Coach', user.name),
                const Divider(height: 20),
                DetailRow('Email', user.email),
                const Divider(height: 20),
                const DetailRow('Submitted', '2 days ago'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Eyebrow('Uploaded document'),
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
              ),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.description_outlined,
                        size: 44, color: AppColors.inkSoft),
                    SizedBox(height: 10),
                    Text('NASM-CPT-Certificate.pdf',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              showToast(context, '${user.name} is now visible to members.');
            },
            child: const Text('Approve and publish profile'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              showToast(context, 'Sent back for correction.');
            },
            child: const Text('Reject and request a new upload'),
          ),
        ],
      ),
    );
  }
}
