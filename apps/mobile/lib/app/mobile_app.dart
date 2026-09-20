import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'app.dart';
import 'routing/app_routes.dart';
import 'routing/feature_routes.dart';
import 'shells/member_shell.dart';
import 'shells/coach_shell.dart';
import '../features/identity/presentation/shared/login_screen.dart';
import '../features/identity/presentation/shared/onboarding_screen.dart';
import '../features/identity/presentation/shared/email_verification_screen.dart';
import '../features/identity/presentation/member/profile_setup_screen.dart';

class GainPathMobileApp extends StatelessWidget {
  const GainPathMobileApp({super.key, this.authRepository, this.backendConfig});

  final AuthRepository? authRepository;
  final BackendConfig? backendConfig;

  @override
  Widget build(BuildContext context) {
    final config = backendConfig ?? BackendConfig.fromEnvironment();
    config.validate();
    return RepositoryProvider<AuthRepository>(
      create: (_) =>
          authRepository ?? AuthRepositoryFactory.create(config: config),
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
              (previous.session?.scope, previous.session?.role) !=
              (current.session?.scope, current.session?.role),
          builder: (context, state) => AppScope(
            key: ValueKey((state.session?.scope, state.session?.role)),
            config: config,
            child: MaterialApp(
              title: 'GainPath',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.build(),
              home: const _MobileAuthGate(),
              routes: AppRouteBuilders.builders,
              onGenerateRoute: buildFeatureRoute,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileAuthGate extends StatefulWidget {
  const _MobileAuthGate();
  @override
  State<_MobileAuthGate> createState() => _MobileAuthGateState();
}

class _MobileAuthGateState extends State<_MobileAuthGate> {
  bool _setupProfile = false;

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
                : null,
            onSignOut: () => context.read<AuthBloc>().add(const LoggedOut()),
          );
        }
        return const _MobileLoginScreen();
      },
    );
  }
}

class _MobileLoginScreen extends StatefulWidget {
  const _MobileLoginScreen();

  @override
  State<_MobileLoginScreen> createState() => _MobileLoginScreenState();
}

class _MobileLoginScreenState extends State<_MobileLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  AppRole _role = AppRole.member;

  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const RoleSelected(AppRole.member));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _selectRole(AppRole role) {
    setState(() => _role = role);
    context.read<AuthBloc>().add(RoleSelected(role));
  }

  void _submit() {
    final bloc = context.read<AuthBloc>();
    bloc.add(RoleSelected(_role));
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
          appBar: AppBar(title: const Text('GainPath Mobile')),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sign in to GainPath Mobile',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Choose the role for this mobile session.'),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Gym Member'),
                          selected: _role == AppRole.member,
                          onSelected: (_) => _selectRole(AppRole.member),
                        ),
                        ChoiceChip(
                          label: const Text('Fitness Coach'),
                          selected: _role == AppRole.coach,
                          onSelected: (_) => _selectRole(AppRole.coach),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email',
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
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: submitting ? null : _submit,
                      child: Text(submitting ? 'Signing in…' : 'Sign in'),
                    ),
                    TextButton(
                        onPressed: submitting
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => LoginScreen(
                                        role: _role,
                                        initiallyRegistering: true))),
                        child: const Text('Create account')),
                    TextButton(
                        onPressed: () => showForgotPasswordSheet(context,
                            initialEmail: _emailController.text),
                        child: const Text('Forgot password?')),
                    TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                                builder: (_) => const OnboardingScreen())),
                        child: const Text('View introduction')),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
