import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/member_provision_page.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets(
      'Render redesigned Add Member experience, verify states, and capture verification PNGs',
      (tester) async {
    final resetFonts = await installFypOfflineFonts();
    addTearDown(resetFonts);

    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final outDir = Directory('../../build/admin-add-member-20261122');
    if (!outDir.existsSync()) {
      outDir.createSync(recursive: true);
    }

    final captureKey = GlobalKey();

    Future<void> saveScreenshot(String filename) async {
      await tester.pump();
      await tester.runAsync(() async {
        final boundary =
            tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
        final image = await boundary.toImage();
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        await File('${outDir.path}/$filename').writeAsBytes(bytes);
        image.dispose();
      });
    }

    final branches = <MemberBranch>[
      (id: 'main', name: 'GainPath Central Gym', active: true),
      (id: 'east', name: 'GainPath East Branch', active: true),
      (id: 'north', name: 'GainPath North Hub', active: true),
      (id: 'closed', name: 'GainPath Archived Branch', active: false),
    ];

    Completer<Map<String, dynamic>> pendingRequest =
        Completer<Map<String, dynamic>>();

    Widget buildApp({String? homeBranchId, Key? key}) {
      return RepaintBoundary(
        key: captureKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
            backgroundColor: AppColors.bg,
            body: MemberProvisionPage(
              key: key,
              request: (input) => pendingRequest.future,
              loadBranches: () async => branches,
              homeBranchId: homeBranchId,
              onClose: (_) {},
            ),
          ),
        ),
      );
    }

    // 1. Initial Desktop View (1440x900)
    await tester.pumpWidget(buildApp(key: const ValueKey('initial-form')));
    await tester.pumpAndSettle();

    expect(find.text('Add New Member'), findsOneWidget);
    expect(find.text('Back to Members'), findsOneWidget);
    expect(find.text('Personal information'), findsOneWidget);
    expect(find.text('Branch assignment'), findsOneWidget);
    expect(find.text('Account Setup Summary'), findsOneWidget);
    expect(find.text('Initial membership'), findsOneWidget);
    expect(find.text('Free Plan'), findsOneWidget);
    expect(find.text('Create Member'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Verify 65% / 35% two-column layout on 1440px
    expect(tester.getTopLeft(find.text('Free Plan')).dx,
        greaterThan(tester.getTopRight(find.byType(TextFormField).first).dx));

    await saveScreenshot('add_member_desktop_initial_1440.png');

    // 2. Trigger Inline Validation Errors
    await tester.tap(find.text('Create Member'));
    await tester.pumpAndSettle();

    expect(find.text('Enter the full name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Select an active home branch.'), findsOneWidget);

    await saveScreenshot('add_member_validation_errors_1440.png');

    // 3. Open Home Branch Selector Dropdown
    final branchDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(branchDropdown);
    await tester.tap(branchDropdown);
    await tester.pumpAndSettle();

    // Verify inactive branch is filtered out
    expect(find.text('GainPath Archived Branch'), findsNothing);
    expect(find.text('GainPath Central Gym'), findsWidgets);
    expect(find.text('GainPath East Branch'), findsWidgets);
    expect(find.text('Active'), findsWidgets);

    await saveScreenshot('add_member_branch_selector_1440.png');

    // Select GainPath East Branch
    await tester.tap(find.text('GainPath East Branch').last);
    await tester.pumpAndSettle();

    // Enter valid details
    await tester.enterText(
        find.byType(TextFormField).at(0), 'Sarah Jenkins');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'sarah.jenkins@gainpath.test');
    await tester.enterText(
        find.byType(TextFormField).at(2), '+60 12-345 6789');
    await tester.pumpAndSettle();

    await saveScreenshot('add_member_account_summary_1440.png');

    // 4. Server-Side Duplicate Email Error State
    await tester.tap(find.text('Create Member'));
    await tester.pump();

    pendingRequest.completeError(FirebaseFunctionsException(
      code: 'already-exists',
      message: 'This email already belongs to an account.',
    ));
    await tester.pumpAndSettle();

    expect(
        find.text('This email already belongs to an account.'), findsOneWidget);
    await saveScreenshot('add_member_error_state_1440.png');

    // 5. Successful Creation with Email Delivery Failure (Recoverable state)
    pendingRequest = Completer<Map<String, dynamic>>();
    await tester.tap(find.text('Create Member'));
    await tester.pump();

    pendingRequest.complete({
      'memberId': 'mbr-fixture-01',
      'displayName': 'Sarah Jenkins',
      'branchName': 'GainPath East Branch',
      'accountStatus': 'pending',
      'delivery': 'failed',
    });
    await tester.pumpAndSettle();

    expect(find.text('Member created successfully.'), findsOneWidget);
    expect(find.text('Account Status: Pending setup'), findsOneWidget);
    expect(
        find.textContaining('setup email could not be sent'), findsOneWidget);
    expect(find.text('Resend Setup Email'), findsOneWidget);
    expect(find.text('View Member'), findsOneWidget);

    await saveScreenshot('add_member_success_failed_email_1440.png');

    // 6. Successful Creation with Brevo Sent Delivery
    pendingRequest = Completer<Map<String, dynamic>>();
    // Reset view for clean sent state
    await tester.pumpWidget(buildApp(homeBranchId: 'main', key: const ValueKey('sent-member')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byType(TextFormField).at(0), 'Michael Tan');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'michael.tan@gainpath.test');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create Member'));
    await tester.pump();

    pendingRequest.complete({
      'memberId': 'mbr-fixture-02',
      'displayName': 'Michael Tan',
      'branchName': 'GainPath Central Gym',
      'accountStatus': 'pending',
      'delivery': 'sent',
    });
    await tester.pumpAndSettle();

    expect(find.text('Member created successfully.'), findsOneWidget);
    expect(find.text('Brevo accepted the setup email for delivery.'),
        findsOneWidget);

    await saveScreenshot('add_member_success_sent_1440.png');

    // 7. Responsive Stacked Layout on Narrow Screen (800x900)
    tester.view.physicalSize = const Size(800, 900);
    await tester.pumpWidget(buildApp(homeBranchId: 'main', key: const ValueKey('narrow-viewport')));
    await tester.pumpAndSettle();

    // Verify stacked column: Free Plan is below the first TextFormField
    expect(tester.getTopLeft(find.text('Free Plan')).dy,
        greaterThan(tester.getBottomLeft(find.byType(TextFormField).first).dy));

    await saveScreenshot('add_member_responsive_800.png');

    // 8. Responsive Check across multiple resolutions
    const testResolutions = [
      Size(1920, 1080),
      Size(1536, 864),
      Size(1440, 900),
      Size(1366, 768),
      Size(1280, 720),
      Size(1024, 768),
      Size(768, 1024),
    ];

    for (final size in testResolutions) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(buildApp(key: ValueKey('res-${size.width}x${size.height}')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'No overflow at ${size.width}x${size.height}');
    }
  });
}
