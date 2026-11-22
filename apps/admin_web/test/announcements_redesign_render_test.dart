import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/announcements_screen.dart';
import 'package:gainpath_domain/content.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

class _TestContentRepository extends ContentRepository {
  _TestContentRepository(this.announcements);
  @override
  final List<Announcement> announcements;
}

void main() {
  testWidgets('Render redesigned Announcement Management Hub and Composer',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final announcements = [
      Announcement(
        id: 'ann-1',
        title: 'Public Holiday Operating Hours',
        body:
            'All gym locations operate on holiday hours (8:00 AM – 8:00 PM). Group classes proceed as scheduled.',
        validFrom: now.subtract(const Duration(days: 2)),
        validTo: now.add(const Duration(days: 5)),
        status: AnnouncementStatus.published,
        category: AnnouncementCategory.general,
        priority: AnnouncementPriority.normal,
        audience: AnnouncementAudience.all,
      ),
      Announcement(
        id: 'ann-2',
        title: 'Sauna & Aquatic Center Maintenance',
        body:
            'Routine equipment servicing and tile replacement in progress. Facilities will reopen at 6:00 AM tomorrow.',
        validFrom: now.subtract(const Duration(days: 1)),
        validTo: now.add(const Duration(days: 2)),
        status: AnnouncementStatus.published,
        category: AnnouncementCategory.maintenance,
        priority: AnnouncementPriority.important,
        audience: AnnouncementAudience.branches,
        targetBranchIds: const ['main', 'east'],
        targetBranchNames: const ['Central Gym', 'East Gym'],
      ),
      Announcement(
        id: 'ann-3',
        title: 'Annual Strength Championship 2026',
        body:
            'Registration is now open at the member service counter. Early bird entry closes next Friday.',
        validFrom: now.add(const Duration(days: 5)),
        validTo: now.add(const Duration(days: 15)),
        status: AnnouncementStatus.published,
        category: AnnouncementCategory.event,
        priority: AnnouncementPriority.normal,
        audience: AnnouncementAudience.all,
      ),
      Announcement(
        id: 'ann-4',
        title: 'Personal Training Holiday Package',
        body:
            'Book 10 private coaching sessions and receive 2 complimentary body composition consultations.',
        validFrom: now,
        validTo: now.add(const Duration(days: 30)),
        status: AnnouncementStatus.draft,
        category: AnnouncementCategory.promotion,
        priority: AnnouncementPriority.normal,
        audience: AnnouncementAudience.branches,
        targetBranchIds: const ['main'],
        targetBranchNames: const ['Central Gym'],
      ),
      Announcement(
        id: 'ann-5',
        title: 'HVAC Air Filter Replacement Completed',
        body:
            'All filtration systems in the free-weight zone have been upgraded to HEPA-13 standards.',
        validFrom: now.subtract(const Duration(days: 14)),
        validTo: now.subtract(const Duration(days: 7)),
        status: AnnouncementStatus.published,
        category: AnnouncementCategory.update,
        priority: AnnouncementPriority.normal,
        audience: AnnouncementAudience.all,
      ),
      Announcement(
        id: 'ann-6',
        title: 'Towel Service Token System (Suspended)',
        body:
            'The experimental physical token policy has been deactivated per member feedback.',
        validFrom: now.subtract(const Duration(days: 20)),
        validTo: now.subtract(const Duration(days: 10)),
        status: AnnouncementStatus.inactive,
        category: AnnouncementCategory.closure,
        priority: AnnouncementPriority.normal,
        audience: AnnouncementAudience.all,
      ),
    ];

    final repo = _TestContentRepository(announcements);

    Future<void> savePng(Finder finder, String filename) async {
      await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
        final image = await boundary.toImage(pixelRatio: 1.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();

        final file = File('../../build/announcements-redesign/$filename');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes);
        image.dispose();
      });
    }

    const surfaceKey = Key('announcements-render-surface');

    // 1. Render Announcement Management Dashboard (1440x960)
    await tester.pumpWidget(
      RepositoryProvider<ContentRepository>.value(
        value: repo,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(),
          home: RepaintBoundary(
            key: surfaceKey,
            child: const ColoredBox(
              color: AppColors.bg,
              child: AnnouncementsScreen(
                loadBranches: _dummyBranches,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Dashboard layout & KPI numbers
    expect(find.text('Announcements'), findsAtLeastNWidgets(1));
    expect(find.text('Create and publish updates across your gym locations.'),
        findsOneWidget);
    expect(find.text('Total announcements'), findsOneWidget);
    expect(find.text('6'), findsNWidgets(2));
    expect(find.text('Active'), findsAtLeastNWidgets(1));
    expect(find.text('2'), findsAtLeastNWidgets(1));
    expect(find.text('Scheduled'), findsAtLeastNWidgets(1));
    expect(find.text('1'), findsAtLeastNWidgets(1));
    expect(find.text('Drafts'), findsAtLeastNWidgets(1));

    // Save Dashboard Screenshot
    await savePng(find.byKey(surfaceKey), 'announcement_management_dashboard_1440.png');

    // 2. Open Composer (New Announcement)
    await tester.tap(find.text('New announcement'));
    await tester.pumpAndSettle();

    expect(find.text('New announcement'), findsAtLeastNWidgets(1));
    expect(find.text('Back to Announcements'), findsOneWidget);
    expect(find.text('Message content'), findsOneWidget);
    expect(find.text('Target audience'), findsOneWidget);
    expect(find.text('Publishing schedule'), findsOneWidget);
    expect(find.text('Member app preview'), findsOneWidget);
    expect(find.text('Publication summary'), findsOneWidget);

    // Enter title & body
    await tester.enterText(
        find.byType(TextField).first, 'Festive Holiday Operating Hours');
    await tester.enterText(
        find.byType(TextField).last,
        'All facilities will close at 6:00 PM on Christmas Eve and reopen on Boxing Day at 8:00 AM.');
    await tester.pumpAndSettle();

    // Save New Composer Screenshot
    await savePng(find.byKey(surfaceKey), 'announcement_composer_new_1440.png');

    // 3. Select Specific Branches (Central Gym, East Gym, West Gym)
    await tester.tap(find.text('Specific branches'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Central Gym'));
    await tester.tap(find.widgetWithText(FilterChip, 'Central Gym'));
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'East Gym'));
    await tester.tap(find.widgetWithText(FilterChip, 'East Gym'));
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'West Gym'));
    await tester.tap(find.widgetWithText(FilterChip, 'West Gym'));
    await tester.pumpAndSettle();

    expect(find.textContaining('3 selected (max 8)'), findsOneWidget);

    // Save Specific Branches Composer Screenshot
    await savePng(find.byKey(surfaceKey), 'announcement_composer_branches_1440.png');

    // 4. Switch to Scheduled Publication
    await tester.ensureVisible(find.text('Schedule publication'));
    await tester.tap(find.text('Schedule publication'));
    await tester.pumpAndSettle();

    // Save Scheduled Publication Composer Screenshot
    await savePng(find.byKey(surfaceKey), 'announcement_composer_scheduled_1440.png');

    // 5. Save Mobile Preview Card Screenshot
    await savePng(find.byKey(const Key('announcement-mobile-preview')),
        'announcement_mobile_preview_card.png');

    // Cancel composer and return to list
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard announcement changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Total announcements'), findsOneWidget);

    // 6. Responsive Viewport Tests (1920x1080, 1536x864, 1366x768, 1280x720, 768x1024)
    for (final size in [
      const Size(1920, 1080),
      const Size(1536, 864),
      const Size(1366, 768),
      const Size(1280, 720),
      const Size(768, 1024),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpAndSettle();
      expect(find.text('Announcements'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
    }
  });
}

Future<Map<String, ({String name, bool active})>> _dummyBranches() async {
  return const {
    'main': (name: 'Central Gym', active: true),
    'east': (name: 'East Gym', active: true),
    'west': (name: 'West Gym', active: true),
    'north': (name: 'North Gym', active: true),
    'old': (name: 'Old Gym', active: false),
  };
}
