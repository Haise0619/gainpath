import 'routing/member_progress_route.dart' show ProgressGoalSummaryBuilder;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/identity.dart'
    show MemberAccountLifecycleRepository;
import '../infrastructure/firebase/firebase_announcement_reader.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'routing/app_routes.dart';
import 'routing/feature_routes.dart';
import '../features/analytics/domain/local_member_progress_repository.dart';
import 'shells/member_shell.dart';
import 'di/published_routine_catalog_factory.dart';
import 'di/equipment_catalog_factory.dart';
import 'di/coach_profile_factory.dart';
import 'di/booking_factory.dart';
import '../features/identity/presentation/shared/login_screen.dart';
import '../features/identity/presentation/shared/email_verification_screen.dart';
import '../infrastructure/firebase/firebase_auth_gateway.dart';
import '../infrastructure/firebase/firebase_fitness_profile_gateway.dart';
import '../infrastructure/firebase/firebase_member_preferences_repository.dart';
import '../infrastructure/firebase/firebase_password_actions.dart';
import '../infrastructure/firebase/firebase_member_account_lifecycle_repository.dart';
import '../features/identity/presentation/member/member_account_recovery_screen.dart';
import '../infrastructure/firebase/firebase_published_routine_repository.dart';
import '../features/workout/data/published_routine.dart';
import '../features/identity/presentation/member/fitness_profile_gate.dart';
import '../features/identity/presentation/member/account_settings_screen.dart';

class GainPathMobileApp extends StatelessWidget {
  /// Normal execution always uses the connected Firebase repositories.
  const GainPathMobileApp({Key? key}) : this.injected(key: key);

  /// Explicit test/development composition may deliberately supply fakes.
  const GainPathMobileApp.injected(
      {super.key,
      this.authRepository,
      this.profileRepositoryFactory,
      this.routineLoaderFactory,
      this.routineCatalogFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachProfileFactory,
      this.coachAccountFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.progressGoalSummaryBuilder,
      this.memberRewardsBuilder,
      this.passwordResetSender,
      this.accountLifecycleFactory,
      this.memberSettingsBuilder});

  final AuthRepository? authRepository;
  final FitnessProfileRepository Function(SessionScope)?
      profileRepositoryFactory;
  final Future<PublishedRoutine?> Function(SessionScope)? routineLoaderFactory;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachProfileFactory? coachProfileFactory;
  final CoachAccountFactory? coachAccountFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final ProgressGoalSummaryBuilder? progressGoalSummaryBuilder;
  final Future<void> Function(String)? passwordResetSender;
  final MemberAccountLifecycleRepository Function(AuthSession, bool Function())?
      accountLifecycleFactory;
  final WidgetBuilder? memberSettingsBuilder;
  final WidgetBuilder? memberRewardsBuilder;

  @override
  Widget build(BuildContext context) {
    return RepositoryProvider<AuthRepository>(
      create: (_) =>
          authRepository ??
          AuthRepositoryFactory.create(
            firebaseGateway: FlutterFirebaseAuthGateway(),
          ),
      dispose: (repository) {
        if (authRepository == null && repository is AuthSessionLifecycle) {
          unawaited((repository as AuthSessionLifecycle).dispose());
        }
      },
      child: BlocProvider(
        create: (context) =>
            AuthBloc(repository: context.read<AuthRepository>()),
        child: BlocBuilder<AuthBloc, AuthState>(
          buildWhen: (previous, current) =>
              !identical(previous.session, current.session),
          builder: (context, state) {
            final home = _MobileAuthGate(
                profileRepositoryFactory: profileRepositoryFactory,
                routineLoaderFactory: routineLoaderFactory,
                routineCatalogFactory: routineCatalogFactory,
                announcementReaderFactory: announcementReaderFactory,
                equipmentReaderFactory: equipmentReaderFactory,
                coachProfileFactory: coachProfileFactory,
                coachAccountFactory: coachAccountFactory,
                coachDirectoryFactory: coachDirectoryFactory,
                coachAvailabilityFactory: coachAvailabilityFactory,
                bookingFactory: bookingFactory,
                bookingListFactory: bookingListFactory,
                progressRepositoryFactory: progressRepositoryFactory,
                progressGoalSummaryBuilder: progressGoalSummaryBuilder,
                memberRewardsBuilder: memberRewardsBuilder,
                passwordResetSender: passwordResetSender,
                accountLifecycleFactory: accountLifecycleFactory,
                memberSettingsBuilder: memberSettingsBuilder);
            final app = MaterialApp(
              // Close captured routes whenever the authenticated identity changes.
              key: ObjectKey(state.session),
              title: 'GainPath',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              home: home,
              routes: AppRouteBuilders.withLogin(
                  (_) => LoginScreen(
                      onPasswordReset: passwordResetSender ??
                          (email) =>
                              FirebasePasswordResetActions().send(email)),
                  memberBuilder: (_) => home,
                  coachBuilder: (_) => BlocBuilder<AuthBloc, AuthState>(
                          builder: (context, state) {
                        final session = state.session;
                        if (session == null ||
                            !AuthRolePolicy.canEnter(state,
                                allowed: {AppRole.coach})) {
                          return const LoginScreen();
                        }
                        return buildFirebaseCoachShell(session,
                            factory: coachProfileFactory,
                            accountFactory: coachAccountFactory,
                            availabilityFactory: coachAvailabilityFactory,
                            bookingListFactory: bookingListFactory);
                      })),
              onGenerateRoute: (settings) => buildFeatureRoute(settings,
                  firebase: true,
                  progressRepositoryFactory: progressRepositoryFactory),
            );
            return app;
          },
        ),
      ),
    );
  }
}

