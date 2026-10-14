import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show AuthSession;
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../features/coaching/presentation/admin/coach_schedule_view.dart';
import 'catalog_edit_session_guard.dart';

class AdminCoachScheduleRoute extends StatefulWidget {
  const AdminCoachScheduleRoute(
      {super.key,
      required this.session,
      required this.repository,
      required this.coachId});
  final AuthSession session;
  final CoachAvailabilityRepository repository;
  final String coachId;
  @override
  State<AdminCoachScheduleRoute> createState() =>
      _AdminCoachScheduleRouteState();
}

class _AdminCoachScheduleRouteState extends State<AdminCoachScheduleRoute> {
  CatalogEditSessionGuard? guard;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (guard != null) return;
    final auth = context.read<AuthBloc>();
    guard = CatalogEditSessionGuard(
        expected: widget.session,
        current: () => auth.state,
        changes: auth.stream);
  }

  @override
  void dispose() {
    guard?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => guard!.isCurrent()
          ? AdminCoachScheduleView(
              repository: widget.repository,
              coachId: widget.coachId,
              isCurrent: guard!.isCurrent)
          : const Scaffold(
              body: Center(
                  child: Text('Schedule unavailable for this session.'))));
}
