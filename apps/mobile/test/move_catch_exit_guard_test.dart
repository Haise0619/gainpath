import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/gamification/application/move_and_catch_controller.dart';
import 'package:gainpath_mobile/features/gamification/domain/move_and_catch.dart';
import 'package:gainpath_mobile/features/gamification/presentation/member/move_catch_exit_guard.dart';

class Engine extends Fake implements MoveCatchEngine {
  @override
  MoveCatchPhase phase = MoveCatchPhase.playing;
}

class Controller extends ChangeNotifier implements MoveAndCatchController {
  @override
  final Engine engine = Engine();
  @override
  bool current = true;
  @override
  bool hasConsent = true;
  int pauses = 0, resumes = 0, closes = 0, settled = 0;
  @override
  Future<void> pause() async {
    pauses++;
    engine.phase = MoveCatchPhase.paused;
  }

  @override
  Future<void> resume() async {
    resumes++;
    engine.phase = MoveCatchPhase.countdown;
  }

  @override
  Future<void> close() async {
    closes++;
    current = false;
  }

  @override
  Future<void> finishAndClose() async {
    settled++;
    await close();
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  Future<void> open(WidgetTester tester, Controller c) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MoveCatchExitGuard(
                                controller: c,
                                builder: (exit) => Scaffold(
                                    body: TextButton(
                                        onPressed: exit,
                                        child: const Text('Exit round')))))),
                    child: const Text('Open game'))))));
    await tester.tap(find.text('Open game'));
    await tester.pumpAndSettle();
  }

  testWidgets('unfinished exit pauses, Continue resumes, Leave closes once',
      (tester) async {
    final c = Controller();
    await open(tester, c);
    await tester.tap(find.text('Exit round'));
    await tester.pumpAndSettle();
    expect(c.pauses, 1);
    expect(find.text('Leave this round?'), findsOneWidget);
    await tester.tap(find.text('Continue playing'));
    await tester.pumpAndSettle();
    expect(c.resumes, 1);
    expect(c.closes, 0);
    await tester.tap(find.text('Exit round'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave round'));
    await tester.pumpAndSettle();
    expect(c.closes, 1);
    expect(find.text('Open game'), findsOneWidget);
  });
  testWidgets('system back uses confirmation and completed exit settles result',
      (tester) async {
    final c = Controller();
    await open(tester, c);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave this round?'), findsOneWidget);
    await tester.tap(find.text('Continue playing'));
    await tester.pumpAndSettle();
    c.engine.phase = MoveCatchPhase.finished;
    c.notifyListeners();
    await tester.pump();
    await tester.tap(find.text('Exit round'));
    await tester.pumpAndSettle();
    expect(c.settled, 1);
    expect(c.closes, 1);
  });
}
