part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

/// User picked a role on the role-select screen (or the web build fixed it to admin).
class RoleSelected extends AuthEvent {
  const RoleSelected(this.role);
  final AppRole role;
  @override
  List<Object?> get props => [role];
}

/// Sign-in or registration form submitted.
class LoginSubmitted extends AuthEvent {
  const LoginSubmitted({
    required this.email,
    required this.password,
    this.name = '',
    this.confirm = '',
    this.registering = false,
    this.agreedTerms = false,
  });
  final String email;
  final String password;
  final String name;
  final String confirm;
  final bool registering;
  final bool agreedTerms;
  @override
  List<Object?> get props => [email, password, name, confirm, registering, agreedTerms];
}

class LoggedOut extends AuthEvent {
  const LoggedOut();
}
