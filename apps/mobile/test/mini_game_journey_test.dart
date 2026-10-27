import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_catch_ports.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_game_details_screen.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/media/tutorial_video.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';

class _Reader implements MiniGameContentReader {
  @override
  final scope = SessionScope(userId: 'member-a', organizationId: 'gym-a');
  @override
  bool current = true;
  MiniGameContent content = MiniGameContent.defaults('gym-a');
  @override
  Future<List<MiniGameContent>> load() async => [content];
}

class _BestScores implements MoveCatchBestScoreStore {
  int best = 0;
  bool unavailable = false;
  final loadedScopes = <SessionScope>[];
  Future<int> Function()? pending;
  @override
  Future<int> load(SessionScope scope) async {
    loadedScopes.add(scope);
    if (unavailable) throw StateError('local storage unavailable');
    return pending == null ? best : pending!();
  }

  @override
  Future<int> record(SessionScope scope, int score,
          {required bool Function() isCurrent}) =>
      throw StateError('The catalog and details must never write scores.');
}

class _Auth extends Fake implements AuthBloc {
  final changes = StreamController<AuthState>.broadcast();
  @override
  AuthState state = const AuthState();
  @override
  Stream<AuthState> get stream => changes.stream;
  void changed() {
    state = AuthState(sessionRevision: state.sessionRevision + 1);
    changes.add(state);
  }
}

