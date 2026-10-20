import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/routing/exercise_tutorial_route.dart';
import 'package:gainpath_mobile/app/routing/workout_prep_route.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/domain/tutorial_player.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_exercise_tutorial_screen.dart';
import 'package:google_fonts/google_fonts.dart';

PublishedRoutineExercise row({String? url}) => PublishedRoutineExercise(
    exerciseId: 'exact-id',
    dayNumber: 2,
    name: 'Published exercise',
    category: 'Lower body',
    sets: 2,
    reps: 7,
    cue: '',
    imageUrl: '',
    muscleGroup: '',
    videoUrl: url);

class FakePlayer extends TutorialPlayer {
  final Completer<void>? pending;
  final bool fail;
  FakePlayer({this.pending, this.fail = false});
  bool disposed = false;
  int plays = 0, pauses = 0;
  @override
  bool ready = false;
  @override
  bool playing = false;
  @override
  bool buffering = false;
  @override
  String? error;
  @override
  Duration duration = const Duration(seconds: 60);
  @override
  Duration position = Duration.zero;
  @override
  double get aspectRatio => 16 / 9;
  @override
  Future<void> initialize() async {
    if (pending != null) await pending!.future;
    if (fail) throw StateError('private URL token=secret');
    if (disposed) return;
    ready = true;
    notifyListeners();
  }

  @override
  Future<void> play() async {
    plays++;
    playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    pauses++;
    playing = false;
    notifyListeners();
  }

  @override
  Future<void> seek(Duration value) async {
    position = value;
    notifyListeners();
  }

  @override
  Widget buildVideo() => const Text('Real player surface');
  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }
}

