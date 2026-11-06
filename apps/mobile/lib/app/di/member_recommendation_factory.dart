import 'package:gainpath_data/gainpath_data.dart' show ScopedCommandTransport;
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../../infrastructure/firebase/firebase_demo_recommendation.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_domain/gainpath_domain.dart'
    show AuthSession, SessionScope;
import 'package:gainpath_domain/identity.dart';
import '../../features/recommendation/application/member_recommendation_repository.dart';
import '../../features/workout/domain/published_routine_catalog_repository.dart';
import '../../infrastructure/firebase/firebase_coach_directory_repository.dart';
import '../../infrastructure/firebase/firebase_published_routine_repository.dart';
import '../../navigation/session_host.dart';
import '../notifications/member_notifications_screen.dart';
import '../notifications/member_recommendation_navigator.dart';
import 'booking_factory.dart';
import 'coach_profile_factory.dart';

typedef MemberRecommendationFactory = MemberRecommendationRepository Function(
    SessionScope scope, bool Function() isCurrent);

/// An explicit local integration seam. Default production recommendation transport
/// stays unavailable until a reviewed backend is registered and released.
Widget buildMemberRecommendationNotifications(AuthSession session,
        {ScopedCommandTransport? datasetTransport,
        Module9Repository? inbox,
        AnnouncementReader? announcements,
        MemberRecommendationFactory? recommendationFactory,
        CoachDirectoryRepository? coachDirectory,
        PublishedRoutineCatalogRepository? catalog,
        BookingServicesFactory? bookingFactory,
        BookingListFactory? bookingListFactory,
        CoachAvailabilityFactory? availabilityFactory}) =>
    CoachSessionHost(
        session: session,
        builder: (context, current) {
          final scoped = session.datasetScope == null
              ? null
              : FirebaseDemoMemberRepositories(datasetTransport ??
                  firebaseFypDatasetTransport(session.scope, current));
          final repository =
              recommendationFactory?.call(session.scope, current) ??
                  (session.datasetScope == null
                      ? UnavailableMemberRecommendationRepository(session.scope)
                      : scoped!.recommendation);
          final navigator = repository.enabled
              ? MemberRecommendationNavigator(
                  session: session,
                  repository: repository,
                  isCurrent: current,
                  coachDirectory: coachDirectory ??
                      FirebaseCoachDirectoryRepository(
                          scope: session.scope, isCurrent: current),
                  catalog: catalog ??
                      FirebasePublishedRoutineRepository(
                          scope: session.scope,
                          activeScope: () => current() ? session.scope : null),
                  bookingFactory: bookingFactory,
                  bookingListFactory: bookingListFactory,
                  availabilityFactory: availabilityFactory)
              : null;
          return MemberNotificationsScreen(
              session: session,
              isCurrent: current,
              module9Repository: inbox ?? scoped?.inbox,
              announcementReader: announcements,
              recommendationRepository: repository,
              onOpenRecommendationTarget: navigator?.open,
              recommendationPhotoBuilder: navigator?.buildCoachPhoto,
              onOpenBookings: () => openBookingList(context, session,
                  factory: bookingListFactory),
              onBrowseCoaches: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                      builder: (_) => buildFirebaseCoachDirectory(session,
                          factory: coachDirectory == null
                              ? null
                              : (_, __) => coachDirectory,
                          bookingFactory: bookingFactory,
                          bookingListFactory: bookingListFactory,
                          availabilityFactory: availabilityFactory))));
        });
