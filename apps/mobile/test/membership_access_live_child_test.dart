import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/navigation/membership_access_gate.dart';
import 'coach_directory_flow_test.dart' show DriftingCoachAuth;

class _AllowedBasic implements MembershipAccessRepository {
  _AllowedBasic(this.scope, this.active);
  final SessionScope scope;
  final bool Function() active;
  int reads = 0;
  @override
  bool get current => active();
  @override
  Future<MembershipAccessDecision> check(
      MembershipAccessFeature feature, String resourceId) async {
    reads++;
    return MembershipAccessDecision.fromJson({
      'schemaVersion': 1,
      'policyVersion': 'gainpath-membership-access-v1',
      'organizationId': scope.organizationId,
      'memberId': scope.userId,
      'resolvedAtMillis': 1800000000000,
      'feature': feature.name,
      'resourceId': resourceId,
      'effectiveTier': 'basic',
      'requiredTier': 'basic',
      'decision': 'allowed',
      'reason': 'tier_access',
    },
        organizationId: scope.organizationId,
        memberId: scope.userId,
        feature: feature,
        resourceId: resourceId);
  }
}

void main() {
  testWidgets(
      'signed-in Basic gate updates loading, results, empty and error content',
      (t) async {
    const session = AuthSession(
        userId: 'member',
        organizationId: 'gainpath',
        branchIds: ['main'],
        email: 'member@example.invalid',
        role: AppRole.member);
    final auth = DriftingCoachAuth(session);
    final bloc = AuthBloc(repository: auth);
    addTearDown(bloc.close);
    addTearDown(auth.dispose);
    await t.pump();
    expect(bloc.state.status, AuthStatus.signedIn);
    late StateSetter rebuild;
    var content = 'Finding your coaches…';
    _AllowedBasic? access;
    await t.pumpWidget(BlocProvider.value(
        value: bloc,
        child: MaterialApp(home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return MembershipAccessGate(
                enabled: true,
                repositoryFactory: (scope, current) =>
                    access ??= _AllowedBasic(scope, current),
                feature: MembershipAccessFeature.coach,
                resourceId: 'coach-directory',
                child: Text(content));
          },
        ))));
    await t.pumpAndSettle();
    expect(find.text('Finding your coaches…'), findsOneWidget);
    for (final next in [
      'Loaded coach cards',
      'No coaches match',
      'Could not load coaches'
    ]) {
      rebuild(() => content = next);
      await t.pumpAndSettle();
      expect(find.text(next), findsOneWidget);
      expect(find.text('Finding your coaches…'), findsNothing);
    }
    expect(access!.reads, 1);
    await auth.signOut();
    await t.pumpAndSettle();
    expect(find.text('Could not load coaches'), findsNothing);
    expect(access!.current, isFalse);
  });
}
