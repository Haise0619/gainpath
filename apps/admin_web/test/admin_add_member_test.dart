import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/members_screen.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';

import '../../../test_support/fyp_render_support.dart';

class _Directory implements AdminMemberDirectoryRepository {
  bool created = false;
  int reads = 0;
  @override
  Future<AdminMemberPage> loadPage(
      {String query = '', String status = 'All', String? afterId}) async {
    reads++;
    const old = AdminMemberRecord(
        id: 'fixture-old',
        name: 'Existing Fixture',
        email: 'existing@example.test',
        status: 'active');
    const member = AdminMemberRecord(
        id: 'fixture-new',
        name: 'New Fixture Member',
        email: 'new@example.test',
        status: 'active');
    if (query.isNotEmpty) {
      return AdminMemberPage([
        if (created && member.email.contains(query.toLowerCase())) member,
      ]);
    }
    return afterId == 'page-2'
        ? AdminMemberPage([if (created) member])
        : AdminMemberPage([if (created) member, old], nextCursor: 'page-2');
  }

  @override
  Future<AdminMemberDetails> loadDetails(String memberId) async =>
      AdminMemberDetails(
        member: const AdminMemberRecord(
            id: 'fixture-new',
            name: 'New Fixture Member',
            email: 'new@example.test',
            status: 'active'),
        organizationId: 'fixture-org',
        branchIds: ['east'],
      );
}

void main() {
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
    final font = File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (font.existsSync()) {
      final bytes = ByteData.sublistView(font.readAsBytesSync());
      await (FontLoader('MaterialIcons')..addFont(Future.value(bytes))).load();
    }
  });

  testWidgets(
      'Admin creates a member through the directory modal and refreshes',
      (tester) async {
    final restoreFonts = await installFypOfflineFonts();
    addTearDown(restoreFonts);
    tester.view.physicalSize = const Size(800, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final directory = _Directory();
    final capture = GlobalKey();
    final requests = <Map<String, Object?>>[];
    var pending = Completer<Map<String, dynamic>>();

    Future<void> screenshot(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_ADD_MEMBER')) return;
      final boundary =
          tester.renderObject<RenderRepaintBoundary>(find.byKey(capture));
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file =
            File('../../build/admin-member-provisioning/fixture-$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(RepaintBoundary(
      key: capture,
      child: RepositoryProvider<AdminMemberDirectoryRepository>.value(
        value: directory,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: Scaffold(
              body: MembersScreen(
            live: true,
            branchRequest: (input) async => {
              'records': [
                {
                  'branchId': 'main',
                  'displayName': 'Fixture Main Branch',
                  'status': 'active'
                },
                {
                  'branchId': 'east',
                  'displayName': 'Fixture East Branch',
                  'status': 'active'
                },
                {
                  'branchId': 'closed',
                  'displayName': 'Fixture Archived Branch',
                  'status': 'archived'
                },
              ]
            },
            memberSetup: (input) async {
              if (input['action'] == 'describe') {
                return {
                  'members': [
                    for (final id in input['memberIds'] as List)
                      {
                        'memberId': id,
                        'homeBranchId': id == 'fixture-new' ? 'east' : 'main',
                        'branchName': id == 'fixture-new'
                            ? 'Fixture East Branch'
                            : 'Fixture Main Branch',
                        'membership': 'free',
                        'accountStatus':
                            id == 'fixture-new' ? 'pendingSetup' : 'active',
                        'canResend': id == 'fixture-new'
                      },
                  ],
                };
              }
              requests.add(input);
              return pending.future;
            },
          )),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add Member'), findsOneWidget);
    await screenshot('01-member-directory');
    await tester.tap(find.text('Add Member'));
    await tester.pumpAndSettle();
    expect(find.text('Add New Member'), findsOneWidget);
    expect(find.text('Free Plan'), findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).autofocus, true);
    await screenshot('02-add-member-modal');
    await tester.tap(find.text('Create Member'));
    await tester.pumpAndSettle();
    expect(find.text('Enter the full name.'), findsOneWidget);
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    await tester.enterText(
        find.byType(TextFormField).at(0), 'New Fixture Member');
    await tester.enterText(
        find.byType(TextFormField).at(1), 'new@example.test');
    final branch = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(branch);
    await tester.tap(branch);
    await tester.pumpAndSettle();
    expect(find.text('Fixture Archived Branch'), findsNothing);
    await screenshot('03-select-home-branch');
    await tester.tap(find.text('Fixture East Branch').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Member'));
    await tester.pump();
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Create Member'))
            .onPressed,
        isNull);
    expect(requests.single['homeBranchId'], 'east');
    pending.completeError(FirebaseFunctionsException(
        code: 'already-exists', message: 'duplicate'));
    await tester.pumpAndSettle();
    expect(
        find.text('This email already belongs to an account.'), findsOneWidget);

    pending = Completer<Map<String, dynamic>>();
    await tester.tap(find.text('Create Member'));
    await tester.pump();
    directory.created = true;
    pending.complete({
      'memberId': 'fixture-new',
      'displayName': 'New Fixture Member',
      'branchName': 'Fixture East Branch',
      'accountStatus': 'pending',
      'delivery': 'failed',
    });
    await tester.pumpAndSettle();
    expect(find.text('Member created successfully.'), findsOneWidget);
    expect(find.text('Account Status: Pending setup'), findsOneWidget);
    expect(
        find.textContaining('setup email could not be sent'), findsOneWidget);
    await screenshot('04-member-created');
    await tester.tap(find.text('Back to Members'));
    await tester.pumpAndSettle();
    expect(directory.reads, greaterThanOrEqualTo(2));
    expect(find.text('New Fixture Member'), findsOneWidget);
    expect(find.text('Fixture East Branch · Free membership'), findsOneWidget);
    await screenshot('05-new-member-on-list');
    await tester.tap(find.text('All home branches'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fixture East Branch').last);
    await tester.pumpAndSettle();
    expect(find.text('New Fixture Member'), findsOneWidget);
    expect(find.text('Existing Fixture'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
