import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../application/admin_reporting_gateway.dart';
import 'admin_remaining_analytics.dart';
import 'sections/commerce_sections.dart';
import 'sections/engagement_sections.dart';
import 'sections/operations_sections.dart';

/// Available workspaces in the Member Engagement Intelligence Dashboard.
enum EngagementTab {
  all('All Workspaces', Icons.dashboard_customize_outlined),
  overview('Overview', Icons.insights_rounded),
  memberActivity('Member Activity', Icons.people_outline_rounded),
  rewards('Rewards', Icons.card_giftcard_rounded),
  gamification('Gamification', Icons.sports_esports_outlined);

  const EngagementTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Comprehensive Member Engagement Intelligence Dashboard.
///
/// Houses four specialized workspaces plus a unified executive view:
/// 1. [EngagementTab.all] — All Workspaces (unified executive perspective)
/// 2. [EngagementTab.overview] — Platform Usage Pattern (observable server events)
/// 3. [EngagementTab.memberActivity] — Recorded Engagement & Returning Members (recency distribution & return rates)
/// 4. [EngagementTab.rewards] — Reward Redemptions (voucher lifecycle, collection trends & item mix)
/// 5. [EngagementTab.gamification] — Gamification Engagement (daily check-ins, mini-games, streak distributions & badge unlocks)
class AdminEngagementAnalytics extends StatefulWidget {
  const AdminEngagementAnalytics({
    super.key,
    required this.query,
    this.refreshToken = 0,
    this.live = false,
    this.operational = true,
    this.filter,
    this.usageKey,
    this.retentionKey,
    this.rewardsKey,
    this.gamificationKey,
    this.initialTab = EngagementTab.all,
  });

  final AdminReportQuery query;
  final int refreshToken;
  final bool live;
  final bool operational;
  final ReportFilter? filter;
  final GlobalKey? usageKey;
  final GlobalKey? retentionKey;
  final GlobalKey? rewardsKey;
  final GlobalKey? gamificationKey;
  final EngagementTab initialTab;

  @override
  State<AdminEngagementAnalytics> createState() =>
      AdminEngagementAnalyticsState();
}

class AdminEngagementAnalyticsState extends State<AdminEngagementAnalytics> {
  late EngagementTab _selectedTab;

  final GlobalKey _defaultUsageKey = GlobalKey();
  final GlobalKey _defaultRetentionKey = GlobalKey();
  final GlobalKey _defaultRewardsKey = GlobalKey();
  final GlobalKey _defaultGamificationKey = GlobalKey();

  EngagementTab get selectedTab => _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void selectTab(EngagementTab tab) {
    if (_selectedTab != tab) {
      setState(() => _selectedTab = tab);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabBar(),
        const SizedBox(height: 12),
        if (_selectedTab == EngagementTab.all) ...[
          _buildOverviewTab(),
          const SizedBox(height: 24),
          _buildMemberActivityTab(),
          const SizedBox(height: 24),
          _buildRewardsTab(),
          const SizedBox(height: 24),
          _buildGamificationTab(),
        ] else if (_selectedTab == EngagementTab.overview) ...[
          _buildOverviewTab(),
        ] else if (_selectedTab == EngagementTab.memberActivity) ...[
          _buildMemberActivityTab(),
        ] else if (_selectedTab == EngagementTab.rewards) ...[
          _buildRewardsTab(),
        ] else if (_selectedTab == EngagementTab.gamification) ...[
          _buildGamificationTab(),
        ],
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: EngagementTab.values.map((tab) {
            final isSelected = _selectedTab == tab;
            return InkWell(
              onTap: () => selectTab(tab),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: isSelected ? AppColors.primary : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tab.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color:
                            isSelected ? AppColors.primary : AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (widget.operational) {
      return AdminObservedSection(
        query: widget.query,
        anchorKey: widget.usageKey ?? _defaultUsageKey,
        refreshToken: widget.refreshToken,
      );
    }
    return UsageEngagementSection(
      anchorKey: widget.usageKey ?? _defaultUsageKey,
      filter: widget.filter ?? const ReportFilter(),
      live: widget.live,
    );
  }

  Widget _buildMemberActivityTab() {
    if (widget.operational) {
      return AdminObservedSection(
        query: widget.query,
        anchorKey: widget.retentionKey ?? _defaultRetentionKey,
        retention: true,
        refreshToken: widget.refreshToken,
      );
    }
    return RetentionRiskSection(
      anchorKey: widget.retentionKey ?? _defaultRetentionKey,
      live: widget.live,
    );
  }

  Widget _buildRewardsTab() {
    return RewardsSection(
      anchorKey: widget.rewardsKey ?? _defaultRewardsKey,
      live: widget.live,
      query: widget.operational ? widget.query : null,
      refreshToken: widget.refreshToken,
    );
  }

  Widget _buildGamificationTab() {
    return GamificationSection(
      anchorKey: widget.gamificationKey ?? _defaultGamificationKey,
      live: widget.live,
      query: widget.operational ? widget.query : null,
      refreshToken: widget.refreshToken,
    );
  }
}
