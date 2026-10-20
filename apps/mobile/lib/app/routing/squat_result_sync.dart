import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AppRole;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/data/real_workout_outbox_repository.dart';
import '../../features/workout/domain/real_workout_contract.dart';
import '../../features/workout/domain/workout_contracts.dart';
import '../../features/workout/presentation/member/real_workout_sync_panel.dart';
import '../../features/workout/presentation/member/workout_result_screen.dart';
import '../../infrastructure/firebase/firebase_real_workout_gateway.dart';
import '../di/real_workout_sync_store_factory.dart';

String newWorkoutRequestId() => List.generate(16,
        (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
    .join();

class SquatResultSync extends StatefulWidget {
  const SquatResultSync(
      {super.key,
      required this.summary,
      required this.auth,
      this.acknowledgement,
      this.repositoryFactory});
  final WorkoutSessionSummary summary;
  final AuthBloc auth;
  final WorkoutConsentAcknowledgement? acknowledgement;
  final Future<RealWorkoutOutboxRepository> Function()? repositoryFactory;
  @override
  State<SquatResultSync> createState() => _SquatResultSyncState();
}

class _SquatResultSyncState extends State<SquatResultSync> {
  RealWorkoutOutboxRepository? _repository;
  String? _error;
  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      final scope = widget.summary.scope;
      final repo = widget.repositoryFactory == null
          ? RealWorkoutOutboxRepository(
              scope: scope,
              activeScope: () => widget.auth.state.session?.scope == scope &&
                      AuthRolePolicy.canEnter(widget.auth.state,
                          allowed: const {AppRole.member})
                  ? scope
                  : null,
              store: await createRealWorkoutSyncStore(scope),
              gateway: FirebaseRealWorkoutGateway(scope: scope),
              newRequestId: newWorkoutRequestId)
          : await widget.repositoryFactory!();
      if (!mounted) {
        repo.dispose();
        return;
      }
      _repository = repo;
      await repo.load();
      // Recover only a durable session opt-in established before capture.
      await repo.enqueueFromIntent(widget.summary);
      if (!mounted) return;
      setState(() {});
      await repo.sync();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Upload status is unavailable. The local result is still saved.');
      }
    }
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WorkoutResultScreen.measured(
      summary: widget.summary,
      syncPanel: _error != null
          ? Text(_error!)
          : _repository == null
              ? const Text('Checking saved upload status…')
              : RealWorkoutSyncPanel(
                  repository: _repository!,
                  sessionId: widget.summary.sessionId));
}
