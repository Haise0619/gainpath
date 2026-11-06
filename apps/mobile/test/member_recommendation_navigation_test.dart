import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/coaching.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/notifications/member_recommendation_navigator.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/features/coaching/presentation/shared/live_coach_directory_views.dart';
import 'package:gainpath_mobile/features/coaching/presentation/member/live_member_booking_view.dart';
import 'package:gainpath_mobile/features/recommendation/application/member_recommendation_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_catalog_repository.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/tutorial_player.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_exercise_tutorial_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'member_recommendation_repository_test.dart' show memberDetail;

const routeMember = AuthSession(
    userId: 'm1',
    organizationId: 'gym1',
    email: 'member@example.invalid',
    role: AppRole.member,
    branchIds: ['main']);

class RecommendationTestAuth extends InMemoryAuthRepository {
  RecommendationTestAuth(this.current);
  AuthSession? current;
  final changes = StreamController<AuthSession?>.broadcast();
  @override
  Future<AuthSession?> restoreSession() async => current;
  @override
  Stream<AuthSession?> get sessionChanges => changes.stream;
  void drift(AuthSession? session) {
    current = session;
    changes.add(session);
  }

  @override
  Future<void> dispose() async {
    await changes.close();
    await super.dispose();
  }
}

class RecommendationDirectory implements CoachDirectoryRepository {
  RecommendationDirectory(this.scope);
  @override
  final SessionScope scope;
  int loads = 0;
  PublishedCoachProfile? profile = PublishedCoachProfile(
      id: 'c1',
      fields: CoachProfessionalFields(
          displayName: 'Current verified Coach',
          specialty: 'Strength',
          bio: 'Current published biography.',
          specializationTags: ['Strength'],
          yearsExperience: 3),
      revision: 2,
      sourceRevision: 2,
      status: 'published',
      branchIds: ['main'],
      createdAtMillis: 1,
      updatedAtMillis: 2,
      publishedAtMillis: 2,
      certificationVerified: true,
      approvedCertificationCount: 1);
  @override
  Future<PublishedCoachProfile?> loadPublished(String id) async {
    loads++;
    return profile?.id == id ? profile : null;
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPage(
          {String? afterId}) async =>
      CoachDirectoryPage(profile == null ? [] : [profile!]);
}

class RecommendationCatalog implements PublishedRoutineCatalogRepository {
  RecommendationCatalog(this.scope);
  @override
  final SessionScope scope;
  int loads = 0;
  PublishedRoutine? routine = const PublishedRoutine(
      id: 'routine1',
      sourceBlueprintId: 'bp1',
      title: 'Current authored Routine',
      estimatedMinutes: 10,
      exercises: [
        PublishedRoutineExercise(
            exerciseId: 'squat',
            dayNumber: 1,
            name: 'Current Squat Tutorial',
            category: 'Strength',
            sets: 3,
            reps: 8,
            cue: 'Keep control',
            imageUrl: '',
            muscleGroup: 'Legs',
            tutorial: ExerciseTutorialDetails(
                description: 'Current authored instructions.',
                steps: [
                  ExerciseTutorialStep(
                      title: 'Start position',
                      description: 'Stand with feet comfortably apart.')
                ]))
      ]);
  @override
  Future<PublishedRoutine?> loadById(String id) async {
    loads++;
    return routine?.id == id ? routine : null;
  }

