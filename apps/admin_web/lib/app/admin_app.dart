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

class GainPathAdminWebApp extends StatelessWidget {
  const GainPathAdminWebApp(
      {super.key,
      this.authRepository,
      this.backendConfig,
      this.tutorialRepositoryFactory,
      this.routineRepositoryFactory});

  final AuthRepository? authRepository;
  final BackendConfig? backendConfig;
  final TutorialRepository Function(SessionScope)? tutorialRepositoryFactory;
  final RoutineTemplateRepository Function(SessionScope, TutorialRepository)?
      routineRepositoryFactory;

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
              title: 'GainPath Admin Console',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              home: _AdminAuthGate(config: config),
            );
            return AppRepositories(
              key: ValueKey(
                  (state.session?.scope, state.session?.role, config.mode)),
              config: config,
              session: state.session,
              tutorialRepositoryFactory: tutorialRepositoryFactory,
              routineRepositoryFactory: routineRepositoryFactory,
              child: app,
            );
          },
        ),
      ),
    );
  }
}

class _AdminAuthGate extends StatelessWidget {
  const _AdminAuthGate({required this.config});
  final BackendConfig config;

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
              liveSession: config.isFirebase ? state.session : null);
        }
        return const _AdminLoginScreen();
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

class _AdminLoginScreen extends StatefulWidget {
  const _AdminLoginScreen();

  @override
  State<_AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<_AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const RoleSelected(AppRole.admin));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    bloc.add(const RoleSelected(AppRole.admin));
    bloc.add(
      LoginSubmitted(
        email: _emailController.text,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final submitting = state.status == AuthStatus.submitting;
        return Scaffold(
          appBar: AppBar(title: const Text('GainPath Admin Web')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Administrator sign-in',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                            'Only organization Admin and Staff roles can enter this console.'),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Work email',
                            errorText: state.fieldErrors.email,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            errorText: state.fieldErrors.password,
                          ),
                        ),
                        if (state.message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.message!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: submitting ? null : _submit,
                          child: Text(submitting ? 'Signing in…' : 'Sign in'),
                        ),
                        TextButton(
                            onPressed: () => showForgotPasswordSheet(context,
                                initialEmail: _emailController.text,
                                asDialog: true),
                            child: const Text('Forgot password?')),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
