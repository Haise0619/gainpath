import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/chatbot_screen.dart';
import 'module6_chat_flow_test.dart' show LiveChat;
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

class LongChat extends LiveChat {
  @override
  List<ChatMessage> get chatSeed => List.generate(
      200,
      (index) => ChatMessage(
          'Saved conversation message $index. Read this training guidance at your own pace.',
          false,
          id: 'fixture-$index'));
}

void main() {
  testWidgets('long conversation bookmarks preserve reading position',
      (tester) async {
    final repo = LongChat()..accepted = true;
    await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
        value: repo,
        child: const MaterialApp(home: ChatbotScreen(connected: true))));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, 450));
    await tester.pumpAndSettle();
    final scroll = tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first)
        .position;
    final before = scroll.pixels;
    await tester.tap(find.text('Save').hitTestable().first);
    await tester.pumpAndSettle();
    expect(scroll.pixels, closeTo(before, 1));
    expect(tester.takeException(), isNull);
  });
  for (final scenario in [
    ('welcome', 390.0, 1.0),
    ('large-text', 320.0, 2.0),
    ('workout-card', 390.0, 1.0),
    ('branch-card', 390.0, 1.0),
    ('keyboard', 360.0, 1.0),
    ('general-reply', 390.0, 1.0),
    ('general-reply-keyboard', 320.0, 2.0),
  ]) {
    testWidgets('assistant ${scenario.$1} is readable and renders',
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
          ('BarlowCondensed', 'assets/fonts/BarlowCondensed-Regular.ttf'),
        ]) {
          await (FontLoader(family)
                ..addFont(File(path).readAsBytes().then(ByteData.sublistView)))
              .load();
        }
        const asset = 'assets/images/ai_coach_mascot.png';
        final codec =
            await ui.instantiateImageCodec(await File(asset).readAsBytes());
        final frame = await codec.getNextFrame();
        final imageKey =
            await const AssetImage(asset).obtainKey(ImageConfiguration.empty);
        PaintingBinding.instance.imageCache.putIfAbsent(
            imageKey,
            () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: frame.image))));
        final smallAvatar =
            await const ResizeImage(AssetImage(asset), width: 96)
                .obtainKey(ImageConfiguration.empty);
        PaintingBinding.instance.imageCache.putIfAbsent(
            smallAvatar,
            () => OneFrameImageStreamCompleter(
                Future.value(ImageInfo(image: frame.image.clone()))));
        codec.dispose();
      });
      tester.view.physicalSize = Size(scenario.$2, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = LiveChat()..accepted = true;
      repo.reply = const ChatMessage(
          'Here is the saved summary from your device. Unscored activity stays unassessed.',
          false,
          sources: ['Device records · demonstration fixture'],
          attachment: FitnessFactsAttachment(
              title: 'Your last workout',
              subtitle: 'Demonstration fixture · not a real Member record',
              facts: [
                FitnessFact('Exercise', 'Squat'),
                FitnessFact('Completed repetitions', '12'),
                FitnessFact('Form assessment', 'Not assessed')
              ],
              actions: [
                FitnessFactAction(
                    'View workout report', FitnessFactTarget.workoutReport)
              ]));
      final general = scenario.$1.startsWith('general-reply');
      final keyboard = scenario.$1.endsWith('keyboard');
      const question = 'Which equipment works my chest?';
      const answer =
          'A chest press machine, dumbbells, or a cable station can all train your chest.\n\n'
          '- Chest press: a stable option when you are getting started.\n'
          '- Dumbbells: use a bench or try a floor press.\n'
          '- Cables: try a light chest fly.\n\n'
          'Start with a load you can move smoothly for each rep.';
      if (general) repo.reply = const ChatMessage(answer, false);
      if (scenario.$1 == 'branch-card') {
        repo.reply = ChatMessage('Here are the recorded branch details.', false,
            attachment: BranchChatAttachment('fixture-org', {
              'branchId': 'north',
              'displayName': 'North Gym',
              'address': 'Fixture address',
              'openingHours': List.generate(7, (_) => {'allDay': true}),
            }));
      }
      final key = GlobalKey();
      await tester.pumpWidget(RepositoryProvider<ChatRepository>.value(
          value: repo,
          child: MaterialApp(
              theme: buildMemberTypographyTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(scenario.$3),
                      viewInsets: EdgeInsets.only(bottom: keyboard ? 300 : 0)),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: ChatbotScreen(connected: true, onOpenFact: (_) {})))));
      await tester.pumpAndSettle();
      if (scenario.$1 == 'branch-card') {
        await tester.enterText(find.byType(TextField), 'How do I get to this gym?');
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(find.text('North Gym'), findsOneWidget);
        expect(find.text('Fixture address'), findsOneWidget);
        expect(find.text('View branch'), findsOneWidget);
        expect(find.text('Get directions'), findsOneWidget);
      }
      if (scenario.$1 == 'workout-card') {
        await tester.ensureVisible(find.text('Training help'));
        await tester.tap(find.text('Training help'));
        await tester.pumpAndSettle();
        expect(find.text('Your last workout'), findsOneWidget);
      }
      if (general) {
        final field = find.byType(TextField);
        await tester.enterText(field, question);
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        final bubble = find.byKey(const ValueKey('assistant-text-bubble'));
        expect(bubble, findsOneWidget);
        if (keyboard) {
          expect(tester.getTopLeft(bubble).dy, greaterThanOrEqualTo(55));
          await tester.drag(find.byType(ListView), const Offset(0, 180));
          await tester.pumpAndSettle();
        }
        expect(find.text(question), findsOneWidget);
        expect(tester.getTopLeft(bubble).dx,
            lessThan(tester.getTopLeft(find.text(question)).dx));
        if (keyboard) {
          await tester.drag(find.byType(ListView), const Offset(0, -1200));
          await tester.pumpAndSettle();
        }
        for (final action in ['Copy', 'Save', 'Helpful', 'Not helpful']) {
          expect(keyboard ? find.byTooltip(action) : find.text(action),
              findsOneWidget);
        }
        expect(find.byTooltip('Send message').hitTestable(), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('GAINPATH_RENDER_CHATBOT')) {
        await tester.runAsync(() async {
          final image = await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir =
              Directory('../../build/chatbot-message-refinement/screenshots')
                ..createSync(recursive: true);
          await File('${dir.path}/${scenario.$1}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      if (scenario.$1 == 'workout-card') {
        await tester.ensureVisible(find.text('Save'));
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(repo.savedAdvice.single, contains('Completed repetitions: 12'));
        expect(repo.savedAdvice.single, contains('Not assessed'));
      }
      if (scenario.$1 == 'branch-card') {
        await tester.ensureVisible(find.text('View branch'));
        await tester.tap(find.text('View branch'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(AlertDialog, 'North Gym'), findsOneWidget);
      }
    });
  }
}
