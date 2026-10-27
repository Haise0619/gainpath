import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/membership.dart';
import '../../navigation/membership_access_gate.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/analytics/application/member_progress_cubit.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/analytics/presentation/shared/progress_dashboard_screen.dart';
import '../../features/analytics/presentation/member/activity_timeline_screen.dart';
import '../../features/analytics/presentation/member/workout_performance_screen.dart';
import '../../features/analytics/presentation/member/posture_accuracy_screen.dart';
import '../../features/analytics/presentation/member/widgets/local_progress_widgets.dart';
import '../../features/workout/presentation/member/workout_result_screen.dart';
import '../di/local_member_progress_factory.dart';
import '../../features/workout/domain/routine_attempt.dart';
import '../../features/workout/presentation/member/routine_history_screen.dart';
import 'routine_journey_route.dart';
import 'member_workout_report_route.dart';
import '../di/workout_backup_factory.dart';
import '../../features/workout/presentation/member/workout_backup_screen.dart';
import '../../features/workout/application/workout_backup_coordinator.dart';

enum MemberProgressView {
  dashboard,
  history,
  performance,
  form,
  routines,
  backup
}

typedef MemberProgressBuilder = Widget Function(
    BuildContext context,
    MemberProgressState state,
    Future<void> Function() refresh,
    void Function(MemberProgressView) open,
    void Function(LocalWorkoutProgressRecord) openWorkout);

/// App composition owns stores, account lifetime and navigation. Browsing reads
/// existing durable summaries/receipts only; it never starts the upload worker.
class MemberProgressHost extends StatefulWidget {
  const MemberProgressHost(
      {super.key,
      required this.scope,
      required this.builder,
      this.backupFactory,
      this.repositoryFactory = createLocalMemberProgressRepository});
  final SessionScope scope;
  final LocalMemberProgressRepositoryFactory repositoryFactory;
  final MemberProgressBuilder builder;
  final WorkoutBackupFactory? backupFactory;
  @override
  State<MemberProgressHost> createState() => _MemberProgressHostState();
}

class _BackupPresentation {
  const _BackupPresentation(this.coordinator, this.error);
  final WorkoutBackupCoordinator? coordinator;
  final String? error;
}

