import 'package:gainpath_data/gainpath_data.dart' show ScopedCommandTransport;
import '../../infrastructure/firebase/firebase_fyp_dataset.dart';
import '../../infrastructure/firebase/firebase_member_recommendations.dart';
import '../../features/recommendation/presentation/member/member_recommendations_view.dart';
import '../../navigation/recommendation_privacy_navigation.dart';
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
                      ? FirebaseMemberRecommendations(
                              scope: session.scope, isCurrent: current)
                          .recommendation
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

/// Account-scoped composition shared by Home and Recommendations history.
class MemberRecommendationHost extends StatefulWidget {
  const MemberRecommendationHost(
      {super.key,
      required this.session,
      required this.isCurrent,
      this.datasetTransport,
      this.compact = false,
      this.visible = true,
      this.coachDirectory,
      this.catalog,
      this.bookingFactory,
      this.bookingListFactory,
      this.availabilityFactory});
  final AuthSession session;
  final bool Function() isCurrent;
  final ScopedCommandTransport? datasetTransport;
  final bool compact, visible;
  final CoachDirectoryRepository? coachDirectory;
  final PublishedRoutineCatalogRepository? catalog;
  final BookingServicesFactory? bookingFactory;
  final BookingListFactory? bookingListFactory;
  final CoachAvailabilityFactory? availabilityFactory;
  @override
  State<MemberRecommendationHost> createState() => _RecommendationHostState();
}

class _RecommendationHostState extends State<MemberRecommendationHost> {
  late MemberRecommendationRepository _repository;
  late MemberRecommendationPageLoader _load;
  MemberRecommendationNavigator? _navigator;

  @override
  void initState() {
    super.initState();
    _configure();
  }

  @override
  void didUpdateWidget(covariant MemberRecommendationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session ||
        oldWidget.coachDirectory != widget.coachDirectory ||
        oldWidget.catalog != widget.catalog ||
        oldWidget.bookingFactory != widget.bookingFactory ||
        oldWidget.bookingListFactory != widget.bookingListFactory ||
        oldWidget.availabilityFactory != widget.availabilityFactory) {
      _configure();
    }
  }

  void _configure() {
    final session = widget.session;
    bool current() =>
        mounted && widget.session == session && widget.isCurrent();
    final demo = session.datasetScope == null
        ? null
        : FirebaseDemoMemberRepositories(widget.datasetTransport ??
            firebaseFypDatasetTransport(session.scope, current));
    final canonical = demo == null
        ? FirebaseMemberRecommendations(
            scope: session.scope, isCurrent: current)
        : null;
    _repository = demo?.recommendation ?? canonical!.recommendation;
    _load = canonical?.loadPage ??
        ({required bool history, String? afterId}) async {
          final page = await demo!.inbox.loadInbox(afterId: afterId);
          final records = <MemberRecommendationDetail>[];
          for (final notice in page.records) {
            final recommendation = notice.recommendation;
            if (recommendation == null) continue;
            final detail =
                await _repository.get(recommendation.recommendationId);
            if (detail.deliveredAt != null && (history || detail.available)) {
              records.add(detail);
            }
          }
          return MemberRecommendationPage(
              records: records, nextAfterId: page.nextAfterId);
        };
    _navigator = null;
    if (!_repository.enabled) return;
    _navigator = MemberRecommendationNavigator(
        session: session,
        repository: _repository,
        isCurrent: current,
        coachDirectory: widget.coachDirectory ??
            demo?.directory ??
            FirebaseCoachDirectoryRepository(
                scope: session.scope, isCurrent: current),
        catalog: widget.catalog ??
            demo?.catalog ??
            FirebasePublishedRoutineRepository(
                scope: session.scope,
                activeScope: () => current() ? session.scope : null),
        bookingFactory: widget.bookingFactory,
        bookingListFactory: widget.bookingListFactory,
        availabilityFactory: widget.availabilityFactory,
        bookingNavigationEnabled: true);
  }

  void _openAll() {
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Recommendations')),
                body: SafeArea(
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: MemberRecommendationsView(
                            repository: _repository,
                            loadPage: _load,
                            isCurrent: widget.isCurrent,
                            onOpenTarget: (context, detail) async {
                              final navigator = _navigator;
                              if (navigator == null) {
                                throw StateError(
                                    'Recommendations unavailable.');
                              }
                              await navigator.open(context, detail);
                            },
                            photoBuilder: _navigator?.buildCoachPhoto,
                            onSettings: () => openRecommendationPrivacyPreview(
                                context, widget.isCurrent)))))));
  }

  @override
  Widget build(BuildContext context) => MemberRecommendationsView(
      repository: _repository,
      loadPage: _load,
      isCurrent: widget.isCurrent,
      onOpenTarget: (context, detail) async {
        final navigator = _navigator;
        if (navigator == null) {
          throw StateError('Recommendations unavailable.');
        }
        await navigator.open(context, detail);
      },
      photoBuilder: _navigator?.buildCoachPhoto,
      onSettings: () =>
          openRecommendationPrivacyPreview(context, widget.isCurrent),
      onViewAll: _openAll,
      compact: widget.compact,
      visible: widget.visible);
}
