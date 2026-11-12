import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show SessionScope, AppRole, AuthSession;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../di/workout_backup_factory.dart';
import '../../features/workout/domain/workout_backup.dart';
import '../../features/workout/domain/workout_contracts.dart';
import '../../features/workout/domain/routine_attempt.dart';
import '../../features/workout/application/workout_backup_coordinator.dart';
import '../../features/workout/presentation/member/workout_backup_screen.dart';
import '../../features/workout/presentation/member/widgets/workout_save_indicator.dart';

/// Reuses the account lease; summaries never wait on this optional presentation.
class WorkoutCloudSaveStatus extends StatefulWidget {
  WorkoutCloudSaveStatus.session(WorkoutSessionSummary summary,
      {super.key, this.factory})
      : scope = summary.scope,
        record = WorkoutBackupRecord.session(summary),
        attempt = null;
  WorkoutCloudSaveStatus.routine(RoutineAttempt value,
      {super.key, this.factory})
      : scope = value.scope,
        attempt = value,
        record = null;
  final SessionScope scope;
  final WorkoutBackupRecord? record;
  final RoutineAttempt? attempt;
  final WorkoutBackupFactory? factory;
  @override
  State<WorkoutCloudSaveStatus> createState() => _WorkoutCloudSaveStatusState();
}

class _WorkoutCloudSaveStatusState extends State<WorkoutCloudSaveStatus>
    with WidgetsBindingObserver {
  AuthBloc? _auth;
  AuthSession? _session;
  StreamSubscription<AuthState>? _authChanges;
  WorkoutBackupLease? _lease;
  bool _opening = false;
  SessionScope? active() => mounted &&
          identical(_auth?.state.session, _session) &&
          _session?.scope == widget.scope &&
          AuthRolePolicy.canEnter(_auth!.state, allowed: const {AppRole.member})
      ? widget.scope
      : null;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null ||
        (!workoutCloudBackupEnabled && widget.factory == null) ||
        widget.scope.datasetScope != null) {
      return;
    }
    try {
      _auth = context.read<AuthBloc>();
    } on ProviderNotFoundException {
      return;
    }
    _session = _auth!.state.session;
    WidgetsBinding.instance.addObserver(this);
    _authChanges = _auth!.stream.listen((_) {
      _lease?.coordinator.accountChanged();
      if (mounted) setState(() {});
    });
    unawaited(_open());
  }

  Future<void> _open() async {
    if (_opening || _lease != null || active() == null) return;
    _opening = true;
    WorkoutBackupLease? lease;
    try {
      lease =
          await (widget.factory ?? acquireWorkoutBackup)(widget.scope, active);
      if (active() == null) {
        lease.release();
        return;
      }
      if (lease.coordinator.scope != widget.scope) {
        throw StateError('Sync account mismatch');
      }
      await lease.coordinator.load();
      await lease.coordinator.refreshLocal();
      if (active() == null) {
        lease.release();
        return;
      }
      setState(() => _lease = lease);
      lease.scheduler?.opportunity();
    } catch (_) {
      lease
          ?.release(); // Local success remains accessible if metadata/network fails.
    } finally {
      _opening = false;
    }
  }

  @override
  void didUpdateWidget(covariant WorkoutCloudSaveStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scope != widget.scope) {
      _lease?.release();
      _lease = null;
      _session = _auth?.state.session;
      unawaited(_open());
    } else {
      unawaited(_lease?.coordinator.refreshLocal().catchError((Object _) {}) ??
          Future<void>.value());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lease?.scheduler?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authChanges?.cancel());
    _lease?.release();
    super.dispose();
  }

  void setup(WorkoutBackupCoordinator coordinator) {
    Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => WorkoutBackupScreen(coordinator: coordinator)));
  }

  @override
  Widget build(BuildContext context) {
    final c = _lease?.coordinator;
    if (c == null) return const WorkoutSaveIndicator();
    if (active() == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: c,
        builder: (context, _) {
          if (active() == null) return const SizedBox.shrink();
          final target = widget.attempt;
          final row = widget.record ??
              c.records
                  .where((r) =>
                      r.kind == 'routine' &&
                      r.id == target?.id &&
                      backupCanonical(r.payload['attempt']) ==
                          backupCanonical(target?.toJson()))
                  .firstOrNull;
          return WorkoutSaveIndicator(
              status:
                  row == null ? BackupRecordStatus.localOnly : c.statusFor(row),
              syncEnabled: c.state.enabled,
              onRetry: () => unawaited(c.sync().catchError((Object _) {})),
              onSetup: !c.state.consentChoiceMade ? () => setup(c) : null);
        });
  }
}
