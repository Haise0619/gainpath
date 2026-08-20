import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import '../auth/login_screen.dart';
import '../auth/role_select_screen.dart';
import 'admin_dashboard_screens.dart';
import 'admin_users_screens.dart';
import 'admin_recommendation_screens.dart';
import 'admin_settings_screens.dart';
import 'content/exercise_tutorials_screen.dart';
import 'content/routine_templates_screen.dart';
import 'equipment/equipment_catalog_screen.dart';
import 'governance/reward_catalog_screen.dart';
import 'governance/announcements_screen.dart';
import 'governance/chatbot_disclaimer_screen.dart';
import 'reports/reports_screen.dart';
import 'settings/system_settings_screen.dart';

/// A single directly-selectable sidebar destination.
class _NavPage {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final String subtitle;
  final Widget page;
  const _NavPage(this.icon, this.iconFilled, this.label, this.subtitle, this.page);
}

/// A sidebar destination that expands in place to reveal its children —
/// Content and Governance, per the console's structure. Never itself
/// selectable: it holds no page of its own, only a submenu.
class _NavGroup {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final List<_NavPage> children;
  const _NavGroup(this.icon, this.iconFilled, this.label, this.children);
}

/// Persistent left-sidebar shell for the Admin / Staff Web Console, per
/// design doc Section 7.1: desktop-width administrative software favours a
/// sidebar over a bottom bar, and dense data over card-first mobile layout.
/// A shared top bar owns page chrome (title, search, notifications, the
/// signed-in admin) so every section reads as one console rather than
/// independent mobile screens dropped into a sidebar frame — no section
/// ever pushes a new screen or shows a back button; the sidebar is the
/// only way to move between areas, exactly like a real admin website.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  final Set<String> _expanded = {'Content'};

  static const _destinations = <Object>[
    _NavPage(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard',
        'How the facility is doing today', AdminDashboardScreen()),
    _NavPage(Icons.people_outline_rounded, Icons.people_rounded, 'Users & Coaches',
        'Provision, verify, and manage accounts', AdminUsersScreen()),
    _NavGroup(Icons.folder_outlined, Icons.folder_rounded, 'Content', [
      _NavPage(Icons.video_library_outlined, Icons.video_library_rounded, 'Exercise Tutorials',
          'Manage the tutorial video library', ExerciseTutorialsScreen()),
      _NavPage(Icons.list_alt_outlined, Icons.list_alt_rounded, 'Routine Templates',
          'Author and assign workout blueprints', RoutineTemplatesScreen()),
    ]),
    _NavPage(Icons.fitness_center_outlined, Icons.fitness_center_rounded, 'Equipment Catalog',
        'Publish and retire gym-floor machines', EquipmentCatalogScreen()),
    _NavGroup(Icons.gavel_outlined, Icons.gavel_rounded, 'Governance', [
      _NavPage(Icons.card_giftcard_outlined, Icons.card_giftcard_rounded, 'Reward Catalog',
          'Points-shop inventory and stock', RewardCatalogScreen()),
      _NavPage(Icons.campaign_outlined, Icons.campaign_rounded, 'Announcements',
          'Broadcast messages to every member', AnnouncementsScreen()),
      _NavPage(Icons.smart_toy_outlined, Icons.smart_toy_rounded, 'AI Chatbot Disclaimer',
          'The safety notice shown before first use', ChatbotDisclaimerScreen()),
    ]),
    _NavPage(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Recommendations',
        'High-risk exercises and matched leads', RiskLeaderboardScreen()),
    _NavPage(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports',
        'Sales, branch performance, and analytics', ReportsScreen()),
    _NavPage(Icons.tune_outlined, Icons.tune_rounded, 'System Settings',
        'General, reward conversion, legal & compliance', SystemSettingsScreen()),
  ];

  List<_NavPage> get _flatPages {
    final pages = <_NavPage>[];
    for (final d in _destinations) {
      if (d is _NavPage) pages.add(d);
      if (d is _NavGroup) pages.addAll(d.children);
    }
    return pages;
  }

  String? _groupLabelFor(int flatIndex) {
    var cursor = 0;
    for (final d in _destinations) {
      if (d is _NavPage) {
        if (cursor == flatIndex) return null;
        cursor++;
      } else if (d is _NavGroup) {
        if (flatIndex >= cursor && flatIndex < cursor + d.children.length) return d.label;
        cursor += d.children.length;
      }
    }
    return null;
  }

  void _select(int flatIndex) {
    final owner = _groupLabelFor(flatIndex);
    setState(() {
      _index = flatIndex;
      if (owner != null) _expanded.add(owner);
    });
  }

  void _toggleGroup(String label) {
    setState(() {
      if (_expanded.contains(label)) {
        _expanded.remove(label);
      } else {
        _expanded.add(label);
      }
    });
  }

  Future<void> _signOut() async {
    final ok = await confirmSheet(context,
        title: 'Sign out of the console?',
        message: 'You will need to sign in again next time.',
        confirmLabel: 'Sign out',
        destructive: true);
    if (ok && mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => kIsWeb ? const LoginScreen(role: AppRole.admin) : const RoleSelectScreen(),
        ),
        (r) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final flatPages = _flatPages;
    final current = flatPages[_index];
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < 980;
          return Row(
            children: [
              _Sidebar(
                collapsed: collapsed,
                selectedIndex: _index,
                expandedGroups: _expanded,
                destinations: _destinations,
                onSelect: _select,
                onToggleGroup: _toggleGroup,
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(title: current.label, subtitle: current.subtitle, onSignOut: _signOut),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: flatPages.map((d) => d.page).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onSignOut;
  const _TopBar({required this.title, required this.subtitle, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
              ],
            ),
          ),
          SizedBox(
            width: 260,
            height: 40,
            child: TextField(
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search members, coaches, reports…',
                hintStyle: const TextStyle(fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                fillColor: AppColors.surfaceAlt,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          const _NotificationButton(),
          const SizedBox(width: 6),
          _ProfileMenu(onSignOut: onSignOut),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();

  static const _items = [
    ['Coach awaiting verification', 'Hafiz Aziz uploaded a certificate 2 days ago', Icons.workspace_premium_rounded, AppColors.warning],
    ['2 refund requests pending', 'Oldest submitted 3 days ago', Icons.receipt_long_rounded, AppColors.danger],
    ['3 members flagged at risk', 'Low form scores across recent sessions', Icons.warning_amber_rounded, AppColors.warning],
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Notifications',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      itemBuilder: (context) => [
        PopupMenuItem<int>(
          enabled: false,
          child: Text('Needs attention', style: Theme.of(context).textTheme.labelSmall),
        ),
        ..._items.map((n) => PopupMenuItem<int>(
              child: SizedBox(
                width: 280,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        color: (n[3] as Color).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(n[2] as IconData, size: 17, color: n[3] as Color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n[0] as String,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text(n[1] as String,
                              style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft), maxLines: 2),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
      ],
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.notifications_outlined, size: 19, color: AppColors.ink)),
            Positioned(
              top: 9,
              right: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenu extends StatelessWidget {
  final VoidCallback onSignOut;
  const _ProfileMenu({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        if (v == 'signout') onSignOut();
        if (v == 'account') {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(MockData.adminName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(MockData.adminEmail, style: TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'account',
          child: Row(
            children: [
              Icon(Icons.account_circle_outlined, size: 18, color: AppColors.inkSoft),
              SizedBox(width: 10),
              Text('My account'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              SizedBox(width: 10),
              Text('Sign out', style: TextStyle(color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryTint,
            child: Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
          ),
          SizedBox(width: 6),
          Icon(Icons.expand_more_rounded, size: 18, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final int selectedIndex;
  final Set<String> expandedGroups;
  final List<Object> destinations;
  final ValueChanged<int> onSelect;
  final ValueChanged<String> onToggleGroup;

  const _Sidebar({
    required this.collapsed,
    required this.selectedIndex,
    required this.expandedGroups,
    required this.destinations,
    required this.onSelect,
    required this.onToggleGroup,
  });

  @override
  Widget build(BuildContext context) {
    var flatCursor = 0;
    final items = <Widget>[];
    for (final d in destinations) {
      if (d is _NavPage) {
        final index = flatCursor++;
        items.add(_navTile(context,
            icon: d.icon,
            iconFilled: d.iconFilled,
            label: d.label,
            selected: index == selectedIndex,
            onTap: () => onSelect(index)));
      } else if (d is _NavGroup) {
        final firstChildIndex = flatCursor;
        final childIndices = List.generate(d.children.length, (i) => flatCursor + i);
        flatCursor += d.children.length;
        final expanded = expandedGroups.contains(d.label);
        final groupSelected = childIndices.contains(selectedIndex);

        if (collapsed) {
          // No room for a flyout in the narrow rail — jump straight to the
          // group's first child, same as tapping any other icon.
          items.add(_navTile(context,
              icon: d.icon,
              iconFilled: d.iconFilled,
              label: d.label,
              selected: groupSelected,
              onTap: () => onSelect(firstChildIndex)));
          continue;
        }

        items.add(_navTile(context,
            icon: d.icon,
            iconFilled: d.iconFilled,
            label: d.label,
            selected: groupSelected && !expanded,
            trailing: Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18, color: AppColors.inkSoft),
            onTap: () => onToggleGroup(d.label)));

        if (expanded) {
          for (var i = 0; i < d.children.length; i++) {
            final child = d.children[i];
            final index = childIndices[i];
            items.add(Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _navTile(context,
                  icon: child.icon,
                  iconFilled: child.iconFilled,
                  label: child.label,
                  selected: index == selectedIndex,
                  dense: true,
                  onTap: () => onSelect(index)),
            ));
          }
        }
      }
    }

    return Container(
      width: collapsed ? 84 : 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(collapsed ? 0 : 22, 26, collapsed ? 0 : 22, 22),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.accessibility_new_rounded, color: AppColors.overlay, size: 22),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GainPath', style: Theme.of(context).textTheme.titleMedium),
                        Text('Admin Console',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: collapsed ? 12 : 14),
              children: items,
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.all(collapsed ? 14 : 18),
            child: Row(
              mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primaryTint,
                  child: Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(MockData.adminName,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                        Text(MockData.adminEmail,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required IconData iconFilled,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    Widget? trailing,
    bool dense = false,
  }) {
    final item = Material(
      color: selected ? AppColors.primaryTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 14, vertical: collapsed ? 14 : (dense ? 10 : 12)),
          child: Row(
            mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Icon(selected ? iconFilled : icon,
                  size: dense ? 18 : 21, color: selected ? AppColors.primary : AppColors.inkSoft),
              if (!collapsed) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: dense ? 13 : 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected ? AppColors.primary : AppColors.ink,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ],
          ),
        ),
      ),
    );
    return Padding(padding: const EdgeInsets.only(bottom: 4), child: item);
  }
}
