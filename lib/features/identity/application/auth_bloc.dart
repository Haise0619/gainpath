import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath/core/domain/app_role.dart';
import 'package:gainpath/features/identity/domain/policies/credentials_policy.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Session state for whichever role is using the app (SD-M1.1, SD-M8.1,
/// SD-M11.1). The prototype has no identity provider: credentials are
/// validated by [CredentialsPolicy] and any well-formed pair signs in after a
/// short simulated round trip. Navigation stays in the screens, which react
/// to [AuthStatus] changes.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    CredentialsPolicy policy = const CredentialsPolicy(),
    this.roundTrip = const Duration(milliseconds: 600),
  })  : _policy = policy,
        super(const AuthState()) {
    on<RoleSelected>((e, emit) => emit(state.copyWith(role: e.role, status: AuthStatus.signedOut, clearErrors: true)));
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoggedOut>((_, emit) => emit(AuthState(role: state.role)));
  }

  static const termsError = 'Agree to the Terms and Privacy Policy to continue.';

  final CredentialsPolicy _policy;
  final Duration roundTrip;

  Future<void> _onLoginSubmitted(LoginSubmitted e, Emitter<AuthState> emit) async {
    final errors = _policy.validate(
      email: e.email,
      password: e.password,
      name: e.name,
      confirm: e.confirm,
      registering: e.registering,
    );
    if (!errors.isValid) {
      emit(state.copyWith(status: AuthStatus.signedOut, fieldErrors: errors, clearMessage: true));
      return;
    }
    if (e.registering && !e.agreedTerms) {
      emit(state.copyWith(status: AuthStatus.signedOut, fieldErrors: CredentialErrors.none, message: termsError));
      return;
    }
    emit(state.copyWith(status: AuthStatus.submitting, fieldErrors: CredentialErrors.none, clearMessage: true));
    await Future<void>.delayed(roundTrip);
    // A brand-new member verifies their email before onboarding (SD-M1.4);
    // every other path lands straight in its shell.
    final next = e.registering && state.role == AppRole.member ? AuthStatus.needsVerification : AuthStatus.signedIn;
    emit(state.copyWith(status: next, email: e.email.trim()));
  }
}
