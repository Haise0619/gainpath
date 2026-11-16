import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/chatbot.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/assistant_reply_view.dart';
import 'package:gainpath_mobile/features/chatbot/presentation/member/assistant_reply_view_model.dart';
import '../../../test_support/fyp_render_support.dart'
    show installFypOfflineFonts;

Map<String, dynamic> availabilityFixture(int now) {
  final day = DateTime.fromMillisecondsSinceEpoch(now, isUtc: true)
      .add(const Duration(days: 1, hours: 8));
  final start =
      DateTime.utc(day.year, day.month, day.day, 2).millisecondsSinceEpoch;
  return {
    'schemaVersion': 1,
    'localDate': DateTime.fromMillisecondsSinceEpoch(start, isUtc: true)
        .toIso8601String()
        .substring(0, 10),
    'timeZone': 'Asia/Kuala_Lumpur',
    'durationMinutes': 60,
    'expiresAtMillis': now + 300000,
    'truncated': false,
    'items': [
      {
        'coachId': 'coach-fixture',
        'name': 'Alex · Sample coach',
        'branchId': 'branch-fixture',
        'branchName': 'Central Studio',
        'startAtMillis': start,
        'endAtMillis': start + 3600000,
        'startLabel': '10:00',
        'endLabel': '11:00',
        'amountMinor': 12000,
        'currency': 'MYR'
      }
    ]
  };
}

ChatMessage accuracyFixture(String kind) {
  const source = 'Presentation fixture · not a real Member account';
  FitnessFactsAttachment facts(String title, List<FitnessFact> rows,
          List<FitnessFactAction> actions) =>
      FitnessFactsAttachment(
          title: title, subtitle: source, facts: rows, actions: actions);
  return switch (kind) {
    'equipment' => const ChatMessage(
        'For your chest, a chest press machine or cable fly can target the pectoral muscles. Start with a comfortable load and follow the equipment guide.',
        false),
    'nutrition' => const ChatMessage(
        'Choose balanced meals with vegetables, whole grains and a protein source such as eggs, beans, tofu or fish. Drink water regularly and adjust portions to your needs.',
        false),
    'last-workout' => ChatMessage('Your completed workout is saved.', false,
        sources: const [source],
        attachment: facts('Your last workout', const [
          FitnessFact('Routine', 'Full Body Foundations'),
          FitnessFact('Saved record type', 'Completed routine'),
          FitnessFact('Status', 'Completed'),
          FitnessFact('Completed', '16 Nov 2026 · 8:00 AM MYT'),
          FitnessFact('Repetitions', '24 full · 2 partial'),
          FitnessFact('Completed exercises', '3 / 3'),
          FitnessFact('Duration', '12m 20s'),
          FitnessFact('Form Score',
              'Open the report for qualified per-exercise scores; no routine-wide score is inferred.')
        ], const [
          FitnessFactAction(
              'View workout report', FitnessFactTarget.workoutReport)
        ])),
    'membership' => ChatMessage(
        'Published benefits remain separate from current access.', false,
        sources: const [source],
        attachment: facts('Your membership', const [
          FitnessFact('Requested plan', 'Premium'),
          FitnessFact('Current effective plan', 'Basic'),
          FitnessFact('Paid plan status', 'active'),
          FitnessFact('Paid plan expiry', '30 Nov 2026 · 8:00 AM MYT'),
          FitnessFact(
              'Your verified benefits', 'Digital dashboard\nGym access'),
          FitnessFact('Shared published benefits', 'Digital dashboard'),
          FitnessFact('Basic — additional published benefits', 'Gym access'),
          FitnessFact('Premium — additional published benefits',
              'Coach discount\nPremium rewards\nCheck-in bonus')
        ], const [
          FitnessFactAction('Open Membership', FitnessFactTarget.membership)
        ])),
    'tomorrow' => ChatMessage(
        'Verified times from the scheduling service.', false,
        sources: const [source],
        attachment: CoachAvailabilityAttachment.fromJson(
            availabilityFixture(DateTime.now().millisecondsSinceEpoch))),
    'tutorial' => const ChatMessage(
        'Here is a published tutorial for your Squat practice.', false,
        sources: [source],
        attachment: FitnessFactsAttachment(
          title: 'Tutorials for your training',
          subtitle: source,
          facts: [FitnessFact('Squat', 'Practice a controlled squat')],
          actions: [
            FitnessFactAction('View Squat tutorial', FitnessFactTarget.tutorial,
                id: 'sample:1:0')
          ],
          contentPreviews: [
            FitnessContentPreview(
              title: 'Squat',
              imageUrl: 'https://example.test/squat-cover.png',
              action: FitnessFactAction(
                  'View Squat tutorial', FitnessFactTarget.tutorial,
                  id: 'sample:1:0'),
            ),
          ],
        )),
    _ => ChatMessage(
        'Your squat observations stay in the same measurement group.', false,
        sources: const [source],
        attachment: facts('Your training snapshot', const [
          FitnessFact('Available exercise captures', '3'),
          FitnessFact(
              'Squat · side', '78.0% estimated mean · 3 comparable captures'),
          FitnessFact('Limited observed change',
              '76.0% → 80.0% · same measurement group, not proof of improvement')
        ], const [
          FitnessFactAction(
              'View workout report', FitnessFactTarget.workoutReport)
        ])),
  };
}

