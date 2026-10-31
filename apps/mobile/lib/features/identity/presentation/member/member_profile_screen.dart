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
      this.bodyMetricsBuilder,
      this.membershipBuilder,
      this.membershipRepository,
      this.memberSettingsBuilder});

  final AuthSession? liveSession;
  final FitnessProfile? liveProfile;
  final VoidCallback? onOpenProgress;
  final WidgetBuilder? bodyMetricsBuilder, membershipBuilder;
  final WidgetBuilder? memberSettingsBuilder;
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
    final experience = live
        ? liveProfile?.experience.label ?? 'Not set'
        : mock!.memberExperience;
    final activity = live
        ? liveProfile?.activity.label ?? 'Not set'
        : mock!.memberActivityLevel;
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
      appBar: AppBar(title: const Text('Profile'), actions: [
        if (widget.membershipRepository != null)
          IconButton(
              tooltip: 'Refresh membership',
              onPressed: loading ? null : _refreshMembership,
              icon: const Icon(Icons.refresh_rounded)),
      ]),
      body: RefreshIndicator(
          onRefresh: _refreshMembership,
          child: PageBody(
            children: [
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MemberProfilePhoto(
                            key: ValueKey(liveSession), session: liveSession),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name,
                                  style:
                                      Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 4),
                              Tooltip(
                                message: email,
                                child: Text(email,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontSize: 13)),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeBackground,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(badge,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: badgeForeground)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: AppColors.hairline),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
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
              const SizedBox(height: 20),
              const Eyebrow('Fitness profile'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _row(
                        context,
                        Icons.badge_outlined,
                        'Physical profile',
                        live
                            ? '$gender · $ageLabel'
                            : '$gender · $ageLabel · $height · $weight',
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => PhysicalProfileScreen(
                                    liveProfile: liveProfile,
                                    liveCubit: liveSession == null
                                        ? null
                                        : context
                                            .read<FitnessProfileCubit>())))),
                    if (live) ...[
                      const _ProfileDivider(),
                      _row(
                          context,
                          Icons.monitor_weight_outlined,
                          'Body metrics',
                          '$height · $weight',
                          bodyMetricsBuilder == null
                              ? null
                              : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: bodyMetricsBuilder!))),
                    ],
                    const _ProfileDivider(),
                    _row(
                        context,
                        Icons.school_rounded,
                        'Experience level',
                        experience,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ExperienceLevelScreen(
                                    liveProfile: liveProfile,
                                    liveCubit: liveSession == null
                                        ? null
                                        : context
                                            .read<FitnessProfileCubit>())))),
                    const _ProfileDivider(),
                    _row(
                        context,
                        Icons.bolt_rounded,
                        'Activity level',
                        activity,
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ActivityLevelScreen(
                                    liveProfile: liveProfile,
                                    liveCubit: liveSession == null
                                        ? null
                                        : context
                                            .read<FitnessProfileCubit>())))),
                    const _ProfileDivider(),
                    _row(
                        context,
                        Icons.flag_rounded,
                        'Fitness goals',
                        liveSession == null
                            ? '${context.read<MemberProfileRepository>().memberTrainingFocus.length} focus areas  ·  3 targets'
                            : liveProfile == null
                                ? 'Set your fitness goals'
                                : '${liveProfile!.goals.length} focus ${liveProfile!.goals.length == 1 ? 'area' : 'areas'}',
                        () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => GoalsScreen(
                                    liveProfile: liveProfile,
                                    liveCubit: liveSession == null
                                        ? null
                                        : context
                                            .read<FitnessProfileCubit>())))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Eyebrow('Account'),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _row(context, Icons.card_membership_rounded, 'Membership',
                        membershipDetail, () => _openMembership(context)),
                    const _ProfileDivider(),
                    _row(
                        context,
                        Icons.insights_rounded,
                        'Progress and reports',
                        liveSession == null
                            ? 'Volume, form, and goals'
                            : 'Local sessions, repetitions and estimated form',
                        () => onOpenProgress != null
                            ? onOpenProgress!()
                            : Navigator.pushNamed(
                                context, FeatureNavigation.progress)),
                    const _ProfileDivider(),
                    _row(
                        context,
                        Icons.settings_outlined,
                        'Settings',
                        'Password, notifications, privacy',
                        () => liveSession == null
                            ? Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const AccountSettingsScreen()))
                            : Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: memberSettingsBuilder ??
                                        (_) => AccountSettingsScreen(
                                            contactSession: liveSession)))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout_rounded, size: 19),
                label: const Text('Sign out'),
              ),
            ],
          )),
    );
  }

  Widget _row(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback? onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      trailing: onTap == null
          ? null
          : const Icon(Icons.chevron_right_rounded, size: 22),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: 16,
      color: AppColors.hairline);
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.inkSoft),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

/// AD-M1.3 — Physical profile: gender, age, height, and weight in one
/// workspace, since they are all "about you" attributes captured together
/// during onboarding and most naturally revisited together too.
