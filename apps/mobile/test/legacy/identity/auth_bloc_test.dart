import 'package:bloc_test/bloc_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';

AuthBloc _bloc() => AuthBloc(repository: InMemoryAuthRepository());

void main() {
  blocTest<AuthBloc, AuthState>(
    'valid sign-in lands signed in with the selected role',
    build: _bloc,
    act: (b) => b
      ..add(const RoleSelected(AppRole.coach))
      ..add(const LoginSubmitted(email: 'jason@furyfitness.my', password: 'demo1234')),
    wait: const Duration(milliseconds: 20),
    verify: (b) {
      expect(b.state.status, AuthStatus.signedIn);
      expect(b.state.role, AppRole.coach);
      expect(b.state.email, 'jason@furyfitness.my');
    },
  );

  blocTest<AuthBloc, AuthState>(
    'empty password is rejected with a field error and no transition',
    build: _bloc,
    act: (b) => b.add(const LoginSubmitted(email: 'a@b.co', password: '')),
    verify: (b) {
      expect(b.state.status, AuthStatus.signedOut);
      expect(b.state.fieldErrors.password, 'Enter your password.');
    },
  );

  blocTest<AuthBloc, AuthState>(
    'registration without agreeing to terms is blocked with a message',
    build: _bloc,
    act: (b) => b.add(const LoginSubmitted(
        email: 'a@b.co', password: 'demo1234', confirm: 'demo1234', name: 'Zhen', registering: true)),
    verify: (b) {
      expect(b.state.status, AuthStatus.signedOut);
      expect(b.state.message, AuthBloc.termsError);
    },
  );

  blocTest<AuthBloc, AuthState>(
    'a new member registration goes to email verification',
    build: _bloc,
    act: (b) => b
      ..add(const RoleSelected(AppRole.member))
      ..add(const LoginSubmitted(
          email: 'a@b.co', password: 'demo1234', confirm: 'demo1234', name: 'Zhen', registering: true, agreedTerms: true)),
    wait: const Duration(milliseconds: 20),
    verify: (b) => expect(b.state.status, AuthStatus.needsVerification),
  );

  blocTest<AuthBloc, AuthState>(
    'logging out returns to signed out but remembers the role',
    build: _bloc,
    act: (b) => b
      ..add(const RoleSelected(AppRole.admin))
      ..add(const LoginSubmitted(email: 'admin@gainpath.com', password: 'demo1234'))
      ..add(const LoggedOut()),
    verify: (b) {
      expect(b.state.status, AuthStatus.signedOut);
      expect(b.state.role, AppRole.admin);
      expect(b.state.email, isNull);
    },
  );
}
