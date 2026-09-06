part of 'auth_bloc.dart';

enum AuthStatus { signedOut, submitting, needsVerification, signedIn }

class AuthState extends Equatable {
  const AuthState({
    this.role,
    this.status = AuthStatus.signedOut,
    this.email,
    this.fieldErrors = CredentialErrors.none,
    this.message,
  });

  final AppRole? role;
  final AuthStatus status;
  final String? email;

  /// Per-field validation errors from the last submission.
  final CredentialErrors fieldErrors;

  /// A form-level message (for example the terms reminder).
  final String? message;

  AuthState copyWith({
    AppRole? role,
    AuthStatus? status,
    String? email,
    CredentialErrors? fieldErrors,
    bool clearErrors = false,
    String? message,
    bool clearMessage = false,
  }) =>
      AuthState(
        role: role ?? this.role,
        status: status ?? this.status,
        email: email ?? this.email,
        fieldErrors: clearErrors ? CredentialErrors.none : (fieldErrors ?? this.fieldErrors),
        message: clearMessage ? null : (message ?? this.message),
      );

  @override
  List<Object?> get props => [role, status, email, fieldErrors, message];
}
