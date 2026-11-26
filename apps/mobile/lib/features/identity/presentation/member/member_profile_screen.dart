import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../../navigation/feature_navigation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, FitnessProfile;
import 'account_settings_screen.dart';
import 'member_profile_photo.dart';
import 'activity_level_screen.dart';
import 'experience_level_screen.dart';
import 'goals_screen.dart';
import 'physical_profile_screen.dart';

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen(
      {super.key,
      this.liveSession,
      this.liveProfile,
      this.onOpenProgress,
      this.onOpenAchievements,
      this.bodyMetricsBuilder,
      this.membershipBuilder,
      this.membershipRepository,
      this.memberSettingsBuilder,
      this.supportBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final VoidCallback? onOpenProgress;
  final VoidCallback? onOpenAchievements;
  final WidgetBuilder? bodyMetricsBuilder, membershipBuilder;
  final WidgetBuilder? memberSettingsBuilder, supportBuilder;
  final MembershipCommerceRepository? membershipRepository;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen>
    with WidgetsBindingObserver {
  Future<MembershipEntitlement>? _membership;
  AuthSession? get liveSession => widget.liveSession;
  FitnessProfile? get liveProfile => widget.liveProfile;
  WidgetBuilder? get bodyMetricsBuilder => widget.bodyMetricsBuilder;
  WidgetBuilder? get membershipBuilder => widget.membershipBuilder;
  WidgetBuilder? get memberSettingsBuilder => widget.memberSettingsBuilder;
  VoidCallback? get onOpenProgress => widget.onOpenProgress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _membership = _loadMembership();
  }

  @override
  void didUpdateWidget(MemberProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.membershipRepository != widget.membershipRepository ||
        !identical(oldWidget.liveSession, liveSession)) {
      _membership = _loadMembership();
    }
  }

  Future<MembershipEntitlement>? _loadMembership() {
    final repository = widget.membershipRepository;
    if (repository == null || !repository.current) return null;
    return Future.sync(() async {
      final data = await repository.load();
      if (!repository.current) throw StateError('Session changed.');
      return MembershipEntitlement.fromOverview(data);
    });
  }

  Future<void> _refreshMembership() async {
    if (!mounted) return;
    final next = _loadMembership();
    setState(() {
      _membership = next;
    });
    // FutureBuilder presents the error; refresh gestures must still finish.
    try {
      await next;
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshMembership());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openMembership(BuildContext context) async {
    if (membershipBuilder == null) {
      await Navigator.pushNamed(context, FeatureNavigation.membership);
    } else {
      await Navigator.push(
          context, MaterialPageRoute<void>(builder: membershipBuilder!));
    }
    if (mounted) await _refreshMembership();
  }

  @override
  Widget build(BuildContext context) {
    Widget profile() => FutureBuilder<MembershipEntitlement>(
        future: _membership,
        builder: (context, snapshot) => _buildProfile(context, snapshot));
    return liveSession == null
        ? profile()
        : BlocBuilder<AuthBloc, AuthState>(builder: (_, __) => profile());
  }

  Widget _buildProfile(
      BuildContext context, AsyncSnapshot<MembershipEntitlement> snapshot) {
    final live = liveSession != null;
    final mock = live ? null : context.read<MemberProfileRepository>();
    final ageLabel = live
        ? liveProfile?.ageLabel ?? 'Age not set'
        : '${mock!.memberAge} yrs';
    final name = live
        ? (liveSession!.displayName?.trim().isNotEmpty == true
            ? liveSession!.displayName!
            : 'Member')
        : mock!.memberName;
    final email = live ? liveSession!.email : mock!.memberEmail;
    final gender = live
        ? liveProfile?.gender.label ?? 'Gender not set'
        : mock!.memberGender;
    final height = live
        ? (liveProfile == null
            ? 'Height not set'
            : '${liveProfile!.heightCm} cm')
        : '${mock!.memberHeight} cm';
    final weight = live
        ? (liveProfile == null
            ? 'Weight not set'
            : '${liveProfile!.weightKg} kg')
        : '${mock!.memberWeight} kg';
    final loading =
        _membership != null && snapshot.connectionState != ConnectionState.done;
    final entitlement = snapshot.connectionState == ConnectionState.done &&
            widget.membershipRepository?.current == true &&
            !snapshot.hasError
        ? snapshot.data
        : null;
    final tier = entitlement?.effectiveTier;
    final resolved = entitlement?.isResolved == true;
    final cached = entitlement?.historicalOnly == true;
    final badge = loading
        ? 'Checking membership…'
        : !resolved
            ? 'Membership unavailable'
            : cached
                ? 'Last verified · ${tier!.label}'
                : '${tier!.label} member';
    final badgeBackground = switch (resolved && !cached ? tier : null) {
      MembershipTier.basic => AppColors.infoTint,
      MembershipTier.premium => AppColors.accentTint,
      _ => AppColors.membershipFreeTint,
    };
    final badgeForeground = switch (resolved && !cached ? tier : null) {
      MembershipTier.basic => AppColors.info,
      MembershipTier.premium => AppColors.accentDark,
      _ => AppColors.membershipFreeInk,
    };
    final expiry = entitlement?.paidExpiresAtMillis;
    final expiryLabel = expiry == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(expiry)
            .toLocal()
            .toString()
            .split(' ')
            .first;
    final membershipDetail = loading
        ? 'Checking your current plan…'
        : !resolved
            ? 'Open membership to check your plan'
            : cached
                ? 'Offline · Last verified ${tier!.label}${expiryLabel == null ? '' : ' · Recorded expiry $expiryLabel'}'
                : entitlement!.paidStatus == PaidMembershipStatus.expired
                    ? 'Free · Previous ${entitlement.paidTier!.label} expired $expiryLabel'
                    : tier == MembershipTier.free
                        ? 'Free · No expiry'
                        : '${tier!.label} · Active until $expiryLabel';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshMembership,
        child: PageBody(
          children: [
            // 1. Compact Modern Top Profile Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      MemberProfilePhoto(
                        key: ValueKey(liveSession),
                        session: liveSession,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 17,
                                    color: AppColors.ink,
                                    letterSpacing: -0.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Tooltip(
                              message: email,
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: badgeBackground,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                badge,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.2,
                                  color: badgeForeground,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.hairline),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _QuickStat(Icons.wc_rounded, gender),
                      _QuickStat(Icons.cake_outlined, ageLabel),
                      _QuickStat(Icons.height_rounded, height),
                      _QuickStat(Icons.monitor_weight_outlined, weight),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // 2. Fitness Profile Section
            _sectionHeader('Fitness profile'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _row(
                    context,
                    icon: Icons.badge_outlined,
                    title: 'Physical profile',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PhysicalProfileScreen(
                          liveProfile: liveProfile,
                          liveCubit: liveSession == null
                              ? null
                              : context.read<FitnessProfileCubit>(),
                        ),
                      ),
                    ),
                  ),
                  if (live) ...[
                    _rowDivider(),
                    _row(
                      context,
                      icon: Icons.monitor_weight_outlined,
                      title: 'Body metrics',
                      onTap: bodyMetricsBuilder == null
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: bodyMetricsBuilder!),
                              ),
                    ),
                  ],
                  _rowDivider(),
                  _row(
                    context,
                    icon: Icons.school_rounded,
                    title: 'Experience level',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ExperienceLevelScreen(
                          liveProfile: liveProfile,
                          liveCubit: liveSession == null
                              ? null
                              : context.read<FitnessProfileCubit>(),
                        ),
                      ),
                    ),
                  ),
                  _rowDivider(),
                  _row(
                    context,
                    icon: Icons.bolt_rounded,
                    title: 'Activity level',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityLevelScreen(
                          liveProfile: liveProfile,
                          liveCubit: liveSession == null
                              ? null
                              : context.read<FitnessProfileCubit>(),
                        ),
                      ),
                    ),
                  ),
                  _rowDivider(),
                  _row(
                    context,
                    icon: Icons.flag_rounded,
                    title: 'Fitness goals',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GoalsScreen(
                          liveProfile: liveProfile,
                          liveCubit: liveSession == null
                              ? null
                              : context.read<FitnessProfileCubit>(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // 3. Account Section
            _sectionHeader('Account'),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.hairline),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.025),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _row(
                    context,
                    icon: Icons.card_membership_rounded,
                    title: 'Membership',
                    accessibleDetail: membershipDetail,
                    onTap: () => _openMembership(context),
                  ),
                  _rowDivider(),
                  _row(
                    context,
                    icon: Icons.insights_rounded,
                    title: 'Progress and reports',
                    onTap: () => onOpenProgress != null
                        ? onOpenProgress!()
                        : Navigator.pushNamed(
                            context, FeatureNavigation.progress),
                  ),
                  if (widget.onOpenAchievements case final onOpen?) ...[
                    _rowDivider(),
                    _row(
                      context,
                      icon: Icons.military_tech_outlined,
                      title: 'View Achievements',
                      onTap: onOpen,
                    ),
                  ],
                  if (widget.supportBuilder case final support?) ...[
                    _rowDivider(),
                    _row(
                      context,
                      icon: Icons.support_agent_outlined,
                      title: 'Help & Support',
                      onTap: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: support)),
                    ),
                  ],
                  _rowDivider(),
                  _row(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () => liveSession == null
                        ? Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AccountSettingsScreen(),
                            ),
                          )
                        : Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: memberSettingsBuilder ??
                                  (_) => AccountSettingsScreen(
                                      contactSession: liveSession),
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),

            // 4. Sign Out Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: BorderSide(
                  color: AppColors.danger.withValues(alpha: 0.28),
                  width: 1.2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                minimumSize: const Size(double.infinity, 48),
              ),
              onPressed: () => _signOut(context),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Sign out',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
          color: AppColors.inkSoft.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    String? accessibleDetail,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(14.5);
    final isLargeText = textScale > 18;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: accessibleDetail != null &&
                        accessibleDetail.isNotEmpty &&
                        isLargeText
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            accessibleDetail,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (accessibleDetail != null &&
                              accessibleDetail.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                accessibleDetail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFB4ACCE),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _rowDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 50,
      endIndent: 16,
      color: AppColors.hairline,
    );
  }
}

/// Logout immediately invalidates account-scoped UI operations and listeners.
Future<void> _signOut(BuildContext context) async {
  context.read<AuthBloc>().add(const LoggedOut());
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _QuickStat(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F4FA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.hairline.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.5, color: AppColors.inkSoft),
          const SizedBox(width: 4.5),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