  @override
  Future<PublishedRoutinePage> loadPage({String? afterId}) async =>
      PublishedRoutinePage(routine == null ? [] : [routine!]);
}

Map<String, Object?> contentDetail() => {
      ...memberDetail(),
      'kind': 'content',
      'targetLabel': 'Current Squat Tutorial',
      'target': {
        'kind': 'content',
        'destination': {
          'kind': 'published_routine_exercise_tutorial',
          'organizationId': 'gym1',
          'routineId': 'routine1',
          'exerciseIndex': 0,
          'exerciseId': 'squat',
          'dayNumber': 1
        }
      }
    };

class RecommendationVideoPlayer extends TutorialPlayer {
  @override
  bool get ready => true;
  @override
  bool get playing => false;
  @override
  bool get buffering => false;
  @override
  String? get error => null;
  @override
  Duration get duration => const Duration(seconds: 30);
  @override
  Duration get position => Duration.zero;
  @override
  double get aspectRatio => 16 / 9;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration value) async {}
  @override
  Widget buildVideo() => const ColoredBox(color: Colors.black);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  for (final content in [false, true]) {
    testWidgets(
        'fresh ${content ? 'Tutorial' : 'Coach'} resolve opens actual existing widget without booking',
        (tester) async {
      final source = RecommendationTestAuth(routeMember);
      final auth = AuthBloc(repository: source);
      await tester.pump();
      addTearDown(auth.close);
      addTearDown(source.dispose);
      var resolves = 0, bookingCreations = 0;
      final repo = RpcMemberRecommendationRepository(
          scope: routeMember.scope,
          isCurrent: () => identical(auth.state.session, routeMember),
          invoke: (request) async {
            if (request['action'] == 'resolve') resolves++;
            return content ? contentDetail() : memberDetail();
          });
      final directory = RecommendationDirectory(routeMember.scope),
          catalog = RecommendationCatalog(routeMember.scope);
      final navigator = MemberRecommendationNavigator(
          session: routeMember,
          repository: repo,
          isCurrent: () => identical(auth.state.session, routeMember),
          coachDirectory: directory,
          catalog: catalog,
          bookingFactory: (_, __) {
            bookingCreations++;
            throw StateError('Only created after user selects booking');
          });
      final detail = MemberRecommendationDetail.parse(
          content ? contentDetail() : memberDetail(), 'gym1', 'r1');
      await tester.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              home: Builder(
                  builder: (context) => Scaffold(
                      body: TextButton(
                          onPressed: () => navigator.open(context, detail),
                          child: const Text('Open current target')))))));
      await tester.tap(find.text('Open current target'));
      await tester.pumpAndSettle();
      expect(resolves, 1);
      expect(bookingCreations, 0);
      expect(find.byType(LiveMemberBookingView), findsNothing);
      if (content) {
        expect(find.byType(ExerciseTutorialRoute), findsOneWidget);
        expect(find.byType(PublishedExerciseTutorialScreen), findsOneWidget);
        final route = tester
            .widget<ExerciseTutorialRoute>(find.byType(ExerciseTutorialRoute));
        expect(
            identical(route.exercise, catalog.routine!.exercises.first), true);
      } else {
        expect(find.byType(LiveCoachDetailView), findsOneWidget);
        expect(find.text('Current verified Coach'), findsWidgets);
        expect(directory.loads, greaterThanOrEqualTo(2));
      }
      source.drift(null);
      await tester.pumpAndSettle();
      expect(find.text('Current verified Coach'), findsNothing);
      if (content) {
        expect(find.text('Current Squat Tutorial'), findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  test(
      'published tutorial resolver refuses changed index/id/day and missing authored instructions',
      () async {
    final directory = RecommendationDirectory(routeMember.scope),
        catalog = RecommendationCatalog(routeMember.scope);
    final repo = RpcMemberRecommendationRepository(
        scope: routeMember.scope,
        isCurrent: () => true,
        invoke: (_) async => contentDetail());
    final navigator = MemberRecommendationNavigator(
        session: routeMember,
        repository: repo,
        isCurrent: () => true,
        coachDirectory: directory,
        catalog: catalog);
    for (final target in [
      const ContentRecommendationTarget('other', 'routine1', 0, 'squat', 1),
      const ContentRecommendationTarget('gym1', 'routine1', 1, 'squat', 1),
      const ContentRecommendationTarget('gym1', 'routine1', 0, 'changed', 1),
      const ContentRecommendationTarget('gym1', 'routine1', 0, 'squat', 2)
    ]) {
      await expectLater(navigator.resolveExercise(target),
          throwsA(isA<MemberRecommendationUnavailable>()));
    }
    catalog.routine = null;
    await expectLater(
        navigator.resolveExercise(const ContentRecommendationTarget(
            'gym1', 'routine1', 0, 'squat', 1)),
        throwsA(isA<MemberRecommendationUnavailable>()));
  });
  testWidgets(
      'a current video-only publication opens the existing actual tutorial route',
      (tester) async {
    final source = RecommendationTestAuth(routeMember);
    final auth = AuthBloc(repository: source);
    await tester.pump();
    addTearDown(auth.close);
    addTearDown(source.dispose);
    final directory = RecommendationDirectory(routeMember.scope),
        catalog = RecommendationCatalog(routeMember.scope);
    catalog.routine = const PublishedRoutine(
        id: 'routine1',
        sourceBlueprintId: 'bp1',
        title: 'Current video Routine',
        estimatedMinutes: 10,
        exercises: [
          PublishedRoutineExercise(
              exerciseId: 'squat',
              dayNumber: 1,
              name: 'Current video tutorial',
              category: 'Strength',
              sets: 3,
              reps: 8,
              cue: '',
              imageUrl: '',
              muscleGroup: 'Legs',
              videoUrl: 'https://media.example.invalid/current.mp4')
        ]);
    final repo = RpcMemberRecommendationRepository(
        scope: routeMember.scope,
        isCurrent: () => identical(auth.state.session, routeMember),
        invoke: (_) async => contentDetail());
    final navigator = MemberRecommendationNavigator(
        session: routeMember,
        repository: repo,
        isCurrent: () => identical(auth.state.session, routeMember),
        coachDirectory: directory,
        catalog: catalog,
        tutorialPlayerFactory: (_) => RecommendationVideoPlayer());
    final detail =
        MemberRecommendationDetail.parse(contentDetail(), 'gym1', 'r1');
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                    body: TextButton(
                        onPressed: () => navigator.open(context, detail),
                        child: const Text('Open current video')))))));
    await tester.tap(find.text('Open current video'));
    await tester.pumpAndSettle();
    expect(find.byType(ExerciseTutorialRoute), findsOneWidget);
    expect(find.byType(PublishedExerciseTutorialScreen), findsOneWidget);
    final row = tester
        .widget<ExerciseTutorialRoute>(find.byType(ExerciseTutorialRoute))
        .exercise;
    expect(identical(row, catalog.routine!.exercises.first), true);
    expect(row.tutorial.steps, isEmpty);
    expect(row.videoUrl, 'https://media.example.invalid/current.mp4');
    await tester.pumpWidget(const SizedBox());
  });
  for (final matching in [true, false]) {
    testWidgets(
        'protected Coach photo requires exact current published path matching=$matching',
        (tester) async {
      final directory = RecommendationDirectory(routeMember.scope),
          catalog = RecommendationCatalog(routeMember.scope);
      directory.profile = PublishedCoachProfile(
          id: 'c1',
          fields: CoachProfessionalFields(
              displayName: 'Current verified Coach',
              specialty: 'Strength',
              bio: 'Current biography.',
              specializationTags: ['Strength'],
              yearsExperience: 3,
              photoPath:
                  'orgs/gym1/coachProfilePhotos/c1/${matching ? 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' : 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'}'),
          revision: 2,
          sourceRevision: 2,
          status: 'published',
          branchIds: ['main'],
          createdAtMillis: 1,
          updatedAtMillis: 2,
          publishedAtMillis: 2,
          certificationVerified: true,
          approvedCertificationCount: 1);
      final repo = RpcMemberRecommendationRepository(
          scope: routeMember.scope,
          isCurrent: () => true,
          invoke: (_) async => memberDetail());
      final navigator = MemberRecommendationNavigator(
          session: routeMember,
          repository: repo,
          isCurrent: () => true,
          coachDirectory: directory,
          catalog: catalog);
      final detail = MemberRecommendationDetail.parse({
        ...memberDetail(),
        'photoPath':
            'orgs/gym1/coachProfilePhotos/c1/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      }, 'gym1', 'r1');
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) =>
                  Scaffold(body: navigator.buildCoachPhoto(context, detail)))));
      await tester.pumpAndSettle();
      expect(directory.loads, 1);
      expect(find.byType(PublishedCoachPhoto),
          matching ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final viewport in [const Size(393, 851), const Size(375, 812)]) {
    for (final textScale in [1.0, 2.0]) {
      testWidgets(
          'current Coach profile wraps long branch at ${viewport.width}px text$textScale',
          (tester) async {
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final directory = RecommendationDirectory(routeMember.scope);
        directory.profile = PublishedCoachProfile(
            id: 'c1',
            fields: CoachProfessionalFields(
                displayName: 'Fictional Coach Amira',
                specialty: 'Squat foundations',
                bio: 'Fictional reviewed educational profile.',
                specializationTags: ['Squat foundations'],
                yearsExperience: null),
            revision: 2,
            sourceRevision: 1,
            status: 'published',
            branchIds: ['fictional-branch'],
            createdAtMillis: 1,
            updatedAtMillis: 2,
            publishedAtMillis: 2,
            certificationVerified: true,
            approvedCertificationCount: 1);
        var bookings = 0;
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
                child: LiveCoachDetailView(
                    coachId: 'c1',
                    repository: directory,
                    isCurrent: () => true,
                    onOpenBooking: () => bookings++))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Book a session'), 300,
            scrollable: find.byType(Scrollable).first, maxScrolls: 50);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Book a session'));
        expect(bookings, 1);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
