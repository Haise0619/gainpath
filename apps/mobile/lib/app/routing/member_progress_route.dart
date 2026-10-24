import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/analytics.dart';
import 'package:gainpath_domain/membership.dart';
import '../../features/membership/presentation/shared/membership_access_gate.dart';
import '../di/membership_factory.dart';
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

enum MemberProgressView { dashboard, history, performance, form }

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
      this.repositoryFactory = createLocalMemberProgressRepository});
  final SessionScope scope;
  final LocalMemberProgressRepositoryFactory repositoryFactory;
  final MemberProgressBuilder builder;
  @override
  State<MemberProgressHost> createState() => _MemberProgressHostState();
}

class _MemberProgressHostState extends State<MemberProgressHost>
    with WidgetsBindingObserver {
  MemberProgressCubit? _cubit;
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _authSubscription;
  StreamSubscription<MemberProgressState>? _progressSubscription;
  Timer? _weekTimer;
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
    _authSubscription = _auth!.stream.listen((_) => _cubit?.accountChanged());
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
    } catch (_) {
      if (mounted && _activeScope() != null) {
        setState(() => _initializationError =
            'Could not open measured workouts saved on this device.');
      }
    } finally {
      _initializing = false;
    }
  }

  Future<void> _refresh() async {
    if (_activeScope() == null) return;
    if (_cubit != null) {
      await _cubit!.load();
    } else {
      await _initialize();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
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
                openWorkout: _openWorkout)));
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
          _progressContent(state, view, refresh, open, openWorkout));
}

class _ScopedProgressPage extends StatelessWidget {
  const _ScopedProgressPage(
      {required this.scope,
      required this.auth,
      required this.cubit,
      required this.view,
      required this.refresh,
      required this.open,
      required this.openWorkout});
  final SessionScope scope;
  final AuthBloc auth;
  final MemberProgressCubit cubit;
  final MemberProgressView view;
  final Future<void> Function() refresh;
  final void Function(MemberProgressView) open;
  final void Function(LocalWorkoutProgressRecord) openWorkout;
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      bloc: auth,
      builder: (context, state) {
        if (state.session?.scope != scope ||
            !AuthRolePolicy.canEnter(state, allowed: const {AppRole.member})) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s progress.')));
        }
        return BlocBuilder<MemberProgressCubit, MemberProgressState>(
            bloc: cubit,
            builder: (context, state) =>
                _progressContent(state, view, refresh, open, openWorkout));
      });
}

Widget _progressContent(
    MemberProgressState state,
    MemberProgressView view,
    Future<void> Function() refresh,
    void Function(MemberProgressView) open,
    void Function(LocalWorkoutProgressRecord) openWorkout) {
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
  final screen = switch (view) {
    MemberProgressView.dashboard => ProgressDashboardScreen(
        localProgress: progress,
        onRefresh: refresh,
        onOpenWorkout: openWorkout,
        onOpenHistory: () => open(MemberProgressView.history),
        onOpenPerformance: () => open(MemberProgressView.performance),
        onOpenForm: () => open(MemberProgressView.form)),
    MemberProgressView.history => ActivityTimelineScreen(
        localProgress: progress,
        onRefresh: refresh,
        onOpenWorkout: openWorkout),
    MemberProgressView.performance =>
      WorkoutPerformanceScreen(localProgress: progress),
    MemberProgressView.form => PostureAccuracyScreen(localProgress: progress),
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
