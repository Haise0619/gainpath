import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'session_host.dart';
import '../infrastructure/firebase/firebase_membership_access_repository.dart';
import '../features/membership/presentation/member/browse_plans_screen.dart';

/// Enable only with deployed access commands and an approved trusted policy.
const membershipAccessEnforcementEnabled =
    bool.fromEnvironment('MEMBERSHIP_ACCESS_ENFORCEMENT', defaultValue: false);

/// An outer entry gate only. Running workout guidance and stored data stay intact.
class MembershipAccessGate extends StatelessWidget {
  const MembershipAccessGate(
      {super.key,
      this.enabled = false,
      this.repository,
      this.repositoryFactory,
      this.freePreviewBuilder,
      required this.feature,
      required this.resourceId,
      required this.child});
  final bool enabled;
  final MembershipAccessRepository? repository;
  final MembershipAccessRepository Function(SessionScope, bool Function())?
      repositoryFactory;
  final Widget Function(BuildContext, Future<void> Function())?
      freePreviewBuilder;
  final MembershipAccessFeature feature;
  final String resourceId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    // Core digital fitness is included for every tier, even when paid evidence
    // is unknown. Account, consent and data ownership remain outer boundaries.
    if (feature == MembershipAccessFeature.exercise ||
        feature == MembershipAccessFeature.advancedReport) {
      return child;
    }
    if (!enabled) return child;
    if (repository != null) {
      return _AccessCheck(
          repository: repository!,
          freePreviewBuilder: freePreviewBuilder,
          feature: feature,
          resourceId: resourceId,
          child: child);
    }
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      final session = state.session;
      if (session == null) {
        return const Center(child: Text('Sign in to check membership access.'));
      }
      return CoachSessionHost(
          key: ObjectKey(session),
          session: session,
          cacheChild: false,
          builder: (_, current) => _AccessCheck(
              key: ValueKey(session.scope),
              repository: repositoryFactory?.call(session.scope, current) ??
                  FirebaseMembershipAccessRepository(
                      scope: session.scope, isCurrent: current),
              freePreviewBuilder: freePreviewBuilder,
              feature: feature,
              resourceId: resourceId,
              child: child));
    });
  }
}

class _AccessCheck extends StatefulWidget {
  const _AccessCheck(
      {super.key,
      required this.repository,
      this.freePreviewBuilder,
      required this.feature,
      required this.resourceId,
      required this.child});
  final MembershipAccessRepository repository;
  final Widget Function(BuildContext, Future<void> Function())?
      freePreviewBuilder;
  final MembershipAccessFeature feature;
  final String resourceId;
  final Widget child;
  @override
  State<_AccessCheck> createState() => _AccessCheckState();
}

class _AccessCheckState extends State<_AccessCheck>
    with WidgetsBindingObserver {
  Future<MembershipAccessDecision>? _decision;
  bool _exerciseAdmitted = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(_AccessCheck old) {
    super.didUpdateWidget(old);
    if (old.feature != widget.feature || old.resourceId != widget.resourceId) {
      _exerciseAdmitted = false;
      _load();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_exerciseAdmitted) {
      setState(_load);
    }
  }

  void _load() {
    _decision = widget.repository.check(widget.feature, widget.resourceId);
  }

  Future<void> _viewPlans() async {
    if (!mounted || !widget.repository.current) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => const BrowsePlansScreen(connected: true)));
    if (mounted && widget.repository.current) setState(_load);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<MembershipAccessDecision>(
      future: _decision,
      builder: (context, snapshot) {
        if (!widget.repository.current) {
          return const Center(
              child: Text('Membership access unavailable for this session.'));
        }
        // An entry decision never tears down an ongoing exercise's complete safety feedback.
        if (_exerciseAdmitted) return widget.child;
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final decision = snapshot.data;
        if (decision?.outcome == MembershipAccessOutcome.allowed) {
          _exerciseAdmitted =
              widget.feature == MembershipAccessFeature.exercise;
          return widget.child;
        }
        final denied = decision?.outcome == MembershipAccessOutcome.denied;
        if (denied &&
            decision?.effectiveTier == MembershipTier.free &&
            widget.freePreviewBuilder != null) {
          return widget.freePreviewBuilder!(context, _viewPlans);
        }
        return Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                      denied
                          ? (decision?.requiredTier == MembershipTier.premium
                              ? 'Premium membership required'
                              : 'Paid membership required')
                          : 'Membership access could not be verified',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                      denied
                          ? widget.feature == MembershipAccessFeature.coach
                              ? 'Coach booking is available with active Basic and Premium membership.'
                              : 'This feature is available with active Basic and Premium membership.'
                          : 'Connect and try again to check current access.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  if (denied)
                    FilledButton(
                        onPressed: _viewPlans,
                        child: const Text('View membership plans')),
                  TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('Check access again')),
                ])));
      });
}
