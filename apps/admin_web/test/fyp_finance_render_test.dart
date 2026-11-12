import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';
import 'payment_review_screen_test.dart' show ReviewFake;
import 'support/module13_demo_render.dart' show loadDemoRenderFonts;

class _StateFake extends ReviewFake {
  _StateFake(this.state);
  final String state;
  final pagePending = Completer<PaymentReviewPage>();
  @override
  Future<PaymentReviewPage> load({String? afterId}) {
    if (state == 'loading') return pagePending.future;
    if (state == 'error') {
      return Future.error(const PaymentReviewException('permission-denied'));
    }
    if (state == 'empty') return Future.value(PaymentReviewPage([]));
    return super.load(afterId: afterId);
  }
}

void main() {
  setUpAll(loadDemoRenderFonts);
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1440, 1100)
  ]) {
    for (final state in [
      'transactions',
      'refunds',
      'reconciliation',
      'details',
      'loading',
      'error',
      'empty'
    ]) {
      testWidgets('finance render ${size.width.toInt()} $state',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final repo = _StateFake(state);
        repo.record = PaymentReviewRecord({
          ...repo.record.data,
          'refundStatus': 'pending_review',
          'localDate': '2026-11-12',
          'startLabel': '10:00',
          'endLabel': '11:00'
        });
        const key = ValueKey('finance-capture');
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              useMaterial3: true,
              fontFamily: 'CReview',
              colorScheme: const ColorScheme.light(
                  primary: AppColors.primary,
                  onPrimary: Colors.white,
                  surface: AppColors.surface,
                  onSurface: AppColors.ink)),
          home: RepaintBoundary(
              key: key,
              child: ColoredBox(
                  color: AppColors.bg,
                  child: PaymentsScreen(
                    live: true,
                    repository: repo,
                    isCurrent: () => true,
                    mode: state == 'refunds'
                        ? PaymentsMode.refunds
                        : state == 'reconciliation'
                            ? PaymentsMode.reconciliation
                            : PaymentsMode.transactions,
                    initialBookingId: state == 'details' ? 'booking-1' : null,
                  ))),
        ));
        if (state == 'loading') {
          await tester.pump(const Duration(milliseconds: 150));
        } else {
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final dir = Directory('../../build/acceptance/admin-finance');
          await dir.create(recursive: true);
          await File('${dir.path}/${size.width.toInt()}-$state.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