class _MemberProgressHostState extends State<MemberProgressHost>
    with WidgetsBindingObserver {
  MemberProgressCubit? _cubit;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<MemberProgressState>? _progressSubscription;
  Timer? _weekTimer;
  Timer? _backupTimer;
  WorkoutBackupLease? _backupLease;
  final _backupPresentation =
      ValueNotifier(const _BackupPresentation(null, null));
  String? _backupError;
  bool _foreground = true, _backupOpening = false;
  String? _initializationError;
  bool _initializing = false;
  bool _authorized(AuthState state) =>
      state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(state, allowed: const {AppRole.member});
  SessionScope? _activeScope() =>
      _auth != null && _authorized(_auth!.state) ? widget.scope : null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) return;
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthBloc>();
    _authSubscription = _auth!.stream.listen((_) {
      _cubit?.accountChanged();
      _backupLease?.coordinator.accountChanged();
    });
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    if (_initializing || !mounted || _activeScope() == null) return;
    _initializing = true;
    try {
      final repository =
          await widget.repositoryFactory(widget.scope, _activeScope);
      if (!mounted || _activeScope() == null) return;
      if (repository.scope != widget.scope) {
        throw StateError('Repository scope mismatch');
      }
      final cubit = MemberProgressCubit(
          repository: repository, activeScope: _activeScope);
      _progressSubscription = cubit.stream.listen((state) {
        _weekTimer?.cancel();
        if (state.progress != null) {
          final delay =
              state.progress!.weekEnd.difference(DateTime.now().toUtc());
          if (delay.isNegative) return;
          _weekTimer =
              Timer(delay + const Duration(milliseconds: 20), cubit.load);
        }
      });
      setState(() {
        _initializationError = null;
        _cubit = cubit;
      });
      await cubit.load();
      if (_backupConfigured) await _initializeBackup();
    } catch (_) {
      if (mounted && _activeScope() != null) {
        setState(() => _initializationError =
            'Could not open measured workouts saved on this device.');
      }
    } finally {
      _initializing = false;
    }
  }

  bool get _backupConfigured =>
      workoutCloudBackupEnabled || widget.backupFactory != null;
  Future<void> _initializeBackup() async {
    if (!mounted ||
        _activeScope() == null ||
        _backupLease != null ||
        _backupOpening) {
      return;
    }
    _backupOpening = true;
    try {
      _backupPresentation.value =
          const _BackupPresentation(null, 'Opening backup…');
      final lease = await (widget.backupFactory ?? acquireWorkoutBackup)(
          widget.scope, _activeScope);
      if (!mounted || _activeScope() == null) {
        lease.release();
        return;
      }
      _backupLease = lease;
      await lease.coordinator.load();
      if (!mounted || _activeScope() == null) {
        lease.release();
        _backupLease = null;
        return;
      }
      if (mounted) setState(() => _backupError = null);
      _backupPresentation.value = _BackupPresentation(lease.coordinator, null);
      await _syncBackup();
    } catch (_) {
      _backupLease?.release();
      _backupLease = null;
      if (mounted && _activeScope() != null) {
        setState(() => _backupError =
            'Backup storage is unavailable. Your local history is retained.');
        _backupPresentation.value = _BackupPresentation(null, _backupError);
      }
    } finally {
      _backupOpening = false;
    }
  }

  Future<void> _syncBackup() async {
    _backupTimer?.cancel();
    final c = _backupLease?.coordinator;
    if (!_foreground || _activeScope() == null || c == null) return;
    try {
      await c.sync();
    } catch (_) {
      if (mounted && _activeScope() != null) {
        setState(
            () => _backupError = 'Backup status could not be saved. Retry.');
      }
    }
    if (!mounted || !_foreground || _activeScope() == null) return;
    _backupTimer = Timer(
        Duration(seconds: c.state.lastError == null ? 60 : 120), () async {
      await _syncBackup();
      if (mounted && _activeScope() != null) await _cubit?.load();
    });
  }

  Future<void> _refresh() async {
    if (_activeScope() == null) return;
    if (_cubit != null) {
      await _syncBackup();
      await _cubit!.load();
    } else {
      await _initialize();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      unawaited(_refresh());
    } else {
      _backupTimer?.cancel();
    }
  }

  Future<void> _open(MemberProgressView view) async {
    if (_activeScope() == null || _cubit == null) return;
    await _refresh();
    if (!mounted || _activeScope() == null || _cubit == null) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => _ScopedProgressPage(
                scope: widget.scope,
                auth: _auth!,
                cubit: _cubit!,
                view: view,
                refresh: _refresh,
                open: _open,
                openWorkout: _openWorkout,
                backupState: _backupPresentation,
                retryBackup: _backupConfigured ? _initializeBackup : null)));
    if (mounted) await _refresh();
  }

  Future<void> _openWorkout(LocalWorkoutProgressRecord record) async {
    if (_activeScope() == null ||
        _cubit == null ||
        record.scope != widget.scope) {
      return;
    }
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocBuilder<AuthBloc, AuthState>(
                bloc: _auth,
                builder: (context, auth) {
                  if (!_authorized(auth)) {
                    return const Scaffold(
                        body: Center(
                            child: Text(
                                'Sign in to view this account’s result.')));
                  }
                  return BlocBuilder<MemberProgressCubit, MemberProgressState>(
                      bloc: _cubit,
                      builder: (context, state) {
                        final summary =
                            state.snapshot?.summaries[record.sessionId];
                        final matches = state.progress?.records
                            .where((r) => r.sessionId == record.sessionId);
                        if (summary == null ||
                            matches == null ||
                            matches.isEmpty) {
                          return const Scaffold(
                              body: Center(
                                  child: Text(
                                      'This saved workout is unavailable.')));
                        }
                        return WorkoutResultScreen.measured(
                            summary: summary,
                            syncPanel: LocalProgressRecordTile(
                                record: matches.first,
                                utcOffset: state.progress!.utcOffset));
                      });
                })));
    if (mounted) await _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _weekTimer?.cancel();
    _backupTimer?.cancel();
    _backupLease?.release();
    _backupPresentation.dispose();
    _authSubscription?.cancel();
    _progressSubscription?.cancel();
    _cubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      bloc: _auth,
      builder: (context, auth) {
        if (!_authorized(auth)) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s progress.')));
        }
        final cubit = _cubit;
        if (cubit == null) {
          return widget.builder(
              context,
              MemberProgressState(
                  status: _initializationError == null
                      ? MemberProgressStatus.loading
                      : MemberProgressStatus.failure,
                  error: _initializationError),
              _refresh,
              _open,
              _openWorkout);
        }
        return BlocBuilder<MemberProgressCubit, MemberProgressState>(
            bloc: cubit,
            builder: (context, state) =>
                widget.builder(context, state, _refresh, _open, _openWorkout));
      });
}

