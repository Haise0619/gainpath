import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../infrastructure/firebase/firebase_membership_repository.dart';
import '../../features/membership/data/mock_membership_commerce.dart';
import 'coach_profile_factory.dart';

/// Rollout switch for new entry checks. Enable only alongside the deployed
/// access commands and an explicitly approved trusted access policy.
const membershipAccessEnforcementEnabled =
    bool.fromEnvironment('MEMBERSHIP_ACCESS_ENFORCEMENT', defaultValue: false);

MembershipCommerceRepository createMembershipCommerceRepository(
        SessionScope scope, bool Function() isCurrent) =>
    FirebaseMembershipRepository(scope: scope, isCurrent: isCurrent);

/// Route-level injection survives Navigator pushes and guards account changes.
class MembershipFeatureHost extends StatelessWidget {
  const MembershipFeatureHost(
      {super.key, required this.connected, required this.builder});
  final bool connected;
  final Widget Function(MembershipCommerceRepository) builder;
  @override
  Widget build(BuildContext context) {
    if (!connected) {
      return builder(MockMembershipCommerce.forRepository(
          context.read<MembershipRepository>()));
    }
    final session = context.read<AuthBloc>().state.session;
    if (session == null) return const SizedBox.shrink();
    return CoachSessionHost(
        session: session,
        builder: (_, current) => builder(FirebaseMembershipRepository(
            scope: session.scope, isCurrent: current)));
  }
}

/// Every pushed route hides captured financial data immediately on logout.
class MembershipRepositoryGuard extends StatelessWidget {
  const MembershipRepositoryGuard(
      {super.key, required this.repository, required this.child});
  final MembershipCommerceRepository repository;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (!repository.sandbox) return child;
    return BlocBuilder<AuthBloc, AuthState>(
        builder: (_, state) => repository.current
            ? child
            : const Center(
                child: Text('Membership unavailable for this session.')));
  }
}
