import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/content.dart';
import '../infrastructure/firebase/firebase_announcement_reader.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'app.dart';
import 'routing/app_routes.dart';
import 'routing/feature_routes.dart';
import '../features/analytics/domain/local_member_progress_repository.dart';
import 'shells/member_shell.dart';
import 'shells/coach_shell.dart';
import 'di/published_routine_catalog_factory.dart';
import 'di/equipment_catalog_factory.dart';
import 'di/coach_profile_factory.dart';
import 'di/booking_factory.dart';
import '../features/identity/presentation/shared/login_screen.dart';
import '../features/identity/presentation/shared/email_verification_screen.dart';
import '../features/identity/presentation/member/profile_setup_screen.dart';
import '../infrastructure/firebase/firebase_auth_gateway.dart';
import '../infrastructure/firebase/firebase_fitness_profile_gateway.dart';
import '../infrastructure/firebase/firebase_member_preferences_repository.dart';
import '../infrastructure/firebase/firebase_password_actions.dart';
import '../infrastructure/firebase/firebase_published_routine_repository.dart';
import '../features/workout/data/published_routine.dart';
import '../features/identity/presentation/member/fitness_profile_gate.dart';
import '../features/identity/presentation/member/account_settings_screen.dart';

class GainPathMobileApp extends StatelessWidget {
  const GainPathMobileApp(
      {super.key,
      this.authRepository,
      this.backendConfig,
      this.profileRepositoryFactory,
      this.routineLoaderFactory,
      this.routineCatalogFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachProfileFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.passwordResetSender,
      this.memberSettingsBuilder});

  final AuthRepository? authRepository;
  final BackendConfig? backendConfig;
  final FitnessProfileRepository Function(SessionScope)?
      profileRepositoryFactory;
  final Future<PublishedRoutine?> Function(SessionScope)? routineLoaderFactory;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachProfileFactory? coachProfileFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final Future<void> Function(String)? passwordResetSender;
  final WidgetBuilder? memberSettingsBuilder;

  @override
  Widget build(BuildContext context) {
    final config = backendConfig ?? BackendConfig.fromEnvironment();
    config.validate();
    return RepositoryProvider<AuthRepository>(
      create: (_) =>
          authRepository ??
          AuthRepositoryFactory.create(
            config: config,
            firebaseGateway:
                config.isFirebase ? FlutterFirebaseAuthGateway() : null,
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
          buildWhen: (previous, current) => previous.session != current.session,
          builder: (context, state) {
            final app = MaterialApp(
              // Close the entry routes when identity changes in either backend.
              key: ValueKey((state.session?.scope, state.session?.role)),
              title: 'GainPath',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              home: _MobileAuthGate(
                  config: config,
                  profileRepositoryFactory: profileRepositoryFactory,
                  routineLoaderFactory: routineLoaderFactory,
                  routineCatalogFactory: routineCatalogFactory,
                  announcementReaderFactory: announcementReaderFactory,
                  equipmentReaderFactory: equipmentReaderFactory,
                  coachProfileFactory: coachProfileFactory,
                  coachDirectoryFactory: coachDirectoryFactory,
                  coachAvailabilityFactory: coachAvailabilityFactory,
                  bookingFactory: bookingFactory,
                  bookingListFactory: bookingListFactory,
                  progressRepositoryFactory: progressRepositoryFactory,
                  passwordResetSender: passwordResetSender,
                  memberSettingsBuilder: memberSettingsBuilder),
              routes: AppRouteBuilders.withLogin((_) => LoginScreen(
                  prefillDemoPassword: !config.isFirebase,
                  onPasswordReset: config.isFirebase
                      ? passwordResetSender ??
                          (email) => FirebasePasswordResetActions().send(email)
                      : null)),
              onGenerateRoute: (settings) => buildFeatureRoute(settings,
                  firebase: config.isFirebase,
                  progressRepositoryFactory: progressRepositoryFactory),
            );
            if (config.isFirebase) return app;
            return AppScope(
              key: ValueKey((state.session?.scope, state.session?.role)),
              config: config,
              child: app,
            );
          },
        ),
      ),
    );
  }
}

