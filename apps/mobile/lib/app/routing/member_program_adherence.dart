import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AppRole, SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'program_adherence_snapshot.dart';
import '../../features/analytics/presentation/program_adherence_host.dart';
import '../di/program_store_factory.dart';
import '../di/workout_store_factory.dart';

class LiveProgramAdherence extends StatelessWidget {
  const LiveProgramAdherence(
      {super.key,
      required this.scope,
      this.reloadToken,
      this.summaryBuilder,
      this.weeklySummaryBuilder,
      this.onChooseProgram,
      this.onOpenProgram});
  final Widget Function(BuildContext, int?)? summaryBuilder;
  final Widget Function(BuildContext, int?, int?)? weeklySummaryBuilder;
  final VoidCallback? onChooseProgram;
  final void Function(String enrollmentId)? onOpenProgram;
  final SessionScope scope;
  final Object? reloadToken;
  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>();
    final captured = auth.state.session;
    SessionScope? activeScope() => identical(auth.state.session, captured) &&
            captured?.scope == scope &&
            AuthRolePolicy.canEnter(auth.state, allowed: const {AppRole.member})
        ? scope
        : null;
    return BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
      if (activeScope() == null) return const SizedBox.shrink();
      return ProgramAdherenceHost(
          key: ValueKey((scope, reloadToken, captured)),
          scope: scope,
          summaryBuilder: summaryBuilder,
          weeklySummaryBuilder: weeklySummaryBuilder,
          onChooseProgram: onChooseProgram,
          onOpenProgram: onOpenProgram,
          activeScope: activeScope,
          load: () async {
            if (activeScope() == null) throw StateError('Account changed');
            final programStore = await createProgramEnrollmentStore(scope);
            if (activeScope() == null) throw StateError('Account changed');
            final routineStore = await createRoutineJourneyStore(scope);
            return loadProgramAdherence(
                scope: scope,
                activeScope: activeScope,
                programStore: programStore,
                routineStore: routineStore,
                now: DateTime.now());
          });
    });
  }
}
