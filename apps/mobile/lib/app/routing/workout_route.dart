import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_pose/gainpath_pose.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../../features/workout/presentation/workout_screen.dart';
import '../di/workout_store_factory.dart';

/// Platform storage and detector selection belong to composition, not screens.
/// Upload deliberately remains pending until a real authenticated adapter exists.
class WorkoutRoute extends StatefulWidget {
  const WorkoutRoute({super.key, this.storeFactory = createWorkoutStore});
  final Future<WorkoutSessionStore> Function(SessionScope) storeFactory;
  @override
  State<WorkoutRoute> createState() => _WorkoutRouteState();
}

class _WorkoutRouteState extends State<WorkoutRoute> {
  Future<WorkoutSessionRepository>? _loading;
  WorkoutSessionRepository? _repository;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthBloc>();
    if (_loading == null &&
        AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})) {
      final scope = auth.state.session!.scope;
      _loading = widget.storeFactory(scope).then((store) {
        if (!mounted || auth.state.session?.scope != scope) {
          throw StateError('Workout account is no longer active.');
        }
        return _repository = WorkoutSessionRepository(
          scope: scope,
          store: store,
          uploadGateway: UnavailableWorkoutUploadGateway(),
          activeScope: () => auth.state.session?.scope,
        );
      });
    }
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
        builder: (context, auth) {
          if (!AuthRolePolicy.canEnter(auth, allowed: const {AppRole.member})) {
            return const Scaffold(
                body: Center(
                    child: Text('Sign in as a member to start a workout.')));
          }
          return FutureBuilder<WorkoutSessionRepository>(
            future: _loading,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Scaffold(
                    appBar: AppBar(title: const Text('Workout unavailable')),
                    body: Center(child: Text('${snapshot.error}')));
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              return MobileWorkoutScreen(
                  repository: snapshot.data!,
                  detector: SimulatedPoseDetector(),
                  simulated: true);
            },
          );
        },
      );
}
