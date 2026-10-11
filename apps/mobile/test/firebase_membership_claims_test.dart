import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_auth_gateway.dart';

void main() {
  test('Firebase auth errors identify recoverable account problems', () {
    expect(firebaseAuthFailureMessage('invalid-credential'),
        'Email or password is incorrect.');
    expect(firebaseAuthFailureMessage('email-already-in-use'),
        'This email is already registered.');
    expect(firebaseAuthFailureMessage('network-request-failed'),
        contains('internet connection'));
  });

  test('membershipClaims combines authoritative user and membership scope', () {
    expect(
      membershipClaims(
        userData: const {
          'organizationId': 'gainpath',
          'primaryBranchId': 'main',
        },
        memberData: const {
          'organizationId': 'gainpath',
          'role': 'member',
          'status': 'active',
          'branchIds': ['main'],
        },
      ),
      {
        'organizationId': 'gainpath',
        'role': 'member',
        'status': 'active',
        'branchIds': ['main'],
      },
    );
  });

  test('membershipClaims rejects cross-organization and inactive records', () {
    expect(
      () => membershipClaims(
        userData: const {'organizationId': 'gainpath'},
        memberData: const {
          'organizationId': 'other',
          'role': 'member',
          'status': 'active',
          'branchIds': ['main'],
        },
      ),
      throwsStateError,
    );
    expect(
      () => membershipClaims(
        userData: const {'organizationId': 'gainpath'},
        memberData: const {
          'organizationId': 'gainpath',
          'role': 'member',
          'status': 'suspended',
          'branchIds': ['main'],
        },
      ),
      throwsStateError,
    );
  });
}