class PendingControlPlayer extends FakePlayer {
  final control = Completer<void>();
  @override
  Future<void> play() async {
    await control.future;
    if (!disposed) await super.play();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
      'pending control times out with retry and ignores late completion',
      (tester) async {
    final player = PendingControlPlayer();
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 21));
    expect(find.text('Retry'), findsOneWidget);
    expect(player.disposed, true);
    player.control.complete();
    await tester.pumpAndSettle();
    expect(player.plays, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'authorization restoration reloads without autoplay or endless loading',
      (tester) async {
    final active = ValueNotifier(true);
    final first = FakePlayer();
    final replacement = FakePlayer();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      authorized: active,
      playerFactory: (_) => calls++ == 0 ? first : replacement,
    )));
    await tester.pumpAndSettle();
    active.value = false;
    await tester.pump();
    active.value = true;
    await tester.pumpAndSettle();
    expect(first.disposed, true);
    expect(find.byTooltip('Play tutorial'), findsOneWidget);
    expect(replacement.plays, 0);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });

  testWidgets('delayed play completing in background is paused again',
      (tester) async {
    final player = PendingControlPlayer();
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    player.control.complete();
    await tester.pump();
    expect(player.playing, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'initialization timeout releases resources and ignores late completion',
      (tester) async {
    final pending = Completer<void>();
    final player = FakePlayer(pending: pending);
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
    )));
    await tester.pump(const Duration(seconds: 21));
    expect(player.disposed, true);
    expect(find.textContaining('Could not play this tutorial'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('Real player surface'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('missing and unsupported media do not construct a player or demo',
      (tester) async {
    for (final url in [
      null,
      'https://youtube.com/watch?v=x',
      'file:///x.mp4'
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: PublishedExerciseTutorialScreen(
        key: ValueKey(url),
        exercise: row(url: url),
        playerFactory: (_) => throw StateError('Must not create player'),
      )));
      await tester.pump();
      expect(find.text('Tutorial video unavailable'), findsOneWidget);
      expect(find.textContaining('90 seconds'), findsNothing);
      expect(find.textContaining('Set your feet'), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    }
  });

  testWidgets(
      'loading then actual duration, controls, replay and seek without autoplay',
      (tester) async {
    final pending = Completer<void>();
    final player = FakePlayer(pending: pending);
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
    )));
    expect(find.text('Loading tutorial…'), findsOneWidget);
    pending.complete();
    await tester.pumpAndSettle();
    expect(player.plays, 0);
    expect(find.text('0:00 / 1:00'), findsOneWidget);
    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    expect(player.playing, true);
    await tester.tap(find.byTooltip('Pause tutorial'));
    await tester.pump();
    expect(player.playing, false);
    tester.widget<Slider>(find.byType(Slider)).onChanged!(30000);
    await tester.pump();
    expect(player.position, const Duration(seconds: 30));
    player.position = player.duration;
    player.notifyListeners();
    await tester.pump();
    await tester.tap(find.byTooltip('Replay tutorial'));
    await tester.pump();
    expect(player.position, Duration.zero);
    expect(player.playing, true);
    await tester.pumpWidget(const SizedBox());
    expect(player.disposed, true);
  });

  testWidgets('failure is sanitized and retry disposes failed player',
      (tester) async {
    final failed = FakePlayer(fail: true);
    final replacement = FakePlayer();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4?token=secret'),
      playerFactory: (_) => calls++ == 0 ? failed : replacement,
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not play this tutorial'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(failed.disposed, true);
    expect(find.text('Real player surface'), findsOneWidget);
    replacement.error = 'decoder private path';
    replacement.notifyListeners();
    await tester.pump();
    expect(find.textContaining('Could not play this tutorial'), findsOneWidget);
    expect(find.textContaining('private'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('background pauses without automatic resume', (tester) async {
    final player = FakePlayer();
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(player.playing, false);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(player.plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'account invalidation releases pending player and suppresses late result',
      (tester) async {
    final active = ValueNotifier(true);
    final pending = Completer<void>();
    final player = FakePlayer(pending: pending);
    await tester.pumpWidget(MaterialApp(
        home: PublishedExerciseTutorialScreen(
      exercise: row(url: 'https://media.example.test/exact.mp4'),
      playerFactory: (_) => player,
      authorized: active,
    )));
    active.value = false;
    expect(player.disposed, true);
    pending.complete();
    await tester.pumpAndSettle();
    expect(
        find.text('Sign in to view this account’s tutorial.'), findsOneWidget);
    expect(find.text('Real player surface'), findsNothing);
    expect(player.plays, 0);
    await tester.pumpWidget(const SizedBox());
    active.dispose();
  });

  testWidgets('actual AuthBloc route stops playback on logout', (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final player = FakePlayer();
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          home: ExerciseTutorialRoute(
              scope: auth.state.session!.scope,
              exercise: row(url: 'https://media.example.test/exact.mp4'),
              playerFactory: (_) => player),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play tutorial'));
    await tester.pump();
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    expect(player.disposed, true);
    await tester.pumpAndSettle();
    expect(
        find.text('Sign in to view this account’s tutorial.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });

  testWidgets(
      'app composition carries account guard into pushed routine tutorial',
      (tester) async {
    late AuthBloc auth;
    await tester.runAsync(() async {
      auth = AuthBloc(
          repository: InMemoryAuthRepository(organizationId: 'gainpath'));
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final routine = PublishedRoutine(
        id: 'published',
        sourceBlueprintId: 'source',
        title: 'Published targets',
        estimatedMinutes: 10,
        exercises: [row()]);
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider.value(
        value: auth,
        child: MaterialApp(
          home: WorkoutPrepRoute(publishedRoutine: routine),
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View routine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Published exercise'));
    await tester.pumpAndSettle();
    final route = tester
        .widget<ExerciseTutorialRoute>(find.byType(ExerciseTutorialRoute));
    expect(route.scope, auth.state.session!.scope);
    expect(identical(route.exercise, routine.exercises.single), true);
    expect(find.text('Tutorial video unavailable'), findsOneWidget);
    await tester.runAsync(() async {
      auth.add(const LoggedOut());
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedOut);
    });
    await tester.pumpAndSettle();
    expect(
        find.text('Sign in to view this account’s tutorial.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() => auth.close());
  });
}
