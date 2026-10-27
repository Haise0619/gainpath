// ignore_for_file: subtype_of_sealed_class
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_admin_member_directory_repository.dart';

class _Db extends Fake implements FirebaseFirestore {}

class _User extends Fake implements User {
  @override
  String get uid => 'admin';
  @override
  bool get emailVerified => true;
}

class _Auth extends Fake implements FirebaseAuth {
  @override
  User get currentUser => _User();
}

void main() {
  test(
      'scoped QR and manual references inspect; foreign QR rejected before transport',
      () async {
    final calls = <Map<String, dynamic>>[];
    final repo = FirebaseAdminMemberDirectoryRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        isCurrent: () => true,
        auth: _Auth(),
        firestore: _Db(),
        membershipCall: (name, input) async {
          expect(name, 'verifiedRewardsCommand');
          calls.add(input);
          return {
            'schemaVersion': 1,
            'redemption': {
              'schemaVersion': 1,
              'organizationId': 'o',
              'memberId': 'member',
              'redemptionId': input['redemptionId'],
              'itemId': 'item',
              'title': 'Real reward',
              'points': 50,
              'status': 'issued',
              'issuedAtMillis': 1800000000000,
              'policyVersion': 'p1',
              'exchangeRateVersion': 'r1'
            }
          };
        });
    await repo.inspect('gainpath-reward:v1:o:voucher');
    expect(calls.single, {
      'schemaVersion': 1,
      'organizationId': 'o',
      'action': 'inspect',
      'redemptionId': 'voucher'
    });
    await repo.inspect('voucher');
    expect(calls.length, 2);
    await expectLater(repo.inspect('gainpath-reward:v1:foreign:voucher'),
        throwsFormatException);
    await expectLater(
        repo.inspect('https://example.test'), throwsFormatException);
    expect(calls.length, 2);
  });
}
