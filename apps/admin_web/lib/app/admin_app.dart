import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'di/app_repositories.dart';
import 'shells/admin_shell.dart';
import '../infrastructure/firebase/firebase_auth_gateway.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_domain/content.dart' show FacilitySettingsRepository;
import 'package:gainpath_domain/gamification.dart'
    show RewardCatalogRepository, MiniGameContentRepository;
import 'package:gainpath_domain/identity.dart' show CoachProfileAdminRepository;
import 'package:gainpath_domain/identity.dart'
    show AdminAccountContactRepository, AdminMemberDirectoryRepository;
import 'package:gainpath_domain/coaching.dart' show CoachAvailabilityRepository;

import 'di/admin_presentation_dependencies.dart';
import '../features/identity/presentation/admin/admin_login_page.dart';

/// Explicit controlled-demo hosts reuse these existing identity screens without
/// constructing unrelated production repositories or changing normal startup.
Widget buildControlledDemoAdminLogin() => const _AdminLoginScreen();
Widget buildControlledDemoAdminVerification(AuthSession session) =>
    _AdminVerificationScreen(session: session);

class GainPathAdminWebApp extends StatelessWidget {
  /// Normal composition always uses Firebase and no repository overrides.
  const GainPathAdminWebApp({Key? key}) : this.injected(key: key);

  /// Explicit test/development composition may deliberately supply fakes.
  const GainPathAdminWebApp.injected(
      {super.key,
      this.authRepository,
      this.datasetTransportFactory,
      this.tutorialRepositoryFactory,
      this.routineRepositoryFactory,
      this.coachRepositoryFactory,
      this.coachAvailabilityFactory,
      this.bookingListFactory,
      this.accountContactFactory,
      this.memberDirectoryFactory,
      this.rewardCatalogFactory,
      this.miniGameContentFactory,
      this.facilitySettingsFactory,
      this.reportingGatewayFactory,
      this.passwordResetSender});

  final AuthRepository? authRepository;
  final FypDatasetTransportFactory? datasetTransportFactory;
  final Future<void> Function(String)? passwordResetSender;
  final ReportingGatewayFactory? reportingGatewayFactory;
  final TutorialRepository Function(SessionScope)? tutorialRepositoryFactory;
  final RoutineTemplateRepository Function(SessionScope, TutorialRepository)?
      routineRepositoryFactory;
  final CoachProfileAdminRepository Function(SessionScope, bool Function())?
      coachRepositoryFactory;
  final CoachAvailabilityRepository Function(SessionScope, bool Function())?
      coachAvailabilityFactory;
  final BookingListRepository Function(SessionScope, bool Function())?
      bookingListFactory;
  final AdminAccountContactRepository Function(SessionScope, bool Function())?
      accountContactFactory;
  final AdminMemberDirectoryRepository Function(SessionScope, bool Function())?
      memberDirectoryFactory;
  final RewardCatalogRepository Function(SessionScope, bool Function())?
      rewardCatalogFactory;
  final MiniGameContentRepository Function(SessionScope, bool Function())?
      miniGameContentFactory;
  final FacilitySettingsRepository Function(SessionScope, bool Function())?
      facilitySettingsFactory;

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
          buildWhen: (previous, current) => previous.session != current.session,
          builder: (context, state) {
            final app = MaterialApp(
              title: 'GainPath Admin Console',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              home: _AdminAuthGate(
                  datasetTransportFactory: datasetTransportFactory,
                  passwordResetSender: passwordResetSender ??
                      (email) => FlutterFirebaseAuthGateway()
                          .sendPasswordResetEmail(email)),
            );
            return AppRepositories.injected(
              key: ValueKey(state.session),
              session: state.session,
              tutorialRepositoryFactory: tutorialRepositoryFactory,
              routineRepositoryFactory: routineRepositoryFactory,
              coachRepositoryFactory: coachRepositoryFactory,
              coachAvailabilityFactory: coachAvailabilityFactory,
              bookingListFactory: bookingListFactory,
              accountContactFactory: accountContactFactory,
              memberDirectoryFactory: memberDirectoryFactory,
              rewardCatalogFactory: rewardCatalogFactory,
              miniGameContentFactory: miniGameContentFactory,
              facilitySettingsFactory: facilitySettingsFactory,
              reportingGatewayFactory: reportingGatewayFactory,
              child: app,
            );
          },
        ),
      ),
    );
  }
}

class _AdminAuthGate extends StatelessWidget {
  const _AdminAuthGate(
      {this.passwordResetSender, this.datasetTransportFactory});
  final FypDatasetTransportFactory? datasetTransportFactory;
  final Future<void> Function(String)? passwordResetSender;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state.status == AuthStatus.checkingSession) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (state.status == AuthStatus.needsVerification &&
            state.session != null) {
          return _AdminVerificationScreen(session: state.session!);
        }
        if (AuthRolePolicy.canEnter(state, allowed: const {AppRole.admin})) {
          return AdminShell(
              liveSession: state.session,
              datasetTransportFactory: datasetTransportFactory);
        }
        return _AdminLoginScreen(onPasswordReset: passwordResetSender);
      },
    );
  }
}

class _AdminVerificationScreen extends StatelessWidget {
  const _AdminVerificationScreen({required this.session});
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final repository = context.read<AuthRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Verify administrator email')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Check your inbox',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text('Verify ${session.email}, then return here.'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context
                        .read<AuthBloc>()
                        .add(const AuthRestoreRequested()),
                    child: const Text("I've verified my email"),
                  ),
                  if (repository is AuthVerificationActions)
                    TextButton(
                      onPressed: () async {
                        await (repository as AuthVerificationActions)
                            .resendEmailVerification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Verification email sent.')),
                          );
                        }
                      },
                      child: const Text('Resend verification email'),
                    ),
                  TextButton(
                    onPressed: () =>
                        context.read<AuthBloc>().add(const LoggedOut()),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

typedef _AdminLoginScreen = AdminLoginPage;
