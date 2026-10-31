import 'dart:async';
import 'package:gainpath_mobile/features/gamification/application/mini_game_round_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/mini_games_screen.dart';
import 'package:gainpath_mobile/media/tutorial_video.dart';
import 'package:gainpath_mobile/navigation/feature_navigation.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_and_catch_view.dart';

class _Reader implements MiniGameContentReader {
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
  int calls = 0;
  Future<List<MiniGameContent>> Function()? result;
  @override
  Future<List<MiniGameContent>> load() async {
    calls++;
    return result == null
        ? [
            MiniGameContent.defaults('gym'),
            MiniGameContent.defaults('gym', gameId: MiniGameContent.reachTapId)
          ]
        : await result!();
  }
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

class _ConsentController extends ChangeNotifier
    implements MoveAndCatchController {
  @override
  MiniGameRoundCoordinator? get roundTiming => null;
  @override
  final scope = SessionScope(userId: 'member', organizationId: 'gym');
  @override
  bool current = true;
  @override
  bool hasConsent = false;
  @override
  bool loading = false;
  @override
  String? error;
  int cameraCalls = 0;
  @override
  Future<void> startCamera({required bool consented}) async {
    if (consented) cameraCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  MiniGameContent guide() => MiniGameContent(
      organizationId: 'gym',
      revision: 2,
      title: 'Catch with confidence',
      introduction: 'A guide from your gym.',
      instructions: ['Find a comfortable spot.', 'Lean gently.'],
      previewVideoUrl:
          'https://firebasestorage.googleapis.com/v0/b/gainpath-0619.firebasestorage.app/o/orgs%2Fgym%2FminiGameMedia%2Fmove-catch-v1%2Fpreview%2Fadmin%2F0123456789abcdef0123456789abcdef?alt=media&token=12345678-1234-1234-1234-123456789abc');

  testWidgets('consent uses scoped description and keeps fixed safeguards',
      (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _ConsentController();
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: MoveAndCatchView(
            controller: controller,
            viewport: const SizedBox(key: Key('camera')),
            content: guide())));
    expect(find.text('Catch with confidence'), findsOneWidget);
    expect(find.text('A guide from your gym.'), findsOneWidget);
    expect(find.text('1. Find a comfortable spot.'), findsOneWidget);
    expect(find.textContaining('Clear the floor around you.'), findsOneWidget);
    expect(find.textContaining('Camera and movement stay on this device.'),
        findsOneWidget);
    expect(find.byType(TutorialVideo), findsNothing);
    expect(find.byKey(const Key('camera')), findsNothing);
    expect(controller.cameraCalls, 0);
    await tester.ensureVisible(find.text('Enable camera'));
    await tester.tap(find.text('Enable camera'));
    expect(controller.cameraCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent rejects another organization description',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: MoveAndCatchView(
            controller: _ConsentController(),
            viewport: const SizedBox(),
            content: MiniGameContent.defaults('other')
                .copyWith(title: 'Other gym private title'))));
    expect(find.text('Other gym private title'), findsNothing);
    expect(find.text('Move & Catch'), findsOneWidget);
  });

  testWidgets('loaded metadata launches the supported game with content',
      (tester) async {
    final content = guide();
    final reader = _Reader()..result = () async => [content];
    RouteSettings? launched;
    await tester.pumpWidget(MaterialApp(
        home: MiniGamesScreen(connected: true, reader: reader),
        onGenerateRoute: (settings) {
          launched = settings;
          return MaterialPageRoute<void>(builder: (_) => const SizedBox());
        }));
    await tester.pumpAndSettle();
    expect(reader.calls, 1);
    expect(find.text(content.title), findsNWidgets(2));
    expect(find.text(content.introduction), findsOneWidget);
    expect(find.text('1. Find a comfortable spot.'), findsNothing);
    expect(find.byType(TutorialVideo), findsNothing);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    expect(find.text('1. Find a comfortable spot.'), findsOneWidget);
    await tester.ensureVisible(find.text('Start playing'));
    await tester.tap(find.text('Start playing'));
    await tester.pumpAndSettle();
    expect(launched?.name, FeatureNavigation.moveAndCatch);
    expect(identical(launched?.arguments, content), true);
  });

  testWidgets('unavailable content keeps explicit built-in guide and Retry',
      (tester) async {
    final reader = _Reader()
      ..result = () async => throw StateError('unavailable');
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Built-in game guide · latest content unavailable'),
        findsOneWidget);
    expect(find.text('Move & Catch'), findsNWidgets(2));
    expect(find.byTooltip('View Move & Catch details'), findsOneWidget);
    reader.result = () async => [guide()];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reader.calls, 2);
    expect(find.text('Catch with confidence'), findsNWidgets(2));
  });

  testWidgets('reader loads once per identity and refresh is explicit',
      (tester) async {
    final reader = _Reader();
    Widget screen(_Reader selected) =>
        MaterialApp(home: MiniGamesScreen(connected: true, reader: selected));
    await tester.pumpWidget(screen(reader));
    await tester.pumpAndSettle();
    await tester.pumpWidget(screen(reader));
    await tester.pumpAndSettle();
    expect(reader.calls, 1);
    await tester.tap(find.byTooltip('Refresh game guide'));
    await tester.pumpAndSettle();
    expect(reader.calls, 2);
    final replacement = _Reader()..result = () async => [guide()];
    await tester.pumpWidget(screen(replacement));
    await tester.pumpAndSettle();
    expect(replacement.calls, 1);
    expect(find.text('Catch with confidence'), findsNWidgets(2));
  });

  testWidgets('unsupported and cross-organization entries never render',
      (tester) async {
    final reader = _Reader()
      ..result = () async => [
            MiniGameContent(
                organizationId: 'gym',
                gameId: 'unimplemented-game',
                title: 'Unsupported game',
                introduction: 'Unavailable mechanics',
                instructions: const ['Invalid guide']),
            MiniGameContent.defaults('other')
                .copyWith(title: 'Another gym guide'),
          ];
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Unsupported game'), findsNothing);
    expect(find.text('Another gym guide'), findsNothing);
    expect(find.text('Move & Catch'), findsNWidgets(2));
    expect(find.text('Built-in game guide · latest content unavailable'),
        findsOneWidget);
  });

  testWidgets('preview loads only on tap and releases on session invalidation',
      (tester) async {
    final reader = _Reader()..result = () async => [guide()];
    final auth = _Auth();
    await tester.pumpWidget(BlocProvider<AuthBloc>.value(
        value: auth,
        child: MaterialApp(
            home: MiniGamesScreen(connected: true, reader: reader))));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialVideo), findsNothing);
    await tester.tap(find.byTooltip('View Move & Catch details'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Watch preview'));
    await tester.tap(find.text('Watch preview'));
    await tester.pumpAndSettle();
    expect(find.byType(TutorialVideo), findsOneWidget);
    reader.current = false;
    auth.changed();
    await tester.pumpAndSettle();
    expect(find.byType(TutorialVideo), findsNothing);
    expect(find.text('This game guide session has ended.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Catch with confidence'), findsNothing);
    expect(find.text('Start playing'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await auth.changes.close();
  });

  testWidgets('empty remote content is unavailable, revision zero is built-in',
      (tester) async {
    final reader = _Reader()..result = () async => [];
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    await tester.pumpAndSettle();
    expect(find.text('Built-in game guide · latest content unavailable'),
        findsOneWidget);
    reader.result = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Built-in game guide'), findsOneWidget);
  });

  testWidgets('late content and captured metadata hide when session ends',
      (tester) async {
    final pending = Completer<List<MiniGameContent>>();
    final reader = _Reader()..result = () => pending.future;
    await tester.pumpWidget(
        MaterialApp(home: MiniGamesScreen(connected: true, reader: reader)));
    reader.current = false;
    pending.complete([guide()]);
    await tester.pumpAndSettle();
    expect(find.text('Catch with confidence'), findsNothing);
    expect(find.text('Start playing'), findsNothing);
    expect(find.text('This game guide session has ended.'), findsOneWidget);
  });

  testWidgets('built-in guide fits 375px at double text size', (tester) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        builder: (_, child) => MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: child!),
        home: const MiniGamesScreen(connected: true)));
    await tester.pumpAndSettle();
    expect(find.text('Built-in game guide'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('View Move & Catch details'));
    expect(tester.takeException(), isNull);
  });
}