void main() {
  testWidgets(
      'availability expiring between build and tap refreshes without navigation',
      (tester) async {
    var now = DateTime.now().millisecondsSinceEpoch;
    final availability = CoachAvailabilityAttachment.fromJson(
        availabilityFixture(now),
        clock: () => now);
    var reviews = 0, refreshes = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: AssistantReplyView(
                    reply: AssistantReplyViewModel.fromMessage(ChatMessage(
                        'Available times.', false,
                        attachment: availability)),
                    onReviewBooking: (_) => reviews++,
                    onRetry: () => refreshes++)))));
    await tester.pumpAndSettle();
    now += 300001;
    await tester.ensureVisible(find.text('Review session'));
    await tester.tap(find.text('Review session'));
    expect(reviews, 0);
    expect(refreshes, 1);
    expect(tester.takeException(), isNull);
  });
  test('availability refuses forged30-minute slots and foreign lookup objects',
      () {
    final json = availabilityFixture(DateTime.now().millisecondsSinceEpoch);
    final row = (json['items'] as List).single as Map;
    row['endAtMillis'] = (row['startAtMillis'] as int) + 1800000;
    expect(() => CoachAvailabilityAttachment.fromJson(json),
        throwsFormatException);
  });
  for (final kind in [
    'equipment',
    'nutrition',
    'last-workout',
    'squat',
    'membership',
    'tomorrow',
    'tutorial'
  ]) {
    for (final large in [false, true]) {
      testWidgets(
          '$kind accuracy presentation ${large ? '320dp200percent' : '390dp'}',
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
          if (kind == 'tutorial') {
            final codec = await ui.instantiateImageCodec(
                await File('assets/images/workout_hero_gym.png').readAsBytes());
            final frame = await codec.getNextFrame();
            final coverKey =
                await const NetworkImage('https://example.test/squat-cover.png')
                    .obtainKey(ImageConfiguration.empty);
            PaintingBinding.instance.imageCache.putIfAbsent(
                coverKey,
                () => OneFrameImageStreamCompleter(
                    Future.value(ImageInfo(image: frame.image))));
            codec.dispose();
          }
        });
        tester.view.physicalSize = Size(large ? 320 : 390, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: buildMemberTypographyTheme(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(large ? 2 : 1)),
                child: child!),
            home: RepaintBoundary(
                key: key,
                child: Scaffold(
                    backgroundColor: const Color(0xFFFAF8FF),
                    appBar: AppBar(title: const Text('GainPath Assistant')),
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: AssistantReplyView(
                            reply: AssistantReplyViewModel.fromMessage(
                                accuracyFixture(kind)),
                            onOpenFact: (_) {},
                            onReviewBooking: (_) {},
                            onRetry: () {}))))));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (kind == 'tutorial') {
          expect(find.text('View Squat tutorial'), findsOneWidget);
          expect(find.byType(Image), findsOneWidget);
        }
        if (const bool.fromEnvironment('GAINPATH_RENDER_CHATBOT_ACCURACY')) {
          await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 1.5);
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            final dir = Directory('../../build/chatbot-accuracy/screenshots')
              ..createSync(recursive: true);
            await File('${dir.path}/$kind-${large ? '320-large' : '390'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      });
    }
  }
}
