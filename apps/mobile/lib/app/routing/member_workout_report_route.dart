import 'dart:async';
import 'package:gainpath_domain/analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/analytics/application/member_progress_cubit.dart';
import '../../features/analytics/domain/local_member_progress_repository.dart';
import '../../features/analytics/domain/member_workout_report.dart';
import '../../features/analytics/presentation/member/workout_report_screen.dart';
import '../../infrastructure/android_workout_report_exporter.dart';
import '../di/local_member_progress_factory.dart';

class MemberWorkoutReportRoute extends StatefulWidget {
  const MemberWorkoutReportRoute(
      {super.key,
      required this.scope,
      this.repositoryFactory = createLocalMemberProgressRepository,
      this.exporter,
      this.initialFilter,
      this.onOpenWorkout,
      this.onOpenRoutine});
  final void Function(LocalWorkoutProgressRecord)? onOpenWorkout;
  final void Function(String)? onOpenRoutine;
  final SessionScope scope;
  final WorkoutReportFilter? initialFilter;
  final LocalMemberProgressRepositoryFactory repositoryFactory;
  final WorkoutReportExporter? exporter;
  @override
  State<MemberWorkoutReportRoute> createState() =>
      _MemberWorkoutReportRouteState();
}

class _MemberWorkoutReportRouteState extends State<MemberWorkoutReportRoute> {
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  MemberProgressCubit? _cubit;
  late final WorkoutReportExporter _exporter =
      widget.exporter ?? const AndroidWorkoutReportExporter();
  bool _opening = false;
  String? _error;
  int _generation = 0;
  SessionScope? _active() => mounted &&
          _auth?.state.session?.scope == widget.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.scope
      : null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) return;
    _auth = context.read<AuthBloc>();
    _subscription = _auth!.stream.listen((_) {
      if (_active() == null) {
        ++_generation;
        _cubit?.accountChanged();
        unawaited(_exporter.cancel());
      }
    });
    unawaited(_load());
  }

  Future<void> _load() async {
    if (_active() == null || _opening) return;
    if (_cubit != null) {
      await _cubit!.load();
      return;
    }
    final generation = ++_generation;
    _opening = true;
    try {
      final repo = await widget.repositoryFactory(widget.scope, _active);
      if (!mounted || _active() == null || generation != _generation) return;
      _cubit = MemberProgressCubit(repository: repo, activeScope: _active);
      setState(() => _error = null);
      await _cubit!.load();
    } catch (_) {
      if (mounted && _active() != null) {
        setState(() => _error = 'Could not open saved workout history.');
      }
    } finally {
      _opening = false;
    }
  }

  @override
  void dispose() {
    ++_generation;
    unawaited(_subscription?.cancel());
    unawaited(_cubit?.close());
    unawaited(_exporter.cancel());
    super.dispose();
  }

  Widget _screen(MemberProgressState state) => WorkoutReportScreen(
      scope: widget.scope,
      onOpenWorkout: widget.onOpenWorkout,
      onOpenRoutine: widget.onOpenRoutine,
      initialFilter: widget.initialFilter,
      source: state.snapshot,
      asOf: state.progress?.asOf ?? DateTime.now(),
      exporter: _exporter,
      isCurrent: () => _active() != null,
      onRefresh: _load,
      loading: state.status == MemberProgressStatus.loading,
      error: state.error ?? _error);
  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      bloc: _auth,
      builder: (context, auth) {
        if (_active() == null) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s report.')));
        }
        if (_cubit == null) {
          return _screen(MemberProgressState(
              status: _error == null
                  ? MemberProgressStatus.loading
                  : MemberProgressStatus.failure));
        }
        return BlocBuilder<MemberProgressCubit, MemberProgressState>(
            bloc: _cubit, builder: (context, state) => _screen(state));
      });
}
