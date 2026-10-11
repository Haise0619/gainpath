import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/workout/data/workout_session_repository.dart';
import '../di/workout_store_factory.dart';
import 'real_squat_route.dart';

class SavedSquatSessionsRoute extends StatefulWidget {
  const SavedSquatSessionsRoute(
      {super.key, required this.scope, this.storeFactory = createWorkoutStore});
  final SessionScope scope;
  final Future<WorkoutSessionStore> Function(SessionScope) storeFactory;
  @override
  State<SavedSquatSessionsRoute> createState() =>
      _SavedSquatSessionsRouteState();
}

class _SavedSquatSessionsRouteState extends State<SavedSquatSessionsRoute> {
  Future<List<WorkoutSessionRecord>>? _loading;
  WorkoutSessionRepository? _repository;
  bool _authorized(AuthState state) =>
      state.session?.scope == widget.scope &&
      AuthRolePolicy.canEnter(state, allowed: const {AppRole.member});
  Future<List<WorkoutSessionRecord>> _load() async {
    final auth = context.read<AuthBloc>();
    final store = await widget.storeFactory(widget.scope);
    if (!mounted || !_authorized(auth.state)) {
      throw StateError('Account changed');
    }
    _repository?.dispose();
    final repository = _repository = WorkoutSessionRepository(
        scope: widget.scope,
        store: store,
        uploadGateway: UnavailableWorkoutUploadGateway(),
        activeScope: () => _authorized(auth.state) ? widget.scope : null);
    final records = await repository.loadHistory();
    return records
        .where((record) =>
            record.summary.poseMetrics != null &&
            record.summary.provenance == WorkoutProvenance.realCamera)
        .toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loading ??= _load();
  }

  @override
  void dispose() {
    _repository?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
        if (!_authorized(state)) {
          return const Scaffold(
              body: Center(
                  child: Text('Sign in to view this account’s results.')));
        }
        return Scaffold(
            appBar: AppBar(title: const Text('Saved squat sessions')),
            body: FutureBuilder<List<WorkoutSessionRecord>>(
                future: _loading,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'Could not read saved results on this device.'),
                      FilledButton(
                          onPressed: () => setState(() => _loading = _load()),
                          child: const Text('Retry'))
                    ]));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Center(
                        child: Text(
                            'No measured squat sessions saved on this device yet.'));
                  }
                  return ListView.separated(
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final summary = snapshot.data![index].summary;
                        return ListTile(
                            title: Text(
                                '${summary.repetitions} full reps · ${summary.partialRepetitions} partial'),
                            subtitle: Text(
                                '${summary.startedAt.toLocal().toString().substring(0, 16)}\nSaved locally · ${summary.formScorePercent == null ? 'form unassessed' : '${summary.formScorePercent!.round()}% estimated form'}'),
                            isThreeLine: true,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final auth = context.read<AuthBloc>();
                              if (!_authorized(auth.state)) return;
                              Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                      builder: (_) => ScopedSquatResult(
                                          summary: summary, auth: auth)));
                            });
                      });
                }));
      });
}
