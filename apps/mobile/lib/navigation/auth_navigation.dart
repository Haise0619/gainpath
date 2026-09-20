import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;

abstract final class AppRoutes {
  static const onboarding = '/';
  static const roleSelect = '/roles';
  static const memberLogin = '/login/member';
  static const coachLogin = '/login/coach';
  static const member = '/member';
  static const coach = '/coach';

  static String loginFor(AppRole role) => switch (role) {
        AppRole.member => memberLogin,
        AppRole.coach => coachLogin,
        AppRole.admin =>
          throw UnsupportedError('Use the separate admin application.'),
      };
  static String shellFor(AppRole role) => switch (role) {
        AppRole.member => member,
        AppRole.coach => coach,
        AppRole.admin =>
          throw UnsupportedError('Use the separate admin application.'),
      };
}
