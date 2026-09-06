import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath/features/identity/domain/policies/credentials_policy.dart';

void main() {
  const policy = CredentialsPolicy();

  test('valid sign-in credentials produce no errors', () {
    expect(policy.validate(email: 'a@b.co', password: 'demo1234').isValid, isTrue);
  });

  test('empty fields are reported', () {
    final e = policy.validate(email: '', password: '');
    expect(e.email, 'Enter your email address.');
    expect(e.password, 'Enter your password.');
  });

  test('malformed email is rejected', () {
    expect(policy.validate(email: 'not-an-email', password: 'x').email, 'Enter a valid email address.');
  });

  test('registration needs a name, an 8-char password and a matching confirmation', () {
    final e = policy.validate(email: 'a@b.co', password: 'short', confirm: 'other', registering: true);
    expect(e.name, 'Enter your full name.');
    expect(e.password, 'Use at least 8 characters.');
    expect(e.confirm, 'Passwords do not match.');
  });
}
