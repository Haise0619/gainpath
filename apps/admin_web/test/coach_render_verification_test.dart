import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coaches_screen.dart';
import 'package:gainpath_admin_web/features/identity/presentation/admin/coach_provision_page.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_data/identity.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

const _testSession = AuthSession(
  userId: 'render-admin',
  organizationId: 'gainpath',
  branchIds: ['gainpath-2', 'main'],
  displayName: 'Admin User',
  email: 'admin@gainpath.com',
  role: AppRole.admin,
);

class _RenderCoachRepo implements CoachProfileAdminRepository {
  @override
  SessionScope get scope => _testSession.scope;

  @override
  Future<bool> canManageDirectory() async => true;

  @override
  Future<CoachDirectoryPage<CoachProfessionalProfile>> loadDraftPage(
      {String? afterId}) async {
    return CoachDirectoryPage([
      CoachProfessionalProfile(
        id: 'coach-mickey',
        fields: CoachProfessionalFields(
          displayName: 'Mickey',
          specialty: 'Power',
          bio: 'Powerlifting and strength trainer',
          specializationTags: ['Power'],
          yearsExperience: 3,
        ),
        revision: 1,
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
      ),
    ]);
  }

  @override
  Future<CoachDirectoryPage<PublishedCoachProfile>> loadPublicPage(
      {String? afterId}) async {
    return CoachDirectoryPage([
      PublishedCoachProfile(
        id: 'coach-jackson',
        fields: CoachProfessionalFields(
          displayName: 'Jackson',
          specialty: 'professor',
          bio: 'Professor of human physiology and sports science',
          specializationTags: ['professor'],
          yearsExperience: 2,
        ),
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: const ['gainpath-2', 'main'],
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
        publishedAtMillis: 2000,
      ),
      PublishedCoachProfile(
        id: 'coach-sarah',
        fields: CoachProfessionalFields(
          displayName: 'Sarah Jenkins',
          specialty: 'Conditioning',
          bio: 'High-intensity interval and athletic conditioning specialist',
          specializationTags: ['Conditioning', 'Cardio'],
          yearsExperience: 4,
        ),
        revision: 1,
        sourceRevision: 1,
        status: 'published',
        branchIds: const ['gainpath-2'],
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
        publishedAtMillis: 2000,
      ),
      PublishedCoachProfile(
        id: 'coach-synthetic',
        fields: CoachProfessionalFields(
          displayName: '[DISPOSABLE UAT] Coach cert...',
          specialty: 'Synthetic UAT',
          bio: 'Synthetic profile for certification UAT test flows',
          specializationTags: ['Synthetic UAT'],
          yearsExperience: 1,
        ),
        revision: 1,
        sourceRevision: 1,
        status: 'inactive',
        branchIds: const ['main'],
        createdAtMillis: 1000,
        updatedAtMillis: 2000,
        publishedAtMillis: 2000,
      ),
    ]);
  }

  @override
  Future<CoachPublicationReview> loadReview(String coachId) async {
    throw UnimplementedError();
  }

  @override
  Future<CoachCommandResult> setStatus({
    required CoachPublicationReview baseline,
    required CoachDirectoryAction action,
    String? reason,
    String? requestId,
  }) async {
    throw UnimplementedError();
  }
}

void main() {
  testWidgets('Render redesigned Coach Directory and full-width Coach Provision wizard',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final boundaryKey = GlobalKey();
    final repo = _RenderCoachRepo();

    Future<void> savePng(GlobalKey key, String filename) async {
      await tester.runAsync(() async {
        final boundary = tester
            .renderObject<RenderRepaintBoundary>(find.byKey(key));
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final file = File('../../build/coach-redesign/$filename');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        image.dispose();
      });
    }

    // 1. Render Coach Directory Grid
    await tester.pumpWidget(
      MultiRepositoryProvider(
        providers: [
          RepositoryProvider<CoachProfileAdminRepository>.value(value: repo),
          RepositoryProvider<UserAccountRepository>.value(
              value: InMemoryUserAccountRepository()),
          RepositoryProvider<CoachRepository>.value(
              value: InMemoryCoachRepository()),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: CoachesScreen(
                live: true,
                branchRequest: (req) async {
                  return {
                    'records': [
                      {'branchId': 'gainpath-2', 'displayName': 'GainPath 2', 'status': 'active'},
                      {'branchId': 'main', 'displayName': 'Main Branch', 'status': 'active'},
                    ],
                  };
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coach Management'), findsOneWidget);
    expect(find.text('Jackson'), findsOneWidget); // Deduplicated! Only 1 Jackson!
    expect(find.text('Mickey'), findsOneWidget);
    expect(find.text('Sarah Jenkins'), findsOneWidget);
    // Crucial: In "All Branches" mode, do not divide into branch sections
    expect(find.textContaining('GainPath 2  ·'), findsNothing);
    expect(find.textContaining('Main Branch  ·'), findsNothing);
    await savePng(boundaryKey, 'admin_coach_all_branches_unified_1440.png');
    await savePng(boundaryKey, 'admin_coach_grid_redesigned_1440.png');

    // 1b. Test filtering to "Main Branch"
    // Tap the branch dropdown pill
    await tester.tap(find.text('All Branches'));
    await tester.pumpAndSettle();

    // Verify there is strictly ONE "All Branches" option in the dropdown menu (no duplicate All Branches)
    expect(
        find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.text('All Branches')),
        findsOneWidget);

    // Select "Main Branch"
    await tester.tap(find.text('Main Branch').last);
    await tester.pumpAndSettle();

    // Verify Main Branch filter results:
    // - Shows Main Branch header
    expect(find.textContaining('Main Branch  ·  2'), findsOneWidget);
    // - NEVER shows GainPath 2 section
    expect(find.textContaining('GainPath 2  ·'), findsNothing);
    // - Jackson appears under Main Branch
    expect(find.text('Jackson'), findsOneWidget);
    // - Sarah Jenkins (only at GainPath 2) is filtered out
    expect(find.text('Sarah Jenkins'), findsNothing);
    await savePng(boundaryKey, 'admin_coach_main_branch_filtered_1440.png');

    // Reset back to All Branches for sanity
    await tester.tap(find.byKey(const ValueKey('coach-filter-branch')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(PopupMenuItem<String>),
            matching: find.text('All Branches')),
        findsOneWidget);
    await tester.tap(find.descendant(
        of: find.byType(PopupMenuItem<String>),
        matching: find.text('All Branches')));
    await tester.pumpAndSettle();
    expect(find.text('Sarah Jenkins'), findsOneWidget);

    // 2. Render Full-Width Coach Provision Wizard (Step 0)
    final wizardBoundary = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: RepaintBoundary(
          key: wizardBoundary,
          child: Scaffold(
            backgroundColor: const Color(0xFFF8FAFC),
            body: CoachProvisionPage(
              branches: const {
                'gainpath-2': 'GainPath 2',
                'main': 'Main Branch',
              },
              create: (map) async => 'new-coach-id',
              onCancel: () {},
              onCreated: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await savePng(wizardBoundary, 'admin_coach_provision_fullwidth_1440.png');

    // 3. Fill in basic details and proceed to Step 1 (Live preview)
    final textFields = find.byType(TextField);
    await tester.enterText(textFields.at(0), 'Coach Alex Tan');
    await tester.enterText(textFields.at(1), 'alex.tan@gainpath.com');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('2 of 3 · Professional profile'), findsOneWidget);
    expect(find.text('Live Profile Preview'), findsOneWidget);

    await savePng(wizardBoundary, 'admin_coach_provision_step2_fullwidth_1440.png');
  });
}
