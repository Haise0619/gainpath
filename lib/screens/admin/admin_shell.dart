import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../data/mock_data.dart';
import '../../widgets/shared.dart';
import '../auth/login_screen.dart';
import '../auth/role_select_screen.dart';
import 'admin_dashboard_screens.dart';
import 'admin_users_screens.dart';
import 'admin_content_screens.dart';
import 'admin_reports_screens.dart';
import 'admin_recommendation_screens.dart';
import 'admin_settings_screens.dart';

class _Destination {
  final IconData icon;
  final IconData iconFilled;
  final String label;
  final String subtitle;
  final Widget page;
  const _Destination(this.icon, this.iconFilled, this.label, this.subtitle, this.page);
}

/// Persistent left-sidebar shell for the Admin / Staff Web Console, per
/// design doc Section 7.1: desktop-width administrative software favours a
/// sidebar over a bottom bar, and dense data over card-first mobile layout.
/// A shared top bar owns page chrome (title, search, notifications, the
/// signed-in admin) so every section reads as one console rather than five
/// independent mobile screens dropped into a sidebar frame.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _destinations = [
    _Destination(Icons.dashboard_outlined, Icons.dashboard_rounded, 'Dashboard',
        "How the facility is doing today", AdminDashboardScreen()),
    _Destination(Icons.people_outline_rounded, Icons.people_rounded, 'Users & Coaches',
        'Provision, verify, and manage accounts', AdminUsersScreen()),
    _Destination(Icons.folder_outlined, Icons.folder_rounded, 'Content',
        'Tutorials, rewards, and announcements', AdminContentScreen()),
    _Destination(Icons.auto_awesome_outlined, Icons.auto_awesome_rounded, 'Recommendations',
        'High-risk exercises and matched leads', RiskLeaderboardScreen()),
    _Destination(Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Reports',
        'Facility-wide analytics and exports', AdminReportsScreen()),
  ];

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
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final collapsed = constraints.maxWidth < 980;
          final current = _destinations[_index];
          return Row(
            children: [
              _Sidebar(
                collapsed: collapsed,
                selectedIndex: _index,
                destinations: _destinations,
                onSelect: (i) => setState(() => _index = i),
              ),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(title: current.label, subtitle: current.subtitle, onSignOut: _signOut),
                    Expanded(
                      child: IndexedStack(
                        index: _index,
                        children: _destinations.map((d) => d.page).toList(),
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
        if (v == 'settings') {
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
              children: [
                Text(MockData.adminName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(MockData.adminEmail, style: const TextStyle(fontSize: 11.5, color: AppColors.inkSoft)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: AppColors.inkSoft),
              SizedBox(width: 10),
              Text('Manage settings'),
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
        children: [
          const CircleAvatar(
            radius: 17,
            backgroundColor: AppColors.primaryTint,
            child: Icon(Icons.person_rounded, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more_rounded, size: 18, color: AppColors.inkSoft),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final bool collapsed;
  final int selectedIndex;
  final List<_Destination> destinations;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.collapsed,
    required this.selectedIndex,
    required this.destinations,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
              children: List.generate(destinations.length, (i) {
                final d = destinations[i];
                final selected = i == selectedIndex;
                final item = Material(
                  color: selected ? AppColors.primaryTint : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(i),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: collapsed ? 0 : 14, vertical: collapsed ? 14 : 12),
                      child: Row(
                        mainAxisAlignment:
                            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          Icon(selected ? d.iconFilled : d.icon,
                              size: 21, color: selected ? AppColors.primary : AppColors.inkSoft),
                          if (!collapsed) ...[
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                d.label,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  color: selected ? AppColors.primary : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
                return Padding(padding: const EdgeInsets.only(bottom: 4), child: item);
              }),
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
}
