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
import '../../features/identity/presentation/shared/login_screen.dart';
import '../../features/identity/presentation/shared/role_select_screen.dart';

abstract final class AppRouteBuilders {
  static Map<String, WidgetBuilder> get builders => {
        WorkoutNavigation.guided: (_) => const WorkoutRoute(),
        AppRoutes.roleSelect: (_) => const RoleSelectScreen(),
        AppRoutes.memberLogin: (_) => const LoginScreen(role: AppRole.member),
        AppRoutes.coachLogin: (_) => const LoginScreen(role: AppRole.coach),
        AppRoutes.member: (_) =>
            const _RoleGuard(role: AppRole.member, child: MemberShell()),
        AppRoutes.coach: (_) =>
            const _RoleGuard(role: AppRole.coach, child: CoachShell()),
      };
}

class _RoleGuard extends StatelessWidget {
  const _RoleGuard({required this.role, required this.child});

  final AppRole role;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        if (AppRoutePolicy.canEnterShell(auth: auth, requiredRole: role)) {
          return child;
        }
        return LoginScreen(role: role);
      },
    );
  }
}