void main() {
  testWidgets(
      'completed Back to games returns to catalogue and refreshes personal best',
      (tester) async {
    final reader = _Reader(), scores = _BestScores();
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(
            connected: true, reader: reader, bestScoreStore: scores),
        routes: {
          FeatureNavigation.moveAndCatch: (context) => Scaffold(
              body: TextButton(
                  onPressed: () {
                    scores.best = 80;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Back to games')))
        }));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back to games'));
    await tester.pumpAndSettle();
    expect(find.text('Featured challenge'), findsOneWidget);
    expect(find.byType(MiniGameDetailsScreen), findsNothing);
    expect(find.text('Personal best · 80'), findsOneWidget);
  });
  testWidgets('catalog opens details before named camera game', (tester) async {
    String? launched;
    await tester.pumpWidget(MaterialApp(
      home: const MiniGamesScreen(connected: true),
      onGenerateRoute: (settings) {
        launched = settings.name;
        return MaterialPageRoute<void>(
            builder: (_) => const Scaffold(body: Text('Camera game')));
      },
    ));
    await tester.pumpAndSettle();
    expect(find.text('Featured challenge'), findsOneWidget);
    expect(find.text('All challenges'), findsOneWidget);
    expect(find.text('Move & Catch'), findsNWidgets(2));
    expect(find.text('How to play'), findsNothing);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    expect(launched, isNull);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('Game rewards · Not active'), findsOneWidget);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(launched, FeatureNavigation.moveAndCatch);
    expect(find.text('Camera game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('grid card opens the same details journey', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: MiniGamesScreen(connected: true)));
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const Key('move-catch-challenge-card')));
    await tester.tap(find.byKey(const Key('move-catch-challenge-card')));
    await tester.pumpAndSettle();
    expect(find.byType(MiniGameDetailsScreen), findsOneWidget);
    expect(find.text('How to play'), findsOneWidget);
    expect(find.text('+10 per star'), findsOneWidget);
    expect(
        find.textContaining(
            'Obstacles subtract 5; your score never goes below 0.'),
        findsOneWidget);
  });

  testWidgets('details displays the scoped reward status supplied by its host',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: MiniGamesScreen(
            connected: true, rewardStatus: Text('Confirmed reward status'))));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed reward status'), findsNothing);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    expect(find.text('Confirmed reward status'), findsOneWidget);
    expect(find.text('Game rewards · Not active'), findsNothing);
    expect(find.text('+10 per star'), findsOneWidget);
  });

  testWidgets('real local zero differs from missing scope and storage failure',
      (tester) async {
    final reader = _Reader(), scores = _BestScores();
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(connected: true, bestScoreStore: scores)));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · Unavailable'), findsOneWidget);
    expect(scores.loadedScopes, isEmpty);
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(
            connected: true, reader: reader, bestScoreStore: scores)));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · 0'), findsOneWidget);
    expect(scores.loadedScopes.single.userId, 'member-a');
    expect(scores.loadedScopes.single.organizationId, 'gym-a');
    scores.unavailable = true;
    await tester.tap(find.byTooltip('Refresh game guide'));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · Unavailable'), findsOneWidget);
    expect(find.text('Personal best · 0'), findsNothing);
  });

  testWidgets('completed return reloads scoped best on the catalog',
      (tester) async {
    final reader = _Reader(), scores = _BestScores()..best = 20;
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(
            connected: true, reader: reader, bestScoreStore: scores),
        routes: {
          FeatureNavigation.moveAndCatch: (context) => Scaffold(
              body: TextButton(
                  onPressed: () {
                    scores.best = 80;
                    Navigator.pop(context, true);
                  },
                  child: const Text('Finish round')))
        }));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · 20'), findsOneWidget);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · 20'), findsOneWidget);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finish round'));
    await tester.pumpAndSettle();
    expect(find.text('Personal best · 80'), findsOneWidget);
    expect(find.byType(MiniGameDetailsScreen), findsNothing);
    expect(find.text('Personal best · 80'), findsOneWidget);
    expect(scores.loadedScopes, hasLength(3));
    expect(
        scores.loadedScopes.every(
            (s) => s.userId == 'member-a' && s.organizationId == 'gym-a'),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending score cannot publish after session invalidation',
      (tester) async {
    final pending = Completer<int>();
    final reader = _Reader(),
        scores = _BestScores()..pending = () => pending.future;
    final auth = _Auth();
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(
            home: MiniGamesScreen(
                connected: true, reader: reader, bestScoreStore: scores))));
    await tester.pump();
    reader.current = false;
    auth.changed();
    pending.complete(990);
    await tester.pumpAndSettle();
    expect(find.text('This game guide session has ended.'), findsOneWidget);
    expect(find.text('Personal best · 990'), findsNothing);
    expect(find.text('Move & Catch'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });

  testWidgets('invalid session cannot load a local best', (tester) async {
    final reader = _Reader()..current = false;
    final scores = _BestScores();
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(
            connected: true, reader: reader, bestScoreStore: scores)));
    await tester.pumpAndSettle();
    expect(scores.loadedScopes, isEmpty);
    expect(find.text('This game guide session has ended.'), findsOneWidget);
  });

  testWidgets('managed cover fills cards and is contained in details',
      (tester) async {
    final reader = _Reader();
    reader.content = MiniGameContent(
        organizationId: 'gym-a',
        revision: 3,
        title: 'Gym challenge',
        introduction: 'Our movement guide.',
        instructions: ['Stand comfortably.', 'Lean gently.'],
        coverUrl: 'https://firebasestorage.googleapis.com/managed-cover',
        previewVideoUrl:
            'https://firebasestorage.googleapis.com/managed-preview');
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Gym challenge'), findsNWidgets(2));
    expect(find.text('Our movement guide.'), findsOneWidget);
    expect(find.byType(TutorialVideo), findsNothing);
    final covers = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(covers, hasLength(2));
    expect(covers.every((image) => image.fit == BoxFit.cover), isTrue);
    expect((covers.first.image as NetworkImage).url, reader.content.coverUrl);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    final cover = tester.widget<Image>(find.byType(Image));
    expect(cover.fit, BoxFit.contain);
    expect(find.text('1. Stand comfortably.'), findsOneWidget);
    expect(find.text('2. Lean gently.'), findsOneWidget);
    expect(find.byType(TutorialVideo), findsNothing);
    expect(find.text('Watch preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('preview keeps camera start disabled through route disposal',
      (tester) async {
    final reader = _Reader();
    reader.content = reader.content.copyWith(
        previewVideoUrl: 'https://firebasestorage.googleapis.com/preview');
    await tester.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(content: reader.content, reader: reader)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Watch preview'));
    await tester.tap(find.text('Watch preview'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialVideo), findsOneWidget);
    final start = find.ancestor(
        of: find.text('Start playing', skipOffstage: false),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton,
            skipOffstage: false));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(tester.widget<FilledButton>(start).onPressed, isNull);
    await tester.pumpAndSettle();
    expect(find.byType(TutorialVideo), findsNothing);
    expect(tester.widget<FilledButton>(start).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning after session loss never reloads scores or guide',
      (tester) async {
    final reader = _Reader(), scores = _BestScores()..best = 10;
    await tester.pumpWidget(MaterialApp(
        home: MiniGameDetailsScreen(
            content: reader.content, reader: reader, bestScoreStore: scores),
        routes: {
          FeatureNavigation.moveAndCatch: (context) => Scaffold(
              body: TextButton(
                  onPressed: () {
                    reader.current = false;
                    scores.best = 90;
                    Navigator.pop(context, true);
                  },
                  child: const Text('End session')))
        }));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End session'));
    await tester.pumpAndSettle();
    expect(find.text('This game guide session has ended.'), findsOneWidget);
    expect(find.text('Personal best · 90'), findsNothing);
    expect(find.text('Start playing'), findsNothing);
    expect(scores.loadedScopes, hasLength(1));
  });

  for (final width in [320.0, 375.0]) {
    testWidgets('catalog and long details fit ${width}px at double text',
        (tester) async {
      tester.view.physicalSize = Size(width, 667);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final reader = _Reader();
      reader.content = reader.content.copyWith(
          title: 'Move & Catch with your gym community',
          introduction:
              'A comfortable movement challenge. Lean gently left and right to catch stars at your own pace.',
          instructions: [
            'Find a clear, comfortable space and face the camera with your shoulders and hips visible.',
            'Keep movement gentle. Hold your position for calibration before you start.'
          ]);
      await tester.pumpWidget(MaterialApp(
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 667),
                  textScaler: const TextScaler.linear(2)),
              child: child!),
          home: MiniGamesScreen(connected: true, reader: reader)));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.byKey(const Key('move-catch-challenge-card')));
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('move-catch-challenge-card')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start playing'));
      expect(
          find.textContaining('Clear the floor around you.'), findsOneWidget);
      expect(find.textContaining('Camera and movement stay on this device.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
