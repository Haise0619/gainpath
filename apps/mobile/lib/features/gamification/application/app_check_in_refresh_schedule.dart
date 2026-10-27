import 'app_check_in_cubit.dart';
import '../domain/app_check_in.dart';

/// Keeps the server's reset interval anchored to monotonic elapsed time.
class AppCheckInRefreshSchedule {
  AppCheckInRefreshSchedule({Duration Function()? elapsed}) {
    final watch = Stopwatch()..start();
    _elapsed = elapsed ?? () => watch.elapsed;
  }
  late final Duration Function() _elapsed;
  AppCheckInSnapshot? _snapshot;
  Duration _received = Duration.zero;
  Duration? next(AppCheckInState state, {required bool foreground}) {
    final snapshot = state.snapshot;
    if (!foreground || snapshot == null) return null;
    if (!identical(snapshot, _snapshot)) {
      _snapshot = snapshot;
      _received = _elapsed();
    }
    final remaining = snapshot.nextResetMillis -
        snapshot.serverNowMillis -
        (_elapsed() - _received).inMilliseconds;
    if (remaining <= 0) return const Duration(seconds: 30);
    if (state.status == AppCheckInStatus.error) {
      return Duration(milliseconds: remaining < 30000 ? remaining : 30000);
    }
    return Duration(milliseconds: remaining + 50);
  }
}
