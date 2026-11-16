import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/assistant_reply_view.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/assistant_reply_view_model.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/chatbot_screen.dart';
import 'module6_chat_flow_test.dart' show LiveChat;
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

ChatMessage fixtureReply(String kind) {
  const source = 'Presentation fixture · not a real Member record';
  FitnessFactsAttachment facts(String title, List<FitnessFact> rows,
          List<FitnessFactAction> actions) =>
      FitnessFactsAttachment(
          title: title, subtitle: source, facts: rows, actions: actions);
  return switch (kind) {
    'membership' => ChatMessage('Here are the current plan facts.', false,
        sources: const [source],
        attachment: facts('Your membership', const [
          FitnessFact('Current effective plan', 'Basic'),
          FitnessFact('Your verified benefits',
              'Gym access\nCoach booking\nMini games\nRegular rewards'),
          FitnessFact('Source', 'Verified plan snapshot')
        ], const [
          FitnessFactAction('Open Membership', FitnessFactTarget.membership)
        ])),
    'workout' => ChatMessage('Here is your saved exercise capture.', false,
        sources: const [source],
        attachment: facts('Your last workout', const [
          FitnessFact('Exercise', 'Squat'),
          FitnessFact('Repetitions', '12 full · 1 partial'),
          FitnessFact('Duration', '2m 10s'),
          FitnessFact('Estimated Form Score', 'Not assessed'),
          FitnessFact('Sets', 'Not recorded for an individual capture'),
          FitnessFact('Tracking', '90s tracked · 3s rejected'),
          FitnessFact('Sync status', 'localOnly')
        ], const [
          FitnessFactAction(
              'View workout report', FitnessFactTarget.workoutReport)
        ])),
    'insight' =>
      ChatMessage('Only compatible measurements are compared.', false,
          sources: const [source],
          attachment: facts('Your training snapshot', const [
            FitnessFact('Available exercise captures', '6'),
            FitnessFact('Full / partial repetitions', '72 / 3'),
            FitnessFact('This Malaysia week', '3 captures · 36 full reps'),
            FitnessFact('Routine attempts', '1 · separate from captures'),
            FitnessFact(
                'Squat · side', '78.0% estimated mean · 3 comparable captures'),
            FitnessFact('Limited observed change',
                '76.0% → 80.0% · same measurement group, not proof of improvement')
          ], const [
            FitnessFactAction(
                'View workout report', FitnessFactTarget.workoutReport)
          ])),
    'coach' => const ChatMessage('Choose a coach to review a session.', false,
        sources: [source],
        attachment: CoachDirectoryAttachment([
          AssistantCoachOption(
              coachId: 'fixture-coach',
              name: 'Alex · Demo coach',
              branchName: 'Central Studio',
              amountMinor: 12000)
        ])),
    'recommendation' =>
      ChatMessage('These are existing recommendations.', false,
          sources: const [source],
          attachment: facts('Why these recommendations?', const [
            FitnessFact('Squat foundations',
                'Practice controlled squat movement\nMatched to your saved exercise context\nCreated 16 Nov 2026 · available')
          ], const [
            FitnessFactAction(
                'Open Squat foundations', FitnessFactTarget.recommendation,
                id: 'fixture-recommendation')
          ])),
    _ => const ChatMessage(
        'Start with a comfortable warm-up. Choose a load that lets you move with control, and rest between sets.',
        false),
  };
}

