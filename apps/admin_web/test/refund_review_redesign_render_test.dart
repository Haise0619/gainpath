import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/membership/payment_review_repository.dart';
import 'package:gainpath_admin_web/features/membership/presentation/admin/refunds_screen.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

class RenderMockRepo implements PaymentReviewRepository {
  final PaymentReviewRecord reviewableRecord = PaymentReviewRecord({
    'bookingId': 'bk-202611-0042',
    'memberId': 'user-m-4421',
    'memberName': 'Marcus Vance',
    'memberEmail': 'marcus.v@gainpath.com',
    'coachName': 'Elena Rostova',
    'branchName': 'Downtown Flagship',
    'amountMinor': 16000,
    'currency': 'MYR',
    'paymentStatus': 'cleared',
    'fulfilmentStatus': 'reconciliation_required',
    'bookingStatus': 'cancelled',
    'refundStatus': 'pending_review',
    'refundReason': 'Coach emergency medical conflict on appointment date',
    'refundNotes': 'Member requested full refund to original payment card. Alternative session times declined.',
    'provider': 'xendit',
    'billId': 'xnd_inv_20261124_987654',
    'createdAtMillis': 1732000000000,
    'paymentConfirmedAtMillis': 1732000500000,
    'cancelledAtMillis': 1732005000000,
  });

  final PaymentReviewRecord completedRecord = PaymentReviewRecord({
    'bookingId': 'bk-202611-0038',
    'memberId': 'user-m-3918',
    'memberName': 'Sophia Chen',
    'memberEmail': 'sophia.chen@gainpath.com',
    'coachName': 'David Miller',
    'branchName': 'West Bay',
    'amountMinor': 12000,
    'currency': 'MYR',
    'paymentStatus': 'cleared',
    'fulfilmentStatus': 'reconciliation_required',
    'bookingStatus': 'cancelled',
    'refundStatus': 'completed',
    'refundReason': 'Session cancelled within refund policy window (>24h)',
    'refundReference': 'ref-exec-202611-089',
    'reviewReason': 'Approved: Verified cancellation occurred 36 hours prior to session.',
    'provider': 'billplz',
    'billId': 'bp_bill_20261120_112233',
    'createdAtMillis': 1731900000000,
    'paymentConfirmedAtMillis': 1731900500000,
    'cancelledAtMillis': 1731905000000,
  });

  @override
  Future<PaymentReviewPage> load({String? afterId}) async {
    return PaymentReviewPage([reviewableRecord, completedRecord]);
  }

  @override
  Future<PaymentReviewDetail> detail(String bookingId) async {
    if (bookingId == completedRecord.id) {
      return PaymentReviewDetail(
        completedRecord,
        events: [
          {
            'source': 'billplz',
            'type': 'payment.cleared',
            'createdAtMillis': 1731900500000,
            'details': {'amountMinor': 12000, 'method': 'visa'},
          },
          {
            'source': 'gainpath',
            'type': 'refund.requested',
            'createdAtMillis': 1731905000000,
            'details': {'reason': 'Session cancelled within policy window'},
          },
          {
            'source': 'admin',
            'type': 'refund.approved',
            'createdAtMillis': 1731906000000,
            'details': {'author': 'Finance Admin', 'notes': 'Policy verified'},
          },
          {
            'source': 'billplz',
            'type': 'payout.completed',
            'createdAtMillis': 1731910000000,
            'details': {'reference': 'ref-exec-202611-089'},
          },
        ],
      );
    }

    return PaymentReviewDetail(
      reviewableRecord,
      events: [
        {
          'source': 'xendit',
          'type': 'payment.cleared',
          'createdAtMillis': 1732000500000,
          'details': {'amountMinor': 16000, 'method': 'fpx'},
        },
        {
          'source': 'gainpath',
          'type': 'refund.requested',
          'createdAtMillis': 1732005000000,
          'details': {'reason': 'Coach emergency medical conflict'},
        },
      ],
    );
  }

  @override
  Future<PaymentReviewDetail> manage(
    String bookingId,
    String action, {
    required String requestId,
    String? reason,
    String? billId,
    String? refundOrderId,
  }) async {
    return detail(bookingId);
  }
}

void main() {
  testWidgets('Render and capture screenshot artifacts for Refund Review Redesign',
      (tester) async {
    final resetFonts = await installFypOfflineFonts();
    addTearDown(resetFonts);

    final buildDir = Directory('../../build/admin-refund-review-redesign')
      ..createSync(recursive: true);
    final brainDir = Directory(
        'C:/Users/Ngzhe/.gemini/antigravity/brain/2e9bce9b-03ec-4533-aa97-83c6a91f9314')
      ..createSync(recursive: true);

    Future<void> capture(GlobalKey key, String name) async {
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        await File('${buildDir.path}/$name').writeAsBytes(bytes);
        await File('${brainDir.path}/$name').writeAsBytes(bytes);
        image.dispose();
      });
    }

    final repo = RenderMockRepo();

    // 1. Refund Requests List at 1280x800
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_requests_list_1280.png');
    }

    // 2. Refund Requests Quick Drawer overlay at 1280x800
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open drawer via Quick preview
      await tester.tap(find.byTooltip('Quick preview').first);
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_requests_quick_drawer_1280.png');
    }

    // 3. Dedicated Review Page at 1280x900
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open Dedicated Review Page
      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_review_page_1280.png');
    }

    // 4. Dedicated Review Page at 1536x960
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1536, 960);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_review_page_1536.png');
    }

    // 5. Dedicated Review Page at 1024x768
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Review'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_review_page_1024.png');
    }

    // 6. Dedicated Review Page Completed Record at 1280x900
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      // Open completed record via View Details
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // In the drawer, tap Open Full Review to see completed review page
      await tester.tap(find.text('Open Full Review'));
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_review_page_completed_1280.png');
    }

    // 7. Dedicated Review Page Mobile 390x844
    {
      tester.view.resetPhysicalSize();
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;

      final key = GlobalKey();
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            body: RefundsScreen(
              key: UniqueKey(),
              mode: PaymentsMode.refunds,
              repository: repo,
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Review').first);
      await tester.tap(find.text('Review').first);
      await tester.pumpAndSettle();

      await capture(key, 'admin_refund_review_page_mobile_390.png');
    }

    tester.view.reset();
  });
}
