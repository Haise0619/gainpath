import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/shells/coach_shell.dart';
import 'package:gainpath_mobile/app/shells/member_shell.dart';
import 'package:gainpath_mobile/features/identity/presentation/shared/login_screen.dart';
import 'package:gainpath_mobile/navigation/auth_navigation.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import 'mock_app_scope.dart';

/// Explicit seeded shell harness. It never constructs a Firebase dependency.
class TestMobileApp extends StatefulWidget {
  const TestMobileApp({super.key, this.authRepository});

  final InMemoryAuthRepository? authRepository;

  @override
  State<TestMobileApp> createState() => _TestMobileAppState();
}

class _TestMobileAppState extends State<TestMobileApp> {
  late final repository = widget.authRepository ?? InMemoryAuthRepository();

  @override
  void dispose() {
    if (widget.authRepository == null) unawaited(repository.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      RepositoryProvider<AuthRepository>.value(
        value: repository,
        child: BlocProvider(
          create: (_) => AuthBloc(repository: repository),
          child: BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
            return MockAppScope(
              key: ObjectKey(state.session),
              child: MaterialApp(
                key: ObjectKey(state.session),
                title: 'GainPath test fixture',
                theme: AppTheme.build(),
                home: const _TestRoleGate(),
                routes: {
                  AppRoutes.login: (_) =>
                      const LoginScreen(prefillDemoPassword: true),
                  AppRoutes.member: (_) =>
                      const _TestRoleGate(requiredRole: AppRole.member),
                  AppRoutes.coach: (_) =>
                      const _TestRoleGate(requiredRole: AppRole.coach),
                },
              ),
            );
          }),
        ),
      );
}

class _TestRoleGate extends StatelessWidget {
  const _TestRoleGate({this.requiredRole});

  final AppRole? requiredRole;

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          if (state.status == AuthStatus.checkingSession) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          }
          final allowed = requiredRole == null
              ? const {AppRole.member, AppRole.coach}
              : {requiredRole!};
          if (!AuthRolePolicy.canEnter(state, allowed: allowed)) {
            return const LoginScreen(prefillDemoPassword: true);
          }
          return state.session!.role == AppRole.coach
              ? const CoachShell()
              : const MemberShell();
        },
      );
}
