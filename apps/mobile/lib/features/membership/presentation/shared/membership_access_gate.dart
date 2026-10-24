import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../../../app/di/coach_profile_factory.dart';
import '../../../../infrastructure/firebase/firebase_membership_access_repository.dart';

/// An outer entry gate only. Running workout guidance and stored data stay intact.
class MembershipAccessGate extends StatelessWidget {
  const MembershipAccessGate(
      {super.key,
      this.enabled = false,
      this.repository,
      required this.feature,
      required this.resourceId,
      required this.child});
  final bool enabled;
  final MembershipAccessRepository? repository;
  final MembershipAccessFeature feature;
  final String resourceId;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    if (repository != null) {
      return _AccessCheck(
          repository: repository!,
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
          session: session,
          builder: (_, current) => _AccessCheck(
              key: ValueKey(session.scope),
              repository: FirebaseMembershipAccessRepository(
                  scope: session.scope, isCurrent: current),
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
      required this.feature,
      required this.resourceId,
      required this.child});
  final MembershipAccessRepository repository;
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
        if (decision?.permitsEntry == true) {
          _exerciseAdmitted =
              widget.feature == MembershipAccessFeature.exercise;
          return widget.child;
        }
        final denied = decision?.outcome == MembershipAccessOutcome.denied;
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
                          ? 'Check your current membership to access this feature.'
                          : 'Connect and try again to check current access.',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  TextButton(
                      onPressed: () => setState(_load),
                      child: const Text('Check access again')),
                ])));
      });
}
