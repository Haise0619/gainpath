import 'package:gainpath_domain/coaching.dart' show BookingPaymentRepository;
import '../../infrastructure/firebase/firebase_booking_payment_repository.dart';
import '../../features/coaching/presentation/member/booking_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_data/gainpath_data.dart' show RemoteBookingRepository;
import 'package:gainpath_domain/gainpath_domain.dart';
import '../../infrastructure/firebase/firebase_booking_repository.dart';
import '../../features/coaching/presentation/member/live_member_booking_view.dart';
import '../../features/coaching/presentation/shared/live_booking_list_view.dart';
import 'coach_profile_factory.dart';
import '../../infrastructure/firebase/firebase_booking_communication_repository.dart';
import '../../infrastructure/firebase/firebase_coach_directory_repository.dart';

typedef BookingServices = ({
  MemberBookingOptionsRepository options,
  BookingRepository writer
});
typedef BookingServicesFactory = BookingServices Function(
    SessionScope, bool Function());
typedef BookingListFactory = BookingListRepository Function(
    AuthSession, bool Function());

BookingServices _services(SessionScope scope, bool Function() current) {
  final source = FirebaseBookingRepository(scope: scope, isCurrent: current);
  return (options: source, writer: RemoteBookingRepository(source));
}

BookingListRepository createBookingList(AuthSession session,
        bool Function() current, BookingListFactory? factory) =>
    factory?.call(session, current) ??
    FirebaseBookingListRepository(
        scope: session.scope,
        role: session.role,
        branchIds: session.branchIds,
        isCurrent: current);

void openBookingList(BuildContext context, AuthSession session,
    {BookingListFactory? factory}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CoachSessionHost(
              session: session,
              builder: (_, current) => LiveBookingListView(
                  onPayment: session.role != AppRole.member
                      ? null
                      : (id) => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => BookingPaymentScreen(
                                  repository: FirebaseBookingPaymentRepository(
                                      scope: session.scope, isCurrent: current),
                                  bookingId: id,
                                  isCurrent: current))),
                  loadCoachName: (id) async =>
                      (await FirebaseCoachDirectoryRepository(
                                  scope: session.scope, isCurrent: current)
                              .loadPublished(id))
                          ?.fields
                          .displayName,
                  communication: FirebaseBookingCommunicationRepository(scope: session.scope, isCurrent: current),
                  repository: createBookingList(session, current, factory),
                  coachId: session.role == AppRole.coach ? session.userId : null,
                  cancellation: session.role == AppRole.member ? FirebaseBookingRepository(scope: session.scope, isCurrent: current) : null,
                  isCurrent: current))));
}

void openMemberBooking(
    BuildContext context, AuthSession session, String coachId,
    {BookingServicesFactory? factory,
    BookingListFactory? listFactory,
    BookingPaymentRepository? payments}) {
  Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => CoachSessionHost(
              session: session,
              builder: (routeContext, current) {
                final services = (factory ?? _services)(session.scope, current);
                return LiveMemberBookingView(
                    payments: payments ??
                        (factory == null
                            ? FirebaseBookingPaymentRepository(
                                scope: session.scope, isCurrent: current)
                            : null),
                    options: services.options,
                    writer: services.writer,
                    coachId: coachId,
                    isCurrent: current,
                    onOpenBookings: () => openBookingList(routeContext, session,
                        factory: listFactory));
              })));
}
