import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../data/mock_data.dart';
import '../../../widgets/shared.dart';
import '../admin_dialogs.dart';
import 'user_action_dialogs.dart';

const _pageSize = 24;

/// AD-M11.3 — the Member half of Manage User Accounts, split out from
/// Coaches because the two scale and present completely differently:
/// hundreds of members need search + pagination over a dense table,
/// while a handful of coaches (below) are grouped by branch instead.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _status = 'All';
  String _query = '';
  int _page = 0;

  void _refresh() => setState(() {});

  List<UserAccount> get _members => MockData.users.where((u) => u.role == 'Member').toList();

  @override
  Widget build(BuildContext context) {
    final all = _members;
    final activeCount = all.where((u) => u.status == 'Active').length;
    final suspendedCount = all.where((u) => u.status == 'Suspended').length;

    final filtered = all.where((u) {
      final matchesStatus = _status == 'All' || u.status == _status;
      final matchesQuery = _query.isEmpty ||
          u.name.toLowerCase().contains(_query.toLowerCase()) ||
          u.email.toLowerCase().contains(_query.toLowerCase());
      return matchesStatus && matchesQuery;
    }).toList();

    final pageCount = (filtered.length / _pageSize).ceil().clamp(1, 1 << 30);
    final page = _page.clamp(0, pageCount - 1);
    final start = page * _pageSize;
    final pageItems = filtered.skip(start).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _StatChip(icon: Icons.groups_rounded, label: 'Total members', value: '${all.length}'),
                _StatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Active',
                    value: '$activeCount',
                    color: AppColors.success),
                _StatChip(
                    icon: Icons.block_rounded,
                    label: 'Suspended',
                    value: '$suspendedCount',
                    color: AppColors.danger),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() {
                      _query = v;
                      _page = 0;
                    }),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Search by name or email',
                      prefixIcon: Icon(Icons.search_rounded, size: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ...['All', 'Active', 'Suspended'].map((s) {
                  final selected = s == _status;
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(s),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _status = s;
                        _page = 0;
                      }),
                      backgroundColor: AppColors.surface,
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
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
              ],
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.hairline),
              ),
              child: Column(
                children: [
                  const _TableHeader(),
                  const Divider(height: 1),
                  if (pageItems.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(36),
                      child: Center(
                        child: Text('No members match that search.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    )
                  else
                    ...List.generate(pageItems.length, (i) {
                      final u = pageItems[i];
                      return Column(
                        children: [
                          if (i > 0) const Divider(height: 1),
                          _MemberRow(user: u, onManage: () => _manage(context, u)),
                        ],
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('${filtered.length} of ${all.length} members',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                const Spacer(),
                if (pageCount > 1) _Pagination(page: page, pageCount: pageCount, onSelect: (p) => setState(() => _page = p)),
              ],
            ),
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
        RecordActionItem(
          icon: Icons.lock_reset_rounded,
          color: AppColors.primary,
          label: 'Reset password',
          onTap: () {
            Navigator.pop(context);
            resetPasswordFlow(context, user);
          },
        ),
        RecordActionItem(
          icon: Icons.block_rounded,
          color: AppColors.danger,
          label: user.status == 'Suspended' ? 'Lift suspension' : 'Suspend account',
          onTap: () {
            Navigator.pop(context);
            if (user.status == 'Suspended') {
              liftSuspensionFlow(context, user, _refresh);
            } else {
              suspendMemberFlow(context, user, _refresh);
            }
          },
        ),
      ],
    );
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final int pageCount;
  final ValueChanged<int> onSelect;
  const _Pagination({required this.page, required this.pageCount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageButton(context, icon: Icons.chevron_left_rounded, onTap: page > 0 ? () => onSelect(page - 1) : null),
        ...List.generate(pageCount, (i) => i).map((i) => _numberButton(context, i)),
        _pageButton(context, icon: Icons.chevron_right_rounded,
            onTap: page < pageCount - 1 ? () => onSelect(page + 1) : null),
      ],
    );
  }

  Widget _numberButton(BuildContext context, int i) {
    final selected = i == page;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected ? AppColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onSelect(i),
          child: SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: Text('${i + 1}',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppColors.inkSoft)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageButton(BuildContext context, {required IconData icon, required VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon, size: 19, color: onTap == null ? AppColors.hairline : AppColors.inkSoft),
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
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

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkSoft, letterSpacing: 0.4);
    return const Padding(
      padding: EdgeInsets.fromLTRB(14, 9, 12, 9),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text('MEMBER', style: style)),
          SizedBox(width: 120, child: Text('STATUS', style: style)),
          SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final UserAccount user;
  final VoidCallback onManage;
  const _MemberRow({required this.user, required this.onManage});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onManage,
        hoverColor: AppColors.surfaceAlt,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration:
                          BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.person_rounded, size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13)),
                          Text(user.email,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 120, child: statusPill(user.status)),
              SizedBox(
                width: 40,
                child: IconButton(
                  icon: const Icon(Icons.more_vert_rounded, size: 18),
                  onPressed: onManage,
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