void main() {
  testWidgets(
      'empty coach results refresh the selected question through the existing flow',
      (tester) async {
    final repository = LiveChat()
      ..accepted = true
      ..reply = const ChatMessage(
          'No eligible coaches are available on this page.', false,
          attachment: CoachDirectoryAttachment([]));
    await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
        value: repository,
        child: const MaterialApp(home: ChatbotScreen(connected: true))));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Training help'));
    await tester.tap(find.text('Training help'));
    await tester.pumpAndSettle();
    expect(repository.calls, 1);
    await tester.ensureVisible(find.text('Refresh coaches'));
    await tester.tap(find.text('Refresh coaches'));
    await tester.pumpAndSettle();
    expect(repository.calls, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('coach results keep only three choices visible until expanded',
      (tester) async {
    final message = ChatMessage('Choose a coach.', false,
        attachment: CoachDirectoryAttachment(List.generate(
            5,
            (index) => AssistantCoachOption(
                coachId: 'coach-$index',
                name: 'Coach $index',
                branchName: 'Studio',
                amountMinor: 12000))));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AssistantReplyView(
                    reply: AssistantReplyViewModel.fromMessage(message),
                    onOpenFact: (_) {})))));
    expect(find.text('Coach 0'), findsOneWidget);
    expect(find.text('Coach 3').hitTestable(), findsNothing);
    await tester.ensureVisible(find.text('More coaches (2)'));
    await tester.tap(find.text('More coaches (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Coach 3'), findsOneWidget);
  });
  testWidgets('membership keeps three benefits visible and expands the rest',
      (tester) async {
    final model =
        AssistantReplyViewModel.fromMessage(fixtureReply('membership'));
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AssistantReplyView(
                    reply: model, onOpenFact: (_) => opened++)))));
    expect(find.text('Gym access'), findsOneWidget);
    expect(find.text('Regular rewards').hitTestable(), findsNothing);
    await tester.tap(find.text('View all benefits'));
    await tester.pumpAndSettle();
    expect(find.text('Regular rewards').hitTestable(), findsOneWidget);
    await tester.ensureVisible(find.text('Open Membership'));
    await tester.tap(find.text('Open Membership'));
    expect(opened, 1);
  });
  testWidgets('technical workout details stay folded and are still accessible',
      (tester) async {
    final model = AssistantReplyViewModel.fromMessage(fixtureReply('workout'));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AssistantReplyView(reply: model)))));
    expect(find.text('Your last workout'), findsOneWidget);
    expect(find.text('Tracking').hitTestable(), findsNothing);
    await tester.ensureVisible(find.text('Details and source'));
    await tester.tap(find.text('Details and source'));
    await tester.pumpAndSettle();
    expect(find.text('Tracking'), findsOneWidget);
    expect(find.text('Not assessed'), findsWidgets);
  });
  testWidgets(
      'coach CTA keeps trusted identifier and does not create a booking',
      (tester) async {
    FitnessFactAction? opened;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: AssistantReplyView(
                reply:
                    AssistantReplyViewModel.fromMessage(fixtureReply('coach')),
                onOpenFact: (action) => opened = action))));
    expect(opened, isNull);
    expect(find.text('Alex · Demo coach'), findsOneWidget);
    expect(find.text('RM 120.00'), findsOneWidget);
    await tester.tap(find.text('Book session'));
    expect(opened!.target, FitnessFactTarget.coaches);
    expect(opened!.id, 'fixture-coach');
  });
  for (final kind in [
    'membership',
    'workout',
    'insight',
    'coach',
    'recommendation',
    'normal',
    'error'
  ]) {
    for (final small in [false, true]) {
      testWidgets('$kind reply ${small ? '320dp large text' : '390dp'} renders',
          (tester) async {
        final restore = await tester.runAsync(installFypOfflineFonts);
        addTearDown(restore!);
        await tester.runAsync(() async {
          for (final (family, path) in [
            (
              'MaterialIcons',
              'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
            ),
            ('Barlow', 'assets/fonts/Barlow-Regular.ttf'),
            ('BarlowCondensed', 'assets/fonts/BarlowCondensed-Regular.ttf')
          ]) {
            await (FontLoader(family)
                  ..addFont(
                      File(path).readAsBytes().then(ByteData.sublistView)))
                .load();
          }
        });
        tester.view.physicalSize = Size(small ? 320 : 390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final model = kind == 'error'
            ? AssistantReplyViewModel.error(
                'Your workout records could not be loaded. Your question is kept.',
                retryLabel: 'Retry')
            : AssistantReplyViewModel.fromMessage(fixtureReply(kind));
        final boundary = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: buildMemberTypographyTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(small ? 2 : 1)),
                child: child!),
            home: RepaintBoundary(
                key: boundary,
                child: Scaffold(
                    backgroundColor: const Color(0xFFFAF8FF),
                    appBar: AppBar(title: const Text('GainPath Assistant')),
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AssistantReplyView(
                            reply: model,
                            onOpenFact: (_) {},
                            onRetry: () {},
                            onEdit: kind == 'error' ? () {} : null))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('GAINPATH_RENDER_CHATBOT_REPLIES')) {
          await tester.runAsync(() async {
            final image = await (boundary.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final dir =
                Directory('../../build/chatbot-reply-presentation/screenshots')
                  ..createSync(recursive: true);
            await File('${dir.path}/$kind-${small ? '320-large' : '390'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
