import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import '../../infrastructure/firebase/firebase_coach_profile_repository.dart';
import '../../infrastructure/firebase/firebase_coach_directory_repository.dart';
import '../../infrastructure/firebase/firebase_coach_availability_repository.dart';
import '../../features/coaching/presentation/coach/availability_screens.dart';
import '../../features/coaching/presentation/shared/live_coach_schedule_view.dart';
import '../shells/coach_shell.dart';
import '../../features/coaching/presentation/member/browse_coaches_screen.dart';
import '../../features/coaching/presentation/shared/live_coach_directory_views.dart';
import 'coach_module8_dependencies.dart';
import '../../features/coaching/presentation/shared/live_booking_list_view.dart';
import 'booking_factory.dart';
import '../../infrastructure/firebase/firebase_coach_account_repository.dart';
import '../../features/identity/application/coach_account_gateway.dart';

typedef CoachProfileFactory = CoachProfileRepository Function(
    SessionScope, bool Function());
typedef CoachAccountFactory = CoachAccountGateway Function(
    SessionScope, bool Function());
typedef CoachDirectoryFactory = CoachDirectoryRepository Function(
    SessionScope, bool Function());
typedef CoachAvailabilityFactory = CoachAvailabilityRepository Function(
    SessionScope, bool Function());

class CoachSessionHost extends StatefulWidget {
  const CoachSessionHost(
      {super.key, required this.session, required this.builder});
  final AuthSession session;
  final Widget Function(BuildContext, bool Function()) builder;
  @override
  State<CoachSessionHost> createState() => _CoachSessionHostState();
}

class _CoachSessionHostState extends State<CoachSessionHost> {
  AuthBloc? _auth;
  StreamSubscription<AuthState>? _subscription;
  bool _invalidated = false;
  Widget? _child;
  bool _matches(AuthState state) =>
      identical(state.session, widget.session) &&
      AuthRolePolicy.canEnter(state, allowed: {widget.session.role});
  bool _current() {
    if (_auth == null || !_matches(_auth!.state)) _invalidated = true;
    return !_invalidated;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_auth != null) return;
    _auth = context.read<AuthBloc>();
    _subscription = _auth!.stream.listen((state) {
      if (!_matches(state)) {
        _invalidated = true;
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      }
    });
    _child = widget.builder(context, _current);
  }

  @override
  void dispose() {
    _invalidated = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) => _current()
          ? _child!
          : const Scaffold(
              body: Center(
                  child:
                      Text('Coach workflow unavailable for this session.'))));
}

Widget buildFirebaseCoachShell(AuthSession session,
        {CoachProfileFactory? factory,
        CoachAccountFactory? accountFactory,
        CoachAvailabilityFactory? availabilityFactory,
        BookingListFactory? bookingListFactory}) =>
    CoachSessionHost(
        key: ObjectKey(session),
        session: session,
        builder: (context, isCurrent) => CoachShell(
            module8: CoachModule8Dependencies(
                account: accountFactory?.call(session.scope, isCurrent) ??
                    FirebaseCoachAccountRepository(
                        scope: session.scope, isCurrent: isCurrent),
                profile: factory?.call(session.scope, isCurrent) ??
                    FirebaseCoachProfileRepository(
                        scope: session.scope, isCurrent: isCurrent)),
            initialIndex: 3,
            restrictUnsupportedWorkflows: true,
            liveRosterBuilder: (_) => LiveBookingListView(
                title: 'Roster',
                repository:
                    createBookingList(session, isCurrent, bookingListFactory),
                isCurrent: isCurrent),
            liveAvailabilityBuilder: (_) => AvailabilityScreen(liveRepository: availabilityFactory?.call(session.scope, isCurrent) ?? FirebaseCoachAvailabilityRepository(scope: session.scope, isCurrent: isCurrent), coachId: session.userId, isCurrent: isCurrent)));
Widget buildFirebaseCoachDirectory(AuthSession session,
        {CoachDirectoryFactory? factory,
        CoachAvailabilityFactory? availabilityFactory,
        BookingServicesFactory? bookingFactory,
        BookingListFactory? bookingListFactory}) =>
    CoachSessionHost(
        key: ObjectKey(session),
        session: session,
        builder: (context, isCurrent) {
          final repository = factory?.call(session.scope, isCurrent) ??
              FirebaseCoachDirectoryRepository(
                  scope: session.scope, isCurrent: isCurrent);
          return BrowseCoachesScreen(
              live: true,
              liveRepository: repository,
              isCurrent: isCurrent,
              onOpenBookings: () => openBookingList(context, session,
                  factory: bookingListFactory),
              onOpenPublished: (id) => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CoachSessionHost(
                          session: session,
                          builder: (_, current) => LiveCoachDetailView(
                              coachId: id,
                              repository: repository,
                              onOpenBooking: () => openMemberBooking(
                                  context, session, id,
                                  factory: bookingFactory,
                                  listFactory: bookingListFactory),
                              onOpenSchedule: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          CoachSessionHost(session: session, builder: (_, scheduleCurrent) => LiveCoachScheduleView(coachId: id, onOpenBooking: () => openMemberBooking(context, session, id, factory: bookingFactory, listFactory: bookingListFactory), repository: availabilityFactory?.call(session.scope, scheduleCurrent) ?? FirebaseCoachAvailabilityRepository(scope: session.scope, isCurrent: scheduleCurrent), isCurrent: scheduleCurrent)))),
                              isCurrent: () => current() && isCurrent())))));
        });
