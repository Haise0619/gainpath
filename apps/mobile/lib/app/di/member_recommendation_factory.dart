import 'dart:async';
import '../../features/recommendation/application/member_recommendation_page_cache.dart';
import '../../features/recommendation/application/published_recommendation_suggestion.dart';
import '../../infrastructure/firebase/firebase_module9_repository.dart';
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
import '../notifications/member_notification_badge.dart';
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
        MemberNotificationBadge? notificationBadge,
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
                      scoped?.catalog ??
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
              module9Repository: inbox ??
                  scoped?.inbox ??
                  FirebaseModule9Repository(
                      scope: session.scope, isCurrent: current),
              announcementReader: announcements,
              notificationBadge: notificationBadge,
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
  Future<void> Function()? _checkProfileCoach;
  MemberRecommendationNavigator? _navigator;
  Future<List<PublishedRecommendationSuggestion>>? _discovery;
  DateTime? _discoveryLoadedAt;
  late MemberRecommendationPageCache _cache;
  Stream<void>? _updates;
  StreamController<void>? _signals;
  StreamSubscription<void>? _signalSource;

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
    } else if (widget.visible && !oldWidget.visible) {
      unawaited(_checkProfileCoach?.call());
    }
  }

  void _configure() {
    _discovery = null;
    _discoveryLoadedAt = null;
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
    _cache = MemberRecommendationPageCache(
        canonical?.loadPage ?? demo!.loadRecommendations, current);
    _load = _cache.load;
    _signalSource?.cancel();
    _signals?.close();
    final signals = StreamController<void>.broadcast();
    StreamSubscription<void>? source;
    signals.onListen = () {
      source =
          FirebaseModule9Repository(scope: session.scope, isCurrent: current)
              .watchInbox()
              .listen(signals.add, onError: signals.addError);
      _signalSource = source;
    };
    signals.onCancel = () {
      source?.cancel();
      source = null;
    };
    _signals = signals;
    _updates = _repository.enabled ? signals.stream : null;
    var checkingProfile = false;
    _checkProfileCoach = () async {
      if (checkingProfile || !current() || !_repository.enabled) return;
      checkingProfile = true;
      try {
        final query = <String, Object?>{
          'schemaVersion': 1,
          'organizationId': session.organizationId,
        };
        final result = canonical != null
            ? await canonical.call('member.profile.recommend', query)
            : await (widget.datasetTransport ??
                    firebaseFypDatasetTransport(session.scope, current))
                .call('member.profile.recommend', query);
        if (current() &&
            !signals.isClosed &&
            result is Map &&
            result['delivered'] == 1) {
          _cache.invalidate();
          signals.add(null);
        }
      } catch (_) {
        // The feed remains usable when the member has not enabled personalization.
      } finally {
        checkingProfile = false;
      }
    };
    if (widget.visible) unawaited(_checkProfileCoach?.call());
    _navigator = null;
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
        loadPublishedCovers: (ids) async {
          final query = <String, Object?>{
            'schemaVersion': 1,
            'organizationId': session.organizationId,
            'routineIds': ids,
          };
          final response = canonical != null
              ? await canonical.call('member.routine.covers', query)
              : await (widget.datasetTransport ??
                      firebaseFypDatasetTransport(session.scope, current))
                  .call('member.routine.covers', query);
          if (!current() || response is! Map) return {};
          return {
            for (final id in ids)
              if (response[id] is String) id: response[id] as String
          };
        },
        bookingNavigationEnabled: true);
  }

  Future<Map<String, String>> _loadRoutineCovers(List<String> ids) async =>
      await _navigator?.loadPublishedCovers?.call(ids) ?? {};

  Future<List<PublishedRecommendationSuggestion>> _loadDiscovery() async {
    final navigator = _navigator;
    if (navigator == null || !widget.isCurrent()) return [];
    if (_discovery != null &&
        _discoveryLoadedAt != null &&
        DateTime.now().difference(_discoveryLoadedAt!) <
            const Duration(seconds: 20)) {
      return _discovery!;
    }
    final request = navigator.loadDiscovery();
    _discovery = request;
    _discoveryLoadedAt = DateTime.now();
    try {
      final items = await request;
      _discoveryLoadedAt = DateTime.now();
      return items;
    } catch (_) {
      if (identical(_discovery, request)) _discovery = null;
      rethrow;
    }
  }

  @override
  void dispose() {
    _signalSource?.cancel();
    _signals?.close();
    _cache.invalidate();
    super.dispose();
  }

  Future<void> _settings() async {
    await openRecommendationPrivacyPreview(context, widget.isCurrent);
    if (!mounted) return;
    _cache.invalidate();
    _signals?.add(null);
    unawaited(_checkProfileCoach?.call());
  }

  void _openAll() {
    unawaited(_checkProfileCoach?.call());
    Navigator.push<void>(
        context,
        MaterialPageRoute(
            builder: (_) => Scaffold(
                appBar: AppBar(
                  title: const Text('Recommended for You'),
                  actions: [
                    IconButton(
                      tooltip: 'Personalization settings',
                      onPressed: _settings,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ],
                ),
                body: SafeArea(
                    child: MemberRecommendationsView(
                        pageScrollable: true,
                        repository: _repository,
                        loadPage: _load,
                        loadDiscovery: _loadDiscovery,
                        loadRoutineCovers: _loadRoutineCovers,
                        onOpenDiscovery: _navigator?.openDiscovery,
                        updates: _updates,
                        onInvalidate: _cache.invalidate,
                        isCurrent: widget.isCurrent,
                        onOpenTarget: (context, detail) async {
                          final navigator = _navigator;
                          if (navigator == null) {
                            throw StateError('Recommendations unavailable.');
                          }
                          await navigator.open(context, detail);
                        },
                        photoBuilder: _navigator?.buildCoachPhoto)))));
  }

  @override
  Widget build(BuildContext context) => MemberRecommendationsView(
      repository: _repository,
      loadPage: _load,
      loadDiscovery: _loadDiscovery,
      loadRoutineCovers: _loadRoutineCovers,
      onOpenDiscovery: _navigator?.openDiscovery,
      updates: _updates,
      onInvalidate: _cache.invalidate,
      isCurrent: widget.isCurrent,
      onOpenTarget: (context, detail) async {
        final navigator = _navigator;
        if (navigator == null) {
          throw StateError('Recommendations unavailable.');
        }
        await navigator.open(context, detail);
      },
      photoBuilder: _navigator?.buildCoachPhoto,
      onViewAll: _openAll,
      compact: widget.compact,
      visible: widget.visible);
}