class MemberProgressRoute extends StatelessWidget {
  const MemberProgressRoute(
      {super.key,
      required this.scope,
      this.view = MemberProgressView.dashboard,
      this.repositoryFactory = createLocalMemberProgressRepository});
  final SessionScope scope;
  final MemberProgressView view;
  final LocalMemberProgressRepositoryFactory repositoryFactory;
  @override
  Widget build(BuildContext context) => MemberProgressHost(
      key: ValueKey(scope),
      scope: scope,
      repositoryFactory: repositoryFactory,
      builder: (context, state, refresh, open, openWorkout) =>
          _progressContent(context, state, view, refresh, open, openWorkout));
}

class _ScopedProgressPage extends StatelessWidget {
  const _ScopedProgressPage(
      {required this.scope,
      required this.auth,
      required this.cubit,
      required this.view,
      required this.refresh,
      required this.open,
      required this.openWorkout,
      required this.backupState,
      this.retryBackup});
  final SessionScope scope;
  final AuthBloc auth;
  final MemberProgressCubit cubit;
  final MemberProgressView view;
  final Future<void> Function() refresh;
  final void Function(MemberProgressView) open;
  final void Function(LocalWorkoutProgressRecord) openWorkout;
  final ValueListenable<_BackupPresentation> backupState;
  final VoidCallback? retryBackup;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<
          _BackupPresentation>(
      valueListenable: backupState,
      builder: (context, presentation, _) => BlocBuilder<AuthBloc, AuthState>(
          bloc: auth,
          builder: (context, state) {
            if (state.session?.scope != scope ||
                !AuthRolePolicy.canEnter(state,
                    allowed: const {AppRole.member})) {
              return const Scaffold(
                  body: Center(
                      child: Text('Sign in to view this account’s progress.')));
            }
            return BlocBuilder<MemberProgressCubit, MemberProgressState>(
                bloc: cubit,
                builder: (context, state) => _progressContent(
                    context, state, view, refresh, open, openWorkout,
                    backup: presentation.coordinator,
                    backupError: presentation.error,
                    retryBackup: retryBackup));
          }));
}