class _MobileAuthGate extends StatefulWidget {
  const _MobileAuthGate(
      {required this.config,
      this.profileRepositoryFactory,
      this.routineLoaderFactory,
      this.routineCatalogFactory,
      this.announcementReaderFactory,
      this.equipmentReaderFactory,
      this.coachProfileFactory,
      this.coachDirectoryFactory,
      this.coachAvailabilityFactory,
      this.bookingFactory,
      this.bookingListFactory,
      this.progressRepositoryFactory,
      this.passwordResetSender,
      this.memberSettingsBuilder});
  final BackendConfig config;
  final FitnessProfileRepository Function(SessionScope)?
      profileRepositoryFactory;
  final Future<PublishedRoutine?> Function(SessionScope)? routineLoaderFactory;
  final PublishedRoutineCatalogFactory? routineCatalogFactory;
  final AnnouncementReader Function(SessionScope, SessionScope? Function())?
      announcementReaderFactory;
  final EquipmentReaderFactory? equipmentReaderFactory;
  final CoachProfileFactory? coachProfileFactory;
  final CoachDirectoryFactory? coachDirectoryFactory;
  final CoachAvailabilityFactory? coachAvailabilityFactory;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final LocalMemberProgressRepositoryFactory? progressRepositoryFactory;
  final Future<void> Function(String)? passwordResetSender;
  final WidgetBuilder? memberSettingsBuilder;
  @override
  State<_MobileAuthGate> createState() => _MobileAuthGateState();
}

class _MobileAuthGateState extends State<_MobileAuthGate> {
  bool _setupProfile = false;
  FitnessProfileRepository? _profileRepository;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.checkingSession) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (AuthRolePolicy.canEnter(
          state,
          allowed: const {AppRole.member, AppRole.coach},
        )) {
          if (widget.config.isFirebase) {
            if (state.session!.role == AppRole.member) {
              final scope = state.session!.scope;
              final auth = context.read<AuthBloc>();
              bool isCurrentMember() =>
                  mounted &&
                  auth.state.session?.scope == scope &&
                  AuthRolePolicy.canEnter(auth.state,
                      allowed: const {AppRole.member});
              if (_profileRepository?.scope != scope) {
                _profileRepository =
                    widget.profileRepositoryFactory?.call(scope) ??
                        FirebaseFitnessProfileRepository(
                            scope: scope,
                            gateway: FlutterFitnessProfileGateway(
                                isSessionCurrent: isCurrentMember));
              }
              return FitnessProfileGate(
                  key: ValueKey(scope),
                  session: state.session!,
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
                        coachAvailabilityFactory:
                            widget.coachAvailabilityFactory,
                        progressRepositoryFactory:
                            widget.progressRepositoryFactory,
                        routineCatalogFactory: widget.routineCatalogFactory ??
                            (catalogScope, activeScope) =>
                                widget.routineLoaderFactory == null
                                    ? FirebasePublishedRoutineRepository(
                                        scope: catalogScope,
                                        activeScope: activeScope)
                                    : SinglePublishedRoutineCatalog(
                                        scope: catalogScope,
                                        loader: () =>
                                            widget.routineLoaderFactory!(
                                                catalogScope)),
                        memberSettingsBuilder: widget.memberSettingsBuilder ??
                            (_) {
                              final actions =
                                  FirebasePasswordActions(scope: scope);
                              return AccountSettingsScreen(
                                repository: FirebaseMemberPreferencesRepository(
                                    scope: scope,
                                    isSessionCurrent: isCurrentMember),
                                verifyCurrentPassword: actions.verifyCurrent,
                                saveNewPassword: actions.saveNew,
                              );
                            },
                      ));
            }
            return buildFirebaseCoachShell(state.session!,
                factory: widget.coachProfileFactory,
                bookingListFactory: widget.bookingListFactory,
                availabilityFactory: widget.coachAvailabilityFactory);
          }
          if (_setupProfile) return const ProfileSetupScreen();
          return state.session!.role == AppRole.coach
              ? const CoachShell()
              : const MemberShell();
        }
        if (state.status == AuthStatus.needsVerification) {
          final repository = context.read<AuthRepository>();
          return EmailVerificationScreen(
            email: state.session!.email,
            onVerified: repository is InMemoryAuthRepository
                ? () async {
                    setState(() => _setupProfile = true);
                    await repository.verifyEmailForDemo();
                  }
                : repository is AuthSessionLifecycle
                    ? () async => context
                        .read<AuthBloc>()
                        .add(const AuthRestoreRequested())
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
            prefillDemoPassword: !widget.config.isFirebase,
            onPasswordReset: widget.config.isFirebase
                ? widget.passwordResetSender ??
                    (email) => FirebasePasswordResetActions().send(email)
                : null);
      },
    );
  }
}
