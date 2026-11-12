import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_data/gainpath_data.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_identity/gainpath_identity.dart';
import 'package:gainpath_mobile/app/member_typography_theme.dart';
import '../../../test_support/fyp_render_support.dart';
import 'package:gainpath_mobile/app/routing/member_points_progress_route.dart';
import 'reward_journey_test.dart' as rewards;
import 'app_check_in_test.dart' as check;

class RenderReceipts extends rewards.JourneyRewards {
  RenderReceipts(this.mode);
  final String mode;
  final receiptsPending = Completer<PointsHistorySnapshot>();
  @override
  Future<VerifiedRewardsSnapshot> overview() async {
    if (mode == 'error') throw StateError('offline');
    return super.overview();
  }

  @override
  Future<PointsHistorySnapshot> pointsHistory() async {
    if (mode == 'loading') return receiptsPending.future;
    if (mode == 'error') throw StateError('offline');
    return PointsHistorySnapshot(
        balance: mode == 'empty' ? 0 : 125,
        reconciled: mode == 'empty',
        entries: mode == 'empty'
            ? []
            : [
                for (var i = 0; i < 8; i++)
                  PointsHistoryEntry(
                      id: 'receipt$i',
                      source: i == 1 ? 'redemption' : 'app_check_in',
                      title: i == 1
                          ? 'Soft training towel redemption'
                          : 'Daily check-in reward',
                      points: i == 1 ? -25 : 50,
                      occurredAtMillis: DateTime.now()
                          .subtract(Duration(days: i))
                          .millisecondsSinceEpoch,
                      redemptionId: i == 1 ? 'towel' : null)
              ]);
  }
}

void main() {
  testWidgets('render live Rewards & Check-in responsive states', (t) async {
    final restore = await installFypOfflineFonts();
    addTearDown(restore);
    await t.runAsync(() async {
      for (final family in ['Barlow', 'BarlowCondensed', 'MaterialIcons']) {
        final loader = FontLoader(family);
        for (final name in family == 'MaterialIcons'
            ? [
                'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
              ]
            : [
                'assets/fonts/$family-Regular.ttf',
                'assets/fonts/$family-SemiBold.ttf',
                'assets/fonts/$family-Bold.ttf'
              ]) {
          loader.addFont(File(name).readAsBytes().then(ByteData.sublistView));
        }
        await loader.load();
      }
    });
    late AuthBloc auth;
    await t.runAsync(() async {
      auth = AuthBloc(repository: InMemoryAuthRepository());
      await Future<void>.delayed(Duration.zero);
      auth.add(const LoginSubmitted(
          email: 'member@example.com', password: 'password123'));
      await auth.stream.firstWhere((s) => s.status == AuthStatus.signedIn);
    });
    final output = Directory(const String.fromEnvironment('REWARDS_RENDER_DIR',
        defaultValue:
            '../../build/report-rewards-consumer-20261112/rewards-after'))
      ..createSync(recursive: true);
    final cases = [
      for (final width in [320.0, 360.0, 390.0])
        for (final scale in [1.0, 1.5, 2.0])
          (
            name: '${width.toInt()}-${(scale * 100).toInt()}',
            size: Size(width, 844),
            scale: scale,
            mode: 'ready'
          ),
      for (final mode in ['loading', 'error', 'empty', 'claimed'])
        (name: '390-$mode', size: const Size(390, 844), scale: 1.0, mode: mode),
      (
        name: 'landscape-200',
        size: const Size(844, 390),
        scale: 2.0,
        mode: 'ready'
      ),
    ];
    for (final variant in cases) {
      t.view.physicalSize = variant.size;
      t.view.devicePixelRatio = 1;
      final key = GlobalKey();
      final repo = RenderReceipts(variant.mode),
          checkIn = check.FakeCheckIn(auth.state.session!.scope)
            ..claimed = variant.mode == 'claimed';
      await t.pumpWidget(BlocProvider.value(
          value: auth,
          child: MaterialApp(
              theme: buildMemberTypographyTheme(),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(variant.scale),
                      disableAnimations: true),
                  child: child!),
              home: RepaintBoundary(
                  key: key,
                  child: LivePointsProgress(
                      key: ValueKey(variant.name),
                      repository: repo,
                      checkInFactory: (_, __) async => checkIn)))));
      if (variant.mode == 'loading') {
        await t.pump();
        await t.pump(const Duration(milliseconds: 300));
      } else {
        await t.pumpAndSettle();
      }
      Future<void> capture(String section) async {
        await t.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${output.path}/${variant.name}-$section.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(t.takeException(), isNull, reason: '${variant.name} $section');
      }

      await capture('top');
      final scroll = find.byType(Scrollable).first;
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await t.drag(scroll, const Offset(0, -550));
      }
      if (variant.mode == 'loading') {
        await t.pump(const Duration(milliseconds: 300));
      } else {
        await t.pumpAndSettle();
      }
      await capture('middle');
      if (find.byType(Scrollable).evaluate().isNotEmpty) {
        await t.drag(scroll, const Offset(0, -2000));
      }
      if (variant.mode == 'loading') {
        await t.pump(const Duration(milliseconds: 300));
      } else {
        await t.pumpAndSettle();
      }
      await capture('bottom');
      await t.pumpWidget(const SizedBox());
      await t.pump();
    }
    t.view.reset();
    await t.runAsync(auth.close);
  }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_REWARDS'));
}
