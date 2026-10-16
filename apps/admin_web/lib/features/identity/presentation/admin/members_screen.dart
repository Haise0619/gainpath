import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'user_action_dialogs.dart';
import 'member_details_dialog.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const _pageSize = 24;

const _avatarPalette = [
  (AppColors.primaryTint, AppColors.primary),
  (AppColors.accentTint, AppColors.accentDark),
  (AppColors.successTint, AppColors.success),
  (AppColors.infoTint, AppColors.info),
  (AppColors.dangerTint, AppColors.danger),
];

/// A colored-initials avatar (the Slack/Notion pattern) instead of a
/// flat generic person icon — members have no profile photo on file, so
/// this is the honest alternative to inventing one. Color is picked
/// deterministically from the name so the same member always gets the
/// same color across renders.
class _InitialsAvatar extends StatelessWidget {
  final String name;
  static const _size = 28.0;
  const _InitialsAvatar({required this.name});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final palette = _avatarPalette[name.hashCode.abs() % _avatarPalette.length];
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: palette.$1, borderRadius: BorderRadius.circular(_size * 0.28)),
      child: Text(_initials,
          style: TextStyle(
              fontSize: _size * 0.4,
              fontWeight: FontWeight.w700,
              color: palette.$2)),
    );
  }
}

/// AD-M11.3 — the Member half of Manage User Accounts, split out from
/// Coaches because the two scale and present completely differently:
/// hundreds of members need search + pagination over a dense table,
/// while a handful of coaches (below) are grouped by branch instead.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key, this.live = false});
  final bool live;

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  String _status = 'All';
  String _query = '';
  int _page = 0;

  void _refresh() => setState(() {});

  List<UserAccount> get _members => context
      .read<UserAccountRepository>()
      .users
      .where((u) => u.role == 'Member')
      .toList();

  @override
  Widget build(BuildContext context) {
    if (widget.live) return const _LiveMembersView();
    final all = _members;
    final activeCount =
        all.where((u) => u.status == AccountStatus.active).length;
    final suspendedCount =
        all.where((u) => u.status == AccountStatus.suspended).length;

    final filtered = all.where((u) {
      final matchesStatus = _status == 'All' || u.status.label == _status;
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
                _StatChip(
                    icon: Icons.groups_rounded,
                    label: 'Total members',
                    value: '${all.length}'),
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
                          _MemberRow(
                              user: u, onManage: () => _manage(context, u)),
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
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontSize: 12)),
                const Spacer(),
                if (pageCount > 1)
                  _Pagination(
                      page: page,
                      pageCount: pageCount,
                      onSelect: (p) => setState(() => _page = p)),
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
          label: user.status == AccountStatus.suspended
              ? 'Lift suspension'
              : 'Suspend account',
          onTap: () {
            Navigator.pop(context);
            if (user.status == AccountStatus.suspended) {
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
  const _Pagination(
      {required this.page, required this.pageCount, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _pageButton(context,
            icon: Icons.chevron_left_rounded,
            onTap: page > 0 ? () => onSelect(page - 1) : null),
        ...List.generate(pageCount, (i) => i)
            .map((i) => _numberButton(context, i)),
        _pageButton(context,
            icon: Icons.chevron_right_rounded,
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

  Widget _pageButton(BuildContext context,
      {required IconData icon, required VoidCallback? onTap}) {
    return IconButton(
      icon: Icon(icon,
          size: 19,
          color: onTap == null ? AppColors.hairline : AppColors.inkSoft),
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
  const _StatChip(
      {required this.icon,
      required this.label,
      required this.value,
      this.color});

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
            decoration: BoxDecoration(
                color: c.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 17, color: c),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800)),
              Text(label,
                  style: const TextStyle(
                      fontSize: 11.5, color: AppColors.inkSoft)),
            ],
          )),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.inkSoft,
        letterSpacing: 0.4);
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
  final String name, email, statusLabel;
  final VoidCallback? onManage;
  final bool readOnly;
  _MemberRow({required UserAccount user, this.onManage})
      : name = user.name,
        email = user.email,
        statusLabel = user.status.label,
        readOnly = false;
  _MemberRow.member(AdminMemberRecord member, {this.onManage})
      : name = member.name,
        email = member.email,
        statusLabel = member.statusLabel,
        readOnly = true;

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
                    _InitialsAvatar(name: name),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontSize: 13)),
                          Text(email,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 120, child: statusPill(statusLabel)),
              SizedBox(
                width: 40,
                child: onManage == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: readOnly ? 'View details for $name' : null,
                        icon: Icon(
                            readOnly
                                ? Icons.visibility_outlined
                                : Icons.more_vert_rounded,
                            size: 18),
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

class _LiveMembersView extends StatefulWidget {
  const _LiveMembersView();
  @override
  State<_LiveMembersView> createState() => _LiveMembersViewState();
}

class _LiveMembersViewState extends State<_LiveMembersView> {
  List<AdminMemberRecord> _items = [];
  final _cursors = <String?>[null];
  String _query = '', _status = 'All';
  String? _next, _error;
  bool _loading = true;
  int _generation = 0;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    _debounce?.cancel();
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _items = [];
      _next = null;
    });
    try {
      final result = await context
          .read<AdminMemberDirectoryRepository>()
          .loadPage(query: _query, status: _status, afterId: _cursors.last);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = result.items;
        _next = result.nextCursor;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _error = 'Could not load members. Check your Admin access and retry.';
      });
    }
  }

  void _search(String value) {
    _debounce?.cancel();
    _generation++;
    setState(() {
      _query = value;
      _cursors
        ..clear()
        ..add(null);
      _items = [];
      _next = null;
      _loading = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.transparent,
        body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 22, 28, 36),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 12, runSpacing: 12, children: [
                _StatChip(
                    icon: Icons.groups_rounded,
                    label: 'Members on page',
                    value: '${_items.length}'),
                _StatChip(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Active on page',
                    value:
                        '${_items.where((e) => e.status == "active").length}',
                    color: AppColors.success),
                _StatChip(
                    icon: Icons.block_rounded,
                    label: 'Suspended on page',
                    value:
                        '${_items.where((e) => e.status == "suspended").length}',
                    color: AppColors.danger),
              ]),
              const SizedBox(height: 12),
              const Text(
                  'Organization membership records · Read-only directory'),
              const SizedBox(height: 18),
              Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                        width: 330,
                        child: TextField(
                            maxLength: 120,
                            onChanged: _search,
                            onSubmitted: (_) => _load(),
                            decoration: const InputDecoration(
                                counterText: '',
                                isDense: true,
                                hintText: 'Search by name or email',
                                prefixIcon:
                                    Icon(Icons.search_rounded, size: 19)))),
                    for (final status in ['All', 'Active', 'Suspended'])
                      ChoiceChip(
                          label: Text(status),
                          selected: _status == status,
                          onSelected: (_) {
                            _debounce?.cancel();
                            _status = status;
                            _cursors
                              ..clear()
                              ..add(null);
                            _load();
                          }),
                    IconButton(
                        tooltip: 'Refresh members',
                        onPressed: _loading
                            ? null
                            : () {
                                _cursors
                                  ..clear()
                                  ..add(null);
                                _load();
                              },
                        icon: const Icon(Icons.refresh_rounded)),
                  ]),
              const SizedBox(height: 14),
              if (_loading) const LinearProgressIndicator(),
              if (_error != null)
                Panel(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ]))
              else if (!_loading)
                Container(
                    decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.hairline)),
                    child: Column(children: [
                      const _TableHeader(),
                      const Divider(height: 1),
                      if (_items.isEmpty)
                        Padding(
                            padding: const EdgeInsets.all(36),
                            child: Text(_next != null
                                ? 'No matches in this batch. Continue to search more members.'
                                : _query.isNotEmpty || _status != 'All'
                                    ? 'No members match that search.'
                                    : 'No members found.')),
                      for (final item in _items) ...[
                        _MemberRow.member(item,
                            onManage: () => showDialog<void>(
                                context: context,
                                builder: (_) => MemberDetailsDialog(
                                    memberId: item.id,
                                    repository: context.read<
                                        AdminMemberDirectoryRepository>()))),
                        const Divider(height: 1),
                      ],
                    ])),
              const SizedBox(height: 12),
              Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                        'Page ${_cursors.length} · ${_items.length} matching members'),
                    TextButton(
                        onPressed: _loading || _cursors.length == 1
                            ? null
                            : () {
                                _cursors.removeLast();
                                _load();
                              },
                        child: const Text('Previous')),
                    TextButton(
                        onPressed: _loading || _next == null
                            ? null
                            : () {
                                _cursors.add(_next);
                                _load();
                              },
                        child: Text(_query.isNotEmpty || _status != 'All'
                            ? 'Continue search'
                            : 'Next')),
                  ]),
            ])));
  }
}
