import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import '../../features/gamification/domain/app_check_in.dart';
import '../../infrastructure/firebase/firebase_app_check_in_repository.dart';

const appCheckInEnabled = bool.fromEnvironment('APP_CHECK_IN_ENABLED') ||
    bool.fromEnvironment('USE_FIREBASE_EMULATORS');
Future<AppCheckInRepository> createAppCheckInRepository(
        SessionScope scope, SessionScope? Function() activeScope) async =>
    appCheckInEnabled
        ? FirebaseAppCheckInRepository(scope: scope, activeScope: activeScope)
        : _UnavailableCheckIn(scope);

class _UnavailableCheckIn implements AppCheckInRepository {
  _UnavailableCheckIn(this.scope);
  @override
  final SessionScope scope;
  @override
  Future<AppCheckInResult> overview() =>
      Future.error(const AppCheckInUnavailable());
  @override
  Future<AppCheckInResult> claim() =>
      Future.error(const AppCheckInUnavailable());
}
