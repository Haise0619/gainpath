import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/application/workout_program_controller.dart';
import '../../features/workout/domain/program_enrollment.dart';
import '../../features/workout/domain/routine_journey.dart';
import '../../features/workout/presentation/member/workout_program_screen.dart';
import '../../infrastructure/firebase/firebase_workout_program_catalog.dart';
import '../di/program_store_factory.dart';
import '../di/workout_store_factory.dart';
import 'routine_journey_route.dart';
import 'squat_result_sync.dart' show newWorkoutRequestId;

class WorkoutProgramRoute extends StatefulWidget {
  const WorkoutProgramRoute(
      {super.key,
      required this.scope,
      this.storeFactory = createProgramEnrollmentStore,
      this.routineStoreFactory = createRoutineJourneyStore,
      this.catalogFactory,
      this.clock = DateTime.now});
  final SessionScope scope;
  final Future<ProgramEnrollmentStore> Function(SessionScope) storeFactory;
  final Future<RoutineJourneyStore> Function(SessionScope) routineStoreFactory;
  final WorkoutProgramCatalog Function(SessionScope, SessionScope? Function())?
      catalogFactory;
  final DateTime Function() clock;
  @override
  State<WorkoutProgramRoute> createState() => _WorkoutProgramRouteState();
}

class _WorkoutProgramRouteState extends State<WorkoutProgramRoute> {
  WorkoutProgramController? _controller;
  WorkoutProgramCatalog? _catalog;
  StreamSubscription<AuthState>? _subscription;
  bool _opening = false;
  String? _error;
  bool _authorized(AuthBloc auth) =>
      auth.state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member});
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_opening && _controller == null && _error == null) unawaited(_open());
  }

  Future<void> _open() async {
    _opening = true;
    final auth = context.read<AuthBloc>();
    try {
      if (!_authorized(auth)) throw StateError('Member account unavailable');
      final store = await widget.storeFactory(widget.scope);
      final routines = await widget.routineStoreFactory(widget.scope);
      if (!mounted || !_authorized(auth)) return;
      SessionScope? active() => _authorized(auth) ? widget.scope : null;
      final c = WorkoutProgramController(
          scope: widget.scope,
          activeScope: active,
          store: store,
          routineStore: routines,
          newId: newWorkoutRequestId);
      _controller = c;
      _catalog = widget.catalogFactory?.call(widget.scope, active) ??
          FirebaseWorkoutProgramCatalog(
              scope: widget.scope, activeScope: active);
      _subscription = auth.stream.listen((_) => c.accountChanged());
      await c.open();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Program progress is unavailable. Existing workout history is retained.');
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _routine(ProgramRoutineLaunch launch) async {
    final auth = context.read<AuthBloc>();
    if (!_authorized(auth)) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
                value: auth,
                child: RoutineJourneyRoute(
                    scope: widget.scope,
                    routine: launch.routine,
                    programAttemptId: launch.attemptId,
                    initialDay: launch.routineDay))));
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        if (!_authorized(context.read<AuthBloc>())) {
          return const Scaffold(
              body:
                  Center(child: Text('Sign in to view your workout program.')));
        }
        if (_error != null) {
          return Scaffold(
              appBar: AppBar(title: const Text("Today's Workout")),
              body: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!),
                TextButton(
                    onPressed: () {
                      _controller?.dispose();
                      _controller = null;
                      setState(() => _error = null);
                      _open();
                    },
                    child: const Text('Retry'))
              ])));
        }
        if (_controller == null || _opening) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final malaysia = widget.clock().toUtc().add(const Duration(hours: 8));
        return WorkoutProgramScreen(
            controller: _controller!,
            loadPrograms: _catalog!.load,
            onOpenRoutine: _routine,
            clock: widget.clock,
            today: DateTime.utc(malaysia.year, malaysia.month, malaysia.day));
      });
}
