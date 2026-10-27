import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_mobile/features/gamification/application/app_check_in_refresh_schedule.dart';
import 'package:gainpath_mobile/features/gamification/application/app_check_in_cubit.dart';
import 'package:gainpath_mobile/features/gamification/domain/app_check_in.dart';
import 'app_check_in_test.dart' as fixture;

void main() {
  test(
      'failed midnight refresh retries promptly instead of adding another full day window',
      () {
    var elapsed = Duration.zero;
    final schedule = AppCheckInRefreshSchedule(elapsed: () => elapsed);
    final scope = SessionScope(userId: 'member', organizationId: 'gainpath'),
        snapshot = AppCheckInSnapshot.fromJson(
            fixture.snapshotJson(
                SessionScope(userId: 'member', organizationId: 'gainpath'),
                claimed: true),
            SessionScope(userId: 'member', organizationId: 'gainpath'));
    expect(snapshot.scope, scope);
    final ready =
        AppCheckInState(status: AppCheckInStatus.ready, snapshot: snapshot);
    expect(schedule.next(ready, foreground: true),
        const Duration(hours: 12, milliseconds: 50));
    elapsed = const Duration(hours: 12, seconds: 1);
    expect(
        schedule.next(
            AppCheckInState(status: AppCheckInStatus.error, snapshot: snapshot),
            foreground: true),
        const Duration(seconds: 30));
    expect(schedule.next(ready, foreground: false), isNull);
  });
}
