import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart';

enum AuthStatus {
  checkingSession,
  signedOut,
  submitting,
  needsVerification,
  signedIn
}

class AuthState extends Equatable {
  const AuthState({
    this.role,
    this.status = AuthStatus.signedOut,
    this.email,
    this.session,
    this.fieldErrors = CredentialErrors.none,
    this.message,
  });

  final AppRole? role;
  final AuthStatus status;
  final String? email;
  final AuthSession? session;
  final CredentialErrors fieldErrors;
  final String? message;

  AuthState copyWith({
    AppRole? role,
    AuthStatus? status,
    String? email,
    AuthSession? session,
    CredentialErrors? fieldErrors,
    bool clearErrors = false,
    bool clearSession = false,
    String? message,
    bool clearMessage = false,
  }) {
    return AuthState(
      role: role ?? this.role,
      status: status ?? this.status,
      email: email ?? this.email,
      session: clearSession ? null : (session ?? this.session),
      fieldErrors: clearErrors
          ? CredentialErrors.none
          : (fieldErrors ?? this.fieldErrors),
      message: clearMessage ? null : (message ?? this.message),
    );
  }

  @override
  List<Object?> get props =>
      [role, status, email, session, fieldErrors, message];
}

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class RoleSelected extends AuthEvent {
  const RoleSelected(this.role);

  final AppRole role;

  @override
  List<Object?> get props => [role];
}

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
  List<Object?> get props =>
      [email, password, name, confirm, registering, agreedTerms];
}

class LoggedOut extends AuthEvent {
  const LoggedOut();
}

class AuthRestoreRequested extends AuthEvent {
  const AuthRestoreRequested();
}

class _SessionChanged extends AuthEvent {
  const _SessionChanged(this.session, this.revision);
  final AuthSession? session;
  final int revision;
}

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository repository,
    CredentialsPolicy policy = const CredentialsPolicy(),
    this.roundTrip = Duration.zero,
  })  : _repository = repository,
        _policy = policy,
        super(AuthState(
            status: repository is AuthSessionLifecycle
                ? AuthStatus.checkingSession
                : AuthStatus.signedOut)) {
    on<RoleSelected>((event, emit) {
      _revision++;
      _allowSessionEvents = false;
      emit(state.copyWith(
        role: event.role,
        status: AuthStatus.signedOut,
        clearErrors: true,
        clearMessage: true,
        clearSession: true,
      ));
    });
    on<LoginSubmitted>(_onLoginSubmitted);
    on<LoggedOut>(_onLoggedOut);
    on<AuthRestoreRequested>(_onRestore);
    on<_SessionChanged>((event, emit) {
      if (event.revision != _revision || !_allowSessionEvents) return;
      if (event.session != null && state.status == AuthStatus.submitting) {
        return;
      }
      _revision++;
      _emitSession(event.session, emit);
    });
    if (repository is AuthSessionLifecycle) {
      _subscription =
          (repository as AuthSessionLifecycle).sessionChanges.listen(
        (session) {
          if (!isClosed) add(_SessionChanged(session, _revision));
        },
        onError: (Object error) {
          if (!isClosed) add(_SessionChanged(null, _revision));
        },
      );
      add(const AuthRestoreRequested());
    }
  }

  static const termsError =
      'Agree to the Terms and Privacy Policy to continue.';
  static const unknownError = 'Unable to complete authentication. Try again.';

  final AuthRepository _repository;
  final CredentialsPolicy _policy;
  final Duration roundTrip;
  StreamSubscription<AuthSession?>? _subscription;
  int _revision = 0;
  bool _allowSessionEvents = true;

  void _emitSession(AuthSession? session, Emitter<AuthState> emit) {
    if (session == null) {
      emit(AuthState(role: state.role));
      return;
    }
    try {
      session.scope;
      emit(AuthState(
          role: session.role,
          email: session.email,
          session: session,
          status: session.needsVerification
              ? AuthStatus.needsVerification
              : AuthStatus.signedIn));
    } on ArgumentError {
      emit(AuthState(role: state.role, message: 'Invalid account scope.'));
    }
  }

  Future<void> _onRestore(
      AuthRestoreRequested event, Emitter<AuthState> emit) async {
    final repository = _repository;
    if (repository is! AuthSessionLifecycle) return;
    final revision = ++_revision;
    _allowSessionEvents = true;
    emit(AuthState(role: state.role, status: AuthStatus.checkingSession));
    try {
      final session =
          await (repository as AuthSessionLifecycle).restoreSession();
      if (revision == _revision && !emit.isDone) _emitSession(session, emit);
    } catch (_) {
      if (revision == _revision && !emit.isDone) {
        emit(AuthState(role: state.role, message: unknownError));
      }
    }
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    final revision = ++_revision;
    _allowSessionEvents = true;
    final errors = _policy.validate(
      email: event.email,
      password: event.password,
      name: event.name,
      confirm: event.confirm,
      registering: event.registering,
    );
    if (!errors.isValid) {
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        fieldErrors: errors,
        clearMessage: true,
      ));
      return;
    }
    if (event.registering && !event.agreedTerms) {
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        fieldErrors: CredentialErrors.none,
        message: termsError,
      ));
      return;
    }
    final role = state.role;
    if (role == null) {
      emit(state.copyWith(
          status: AuthStatus.signedOut, message: 'Select a role to continue.'));
      return;
    }

    emit(state.copyWith(
      status: AuthStatus.submitting,
      fieldErrors: CredentialErrors.none,
      clearMessage: true,
    ));
    try {
      final session = event.registering
          ? await _repository.register(
              role: role,
              email: event.email,
              password: event.password,
              name: event.name,
            )
          : await _repository.signIn(
              role: role,
              email: event.email,
              password: event.password,
            );
      if (roundTrip > Duration.zero) await Future<void>.delayed(roundTrip);
      if (revision != _revision || emit.isDone) return;
      session.scope;
      emit(state.copyWith(
        role: session.role,
        status: session.needsVerification
            ? AuthStatus.needsVerification
            : AuthStatus.signedIn,
        email: session.email,
        session: session,
      ));
    } on AuthException catch (error) {
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        message: error.message,
        clearSession: true,
      ));
    } catch (_) {
      if (revision != _revision || emit.isDone) return;
      emit(state.copyWith(
        status: AuthStatus.signedOut,
        message: unknownError,
        clearSession: true,
      ));
    }
  }

  Future<void> _onLoggedOut(LoggedOut event, Emitter<AuthState> emit) async {
    final revision = ++_revision;
    _allowSessionEvents = false;
    emit(AuthState(role: state.role));
    try {
      await _repository.signOut();
    } catch (_) {
      if (revision == _revision && !emit.isDone) {
        emit(AuthState(
            role: state.role,
            message: 'Unable to sign out of the provider. Try again.'));
      }
    }
  }

  @override
  Future<void> close() async {
    _revision++;
    await _subscription?.cancel();
    return super.close();
  }
}

class AuthRolePolicy {
  const AuthRolePolicy._();

  static bool canEnter(AuthState state, {required Set<AppRole> allowed}) {
    final session = state.session;
    if (state.status != AuthStatus.signedIn ||
        session == null ||
        session.needsVerification ||
        state.role != session.role) {
      return false;
    }
    try {
      session.scope;
      return allowed.contains(session.role);
    } on ArgumentError {
      return false;
    }
  }
}