class _MobileAuthGate extends StatefulWidget {
  const _MobileAuthGate(
      {this.profileRepositoryFactory,
      this.routineLoaderFactory,
      this.routineCatalogFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachProfileFactory,
      this.coachAccountFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.progressGoalSummaryBuilder,
      this.memberRewardsBuilder,
      this.passwordResetSender,
      this.accountLifecycleFactory,
      this.memberSettingsBuilder});
  final FitnessProfileRepository Function(SessionScope)?
      profileRepositoryFactory;
  final Future<PublishedRoutine?> Function(SessionScope)? routineLoaderFactory;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachProfileFactory? coachProfileFactory;
  final CoachAccountFactory? coachAccountFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final ProgressGoalSummaryBuilder? progressGoalSummaryBuilder;
  final Future<void> Function(String)? passwordResetSender;
  final MemberAccountLifecycleRepository Function(AuthSession, bool Function())?
      accountLifecycleFactory;
  final WidgetBuilder? memberSettingsBuilder;
  final WidgetBuilder? memberRewardsBuilder;
  @override
  State<_MobileAuthGate> createState() => _MobileAuthGateState();
}

class _MobileAuthGateState extends State<_MobileAuthGate> {
  FitnessProfileRepository? _profileRepository;
  AuthSession? _profileSession;
  AuthSession? _recoverySession;
  MemberAccountLifecycleRepository? _recoveryRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.checkingSession) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (state.status == AuthStatus.pendingDeletion &&
            state.session?.role == AppRole.member) {
          final captured = state.session!;
          final auth = context.read<AuthBloc>();
          var invalidated = false;
          bool isCurrent() {
            if (invalidated) return false;
            final valid = mounted &&
                identical(auth.state.session, captured) &&
                auth.state.status == AuthStatus.pendingDeletion;
            if (!valid) invalidated = true;
            return valid;
          }

          if (!identical(_recoverySession, captured)) {
            _recoverySession = captured;
            _recoveryRepository =
                widget.accountLifecycleFactory?.call(captured, isCurrent) ??
                    FirebaseMemberAccountLifecycleRepository(
                        scope: captured.scope, isCurrent: isCurrent);
          }
          return MemberAccountRecoveryScreen(
            repository: _recoveryRepository!,
            onSignedOut: () => auth.add(const LoggedOut()),
            onRestored: () => auth.add(const AuthRestoreRequested()),
          );
        }
        if (AuthRolePolicy.canEnter(
          state,
          allowed: const {AppRole.member, AppRole.coach},
        )) {
          if (state.session!.role == AppRole.member) {
            final capturedSession = state.session!;
            final scope = capturedSession.scope;
            final auth = context.read<AuthBloc>();
            var sessionInvalidated = false;
            bool isCurrentMember() {
              if (sessionInvalidated) return false;
              final current = mounted &&
                  identical(auth.state.session, capturedSession) &&
                  AuthRolePolicy.canEnter(auth.state,
                      allowed: const {AppRole.member});
              if (!current) sessionInvalidated = true;
              return current;
            }

            if (!identical(_profileSession, capturedSession)) {
              _profileSession = capturedSession;
              _profileRepository =
                  widget.profileRepositoryFactory?.call(scope) ??
                      FirebaseFitnessProfileRepository(
                          scope: scope,
                          gateway: FlutterFitnessProfileGateway(
                              isSessionCurrent: isCurrentMember));
            }
            return FitnessProfileGate(
                key: ObjectKey(_profileRepository),
                session: capturedSession,
                repository: _profileRepository!,
                readyBuilder: (context, profile) => MemberShell(
                      liveSession: state.session!,
                      liveProfile: profile,
                      equipmentReaderFactory: widget.equipmentReaderFactory,
                      announcementReaderFactory:
                          widget.announcementReaderFactory ??
                              (scope, active) => FirebaseAnnouncementReader(
                                  scope: scope, activeScope: active),
                      coachDirectoryFactory: widget.coachDirectoryFactory,
                      bookingFactory: widget.bookingFactory,
                      bookingListFactory: widget.bookingListFactory,
                      coachAvailabilityFactory: widget.coachAvailabilityFactory,
                      progressGoalSummaryBuilder:
                          widget.progressGoalSummaryBuilder,
                      progressRepositoryFactory:
                          widget.progressRepositoryFactory,
                      memberRewardsBuilder: widget.memberRewardsBuilder,
                      routineCatalogFactory: widget.routineCatalogFactory ??
                          (catalogScope, activeScope) =>
                              widget.routineLoaderFactory == null
                                  ? FirebasePublishedRoutineRepository(
                                      scope: catalogScope,
                                      activeScope: activeScope)
                                  : SinglePublishedRoutineCatalog(
                                      scope: catalogScope,
                                      loader: () => widget
                                          .routineLoaderFactory!(catalogScope)),
                      memberSettingsBuilder: widget.memberSettingsBuilder ??
                          (_) {
                            final actions =
                                FirebasePasswordActions(scope: scope);
                            return AccountSettingsScreen(
                              contactSession: state.session!,
                              repository: FirebaseMemberPreferencesRepository(
                                  scope: scope,
                                  isSessionCurrent: isCurrentMember),
                              verifyCurrentPassword: actions.verifyCurrent,
                              saveNewPassword: actions.saveNew,
                              lifecycleRepository:
                                  widget.accountLifecycleFactory?.call(
                                          capturedSession, isCurrentMember) ??
                                      FirebaseMemberAccountLifecycleRepository(
                                          scope: scope,
                                          isCurrent: isCurrentMember),
                              onAccountDeactivated: () =>
                                  auth.add(const LoggedOut()),
                            );
                          },
                    ));
          }
          return buildFirebaseCoachShell(state.session!,
              factory: widget.coachProfileFactory,
              accountFactory: widget.coachAccountFactory,
              bookingListFactory: widget.bookingListFactory,
              availabilityFactory: widget.coachAvailabilityFactory);
        }
        if (state.status == AuthStatus.needsVerification) {
          final repository = context.read<AuthRepository>();
          return EmailVerificationScreen(
            email: state.session!.email,
            onVerified: repository is AuthSessionLifecycle
                ? () async {
                    final session = await (repository as AuthSessionLifecycle)
                        .restoreSession();
                    if (session == null || session.needsVerification) {
                      throw const AuthException(
                          'Your email is not verified yet. Open the latest verification link, then try again.');
                    }
                  }
                : null,
            onResend: repository is AuthVerificationActions
                ? (repository as AuthVerificationActions)
                    .resendEmailVerification
                : null,
            onSignOut: () => context.read<AuthBloc>().add(const LoggedOut()),
          );
        }
        if (state.session?.role == AppRole.admin) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Use the admin web console for this account.'),
                  TextButton(
                    onPressed: () =>
                        context.read<AuthBloc>().add(const LoggedOut()),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }
        return LoginScreen(
            onPasswordReset: widget.passwordResetSender ??
                (email) => FirebasePasswordResetActions().send(email));
      },
    );
  }
}