Widget _progressContent(
    BuildContext context,
    MemberProgressState state,
    MemberProgressView view,
    Future<void> Function() refresh,
    void Function(MemberProgressView) open,
    void Function(LocalWorkoutProgressRecord) openWorkout,
    {WorkoutBackupCoordinator? backup,
    String? backupError,
    VoidCallback? retryBackup}) {
  final progress = state.progress;
  if (progress == null) {
    return Scaffold(
        appBar: AppBar(title: const Text('Local workout progress')),
        body: state.status == MemberProgressStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(state.error ?? 'This account’s progress is unavailable.'),
                FilledButton(onPressed: refresh, child: const Text('Retry'))
              ])));
  }
  void openReport() {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => MemberWorkoutReportRoute(scope: progress.scope)));
  }

  final screen = switch (view) {
    MemberProgressView.dashboard => ProgressDashboardScreen(
        onOpenReport: openReport,
        localProgress: progress,
        routineProgress: state.routines,
        onOpenRoutineHistory: () => open(MemberProgressView.routines),
        onOpenBackup: () => open(MemberProgressView.backup),
        onOpenRoutine: (a) => openRoutineAttempt(context, a, refresh),
        onRefresh: refresh,
        onOpenWorkout: openWorkout,
        onOpenHistory: () => open(MemberProgressView.history),
        onOpenPerformance: () => open(MemberProgressView.performance),
        onOpenForm: () => open(MemberProgressView.form)),
    MemberProgressView.history => ActivityTimelineScreen(
        onOpenReport: openReport,
        localProgress: progress,
        onRefresh: refresh,
        onOpenWorkout: openWorkout),
    MemberProgressView.performance => WorkoutPerformanceScreen(
        localProgress: progress, onOpenReport: openReport),
    MemberProgressView.form =>
      PostureAccuracyScreen(localProgress: progress, onOpenReport: openReport),
    MemberProgressView.routines => RoutineHistoryScreen(
        attempts: state.routines?.records ?? const [],
        available: state.routines != null,
        onOpenBackup: () => open(MemberProgressView.backup),
        onRefresh: refresh,
        onOpenAttempt: (a) => openRoutineAttempt(context, a, refresh)),
    MemberProgressView.backup => WorkoutBackupScreen(
        coordinator: backup,
        error: backupError,
        onRetry: retryBackup,
        onChanged: refresh),
  };
  final warnings = state.snapshot?.warnings ?? const <String>[];
  return Column(children: [
    if (warnings.isNotEmpty)
      SafeArea(
          bottom: false,
          child: Material(
              color: Colors.amber.shade100,
              child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(warnings.join('\n'))))),
    Expanded(
        child: view == MemberProgressView.performance ||
                view == MemberProgressView.form
            ? MembershipAccessGate(
                enabled: membershipAccessEnforcementEnabled,
                feature: MembershipAccessFeature.advancedReport,
                resourceId: view == MemberProgressView.performance
                    ? 'performance_trends'
                    : 'form_trends',
                child: screen)
            : screen)
  ]);
}

/// The detail route remains guarded even if the account changes while it is open.
Future<void> openRoutineAttempt(BuildContext context, RoutineAttempt attempt,
    Future<void> Function() refresh) async {
  final auth = context.read<AuthBloc>();
  bool authorized() =>
      auth.state.session?.scope == attempt.scope &&
      AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member});
  if (!authorized()) return;
  Future<void> continueAttempt(
      BuildContext detailContext, RoutineJourneyAction action) async {
    if (!authorized()) return;
    await Navigator.pushReplacement(
        detailContext,
        MaterialPageRoute<void>(
            builder: (_) => RoutineJourneyRoute(
                scope: attempt.scope,
                routine: attempt.routine,
                attemptId: attempt.id,
                action: action)));
  }

  await Navigator.push(
      context,
      MaterialPageRoute<void>(
          builder: (detailContext) => BlocBuilder<AuthBloc, AuthState>(
              bloc: auth,
              builder: (_, state) {
                if (!authorized()) {
                  return const Scaffold(
                      body: Center(
                          child:
                              Text('Sign in to view this account’s routine.')));
                }
                final hasNext = attempt.routine.exercises
                    .any((e) => e.dayNumber > attempt.day);
                return RoutineAttemptDetailScreen(
                    attempt: attempt,
                    onResume: () => continueAttempt(
                        detailContext, RoutineJourneyAction.resume),
                    onRepeat: () => continueAttempt(
                        detailContext, RoutineJourneyAction.repeat),
                    onNextDay: hasNext
                        ? () => continueAttempt(
                            detailContext, RoutineJourneyAction.nextDay)
                        : null,
                    onViewProgress: () => Navigator.push(
                        detailContext,
                        MaterialPageRoute<void>(
                            builder: (_) =>
                                MemberProgressRoute(scope: attempt.scope))));
              })));
  if (context.mounted && authorized()) await refresh();
}
