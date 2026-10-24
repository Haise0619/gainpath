import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/membership.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/member_membership_verification_panel.dart';

class _Verification implements MembershipVerificationRepository {
  bool fail = false;
  @override
  Future<MemberMembershipVerification> verifyMembership(String memberId) async {
    if (fail) throw StateError('private auth failure');
    return MemberMembershipVerification.fromJson({
      'schemaVersion': 1,
      'organizationId': 'o',
      'memberId': memberId,
      'verifiedAtMillis': 1800000000000,
      'status': 'denied',
      'gymAdmission': false,
      'identity': null,
      'entitlement': null
    }, organizationId: 'o', memberId: memberId);
  }
}

void main() {
  testWidgets(
      'requires a fresh server check and never presents denied target as Free',
      (tester) async {
    final repo = _Verification();
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MemberMembershipVerificationPanel(
                memberId: 'm', repository: repo))));
    expect(find.text('Verify current membership'), findsOneWidget);
    expect(find.text('Free'), findsNothing);
    await tester.tap(find.text('Verify current membership'));
    await tester.pumpAndSettle();
    expect(find.text('Membership verification denied'), findsOneWidget);
    expect(find.text('General gym admission: Not included'), findsOneWidget);
    repo.fail = true;
    await tester.tap(find.text('Verify current membership'));
    await tester.pumpAndSettle();
    expect(find.text('Membership verification denied'), findsNothing);
    expect(find.textContaining('private auth failure'), findsNothing);
    expect(
        find.text(
            'Current membership could not be verified. Retry when connected.'),
        findsOneWidget);
  });
}
