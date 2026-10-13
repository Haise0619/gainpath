import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app_route_policy.dart';
import '../../navigation/auth_navigation.dart';
export '../../navigation/auth_navigation.dart';
import '../../navigation/workout_navigation.dart';
import 'workout_route.dart';
import '../shells/coach_shell.dart';
import '../shells/member_shell.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import '../../features/identity/presentation/shared/login_screen.dart';

abstract final class AppRouteBuilders {
  static Map<String, WidgetBuilder> withLogin(WidgetBuilder loginBuilder) => {
        ...builders,
        for (final route in [
          AppRoutes.login,
          AppRoutes.roleSelect,
          AppRoutes.memberLogin,
          AppRoutes.coachLogin
        ])
          route: loginBuilder,
        AppRoutes.member: (_) => _RoleGuard(
            role: AppRole.member,
            loginBuilder: loginBuilder,
            child: const MemberShell()),
        AppRoutes.coach: (_) => _RoleGuard(
            role: AppRole.coach,
            loginBuilder: loginBuilder,
            child: const CoachShell()),
      };
  static Map<String, WidgetBuilder> get builders => {
        WorkoutNavigation.guided: (_) => const WorkoutRoute(),
        AppRoutes.login: (_) => const LoginScreen(),
        AppRoutes.roleSelect: (_) => const LoginScreen(),
        AppRoutes.memberLogin: (_) => const LoginScreen(),
        AppRoutes.coachLogin: (_) => const LoginScreen(),
        AppRoutes.member: (_) =>
            const _RoleGuard(role: AppRole.member, child: MemberShell()),
        AppRoutes.coach: (_) =>
            const _RoleGuard(role: AppRole.coach, child: CoachShell()),
      };
}

class _RoleGuard extends StatelessWidget {
  const _RoleGuard(
      {required this.role, required this.child, this.loginBuilder});

  final AppRole role;
  final Widget child;
  final WidgetBuilder? loginBuilder;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        if (AppRoutePolicy.canEnterShell(auth: auth, requiredRole: role)) {
          return child;
        }
        return loginBuilder?.call(context) ?? const LoginScreen();
      },
    );
  }
}
