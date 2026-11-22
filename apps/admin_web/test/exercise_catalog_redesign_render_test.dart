import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_catalog_list.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../../test_support/fyp_render_support.dart';

void main() {
  testWidgets('render redesigned exercise catalog at 1440, 1280, 1024',
      (tester) async {
    addTearDown(await installFypOfflineFonts());
    final icons = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(File(
              'C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf')
          .readAsBytesSync())));
    await icons.load();

    final exercises = [
      TutorialVideo(
        id: 'bodyweight-reverse-lunge-side-v1',
        title: 'Bodyweight Reverse Lunge',
        category: 'Compound Lower-Body',
        status: TutorialStatus.draft,
        archived: true,
        trackingCapability: ExerciseTrackingCapability.guidedOnly,
      ),
      TutorialVideo(
        id: '64e9314904d20a07b02447570a11ee2f',
        title: 'Burpee',
        category: 'Core',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.guidedOnly,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        defaultPrescription: const TimedPrescription(
            sets: 3, durationSeconds: 45, restSeconds: 60),
        mediaValidation: {'validated': true, 'resolution': '1080p'},
        videoUrl: 'https://example.com/burpee.mp4',
      ),
      TutorialVideo(
        id: 's1ERYwaBd19TqXoHpk2R',
        title: 'CRUD UAT 2026-10-15 - catalog edited',
        category: 'Compound Lower-Body',
        status: TutorialStatus.draft,
        archived: true,
        trackingCapability: ExerciseTrackingCapability.guidedOnly,
      ),
      TutorialVideo(
        id: 'dumbbell-shoulder-press-front-v1',
        title: 'Dumbbell Shoulder Press',
        category: 'Compound Upper-Body',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.frontViewShoulderPress,
        executionMode: ExerciseExecutionMode.aiTracked,
        defaultPrescription: const RepetitionPrescription(
            sets: 4, repetitions: 12, restSeconds: 90),
        videoUrl: 'https://example.com/press.mp4',
      ),
      TutorialVideo(
        id: 'barbell-back-squat-side-v1',
        title: 'Barbell Back Squat',
        category: 'Compound Lower-Body',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.sideViewSquat,
        executionMode: ExerciseExecutionMode.aiTracked,
        defaultPrescription: const RepetitionPrescription(
            sets: 4, repetitions: 8, restSeconds: 120),
        videoUrl: 'https://example.com/squat.mp4',
      ),
      TutorialVideo(
        id: 'standing-calf-raise-side-v1',
        title: 'Standing Calf Raise',
        category: 'Accessory',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.sideViewCalfRaise,
        executionMode: ExerciseExecutionMode.aiTracked,
        defaultPrescription: const RepetitionPrescription(
            sets: 3, repetitions: 15, restSeconds: 45),
      ),
      TutorialVideo(
        id: 'forearm-plank-timed-v1',
        title: 'Forearm Plank',
        category: 'Core',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.guidedOnly,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        defaultPrescription: const TimedPrescription(
            sets: 3, durationSeconds: 60, restSeconds: 30),
        videoUrl: 'https://example.com/plank.mp4',
      ),
      TutorialVideo(
        id: 'push-up-standard-side-v1',
        title: 'Standard Floor Push-Up',
        category: 'Compound Upper-Body',
        status: TutorialStatus.draft,
        trackingCapability: ExerciseTrackingCapability.sideViewFloorPushUp,
        executionMode: ExerciseExecutionMode.aiTracked,
        defaultPrescription: const RepetitionPrescription(
            sets: 3, repetitions: 10, restSeconds: 60),
      ),
    ];

    Widget buildConsole({required Widget child, required double width}) {
      return Container(
        color: AppColors.bg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Admin Sidebar (224px)
            Container(
              width: 224,
              color: Colors.white,
              child: Column(
                children: [
                  // Logo
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'GP',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'GainPath',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: AppColors.ink),
                            ),
                            Text(
                              'Admin Console',
                              style: TextStyle(
                                  fontSize: 10.5, color: AppColors.inkSoft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.hairline),
                  // Nav Items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 10),
                      children: [
                        _sidebarItem(
                            icon: Icons.dashboard_outlined,
                            label: 'Dashboard'),
                        _sidebarItem(
                            icon: Icons.people_outline,
                            label: 'Users & Coaches'),
                        _sidebarItem(
                            icon: Icons.auto_awesome_outlined,
                            label: 'Recommendations'),
                        _sidebarItem(
                            icon: Icons.payments_outlined,
                            label: 'Payments'),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(12, 16, 12, 6),
                          child: Text(
                            'CONTENT',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.inkSoft,
                                letterSpacing: 0.8),
                          ),
                        ),
                        _sidebarItem(
                            icon: Icons.fitness_center_rounded,
                            label: 'Exercise Catalog',
                            selected: true),
                        _sidebarItem(
                            icon: Icons.format_list_bulleted_rounded,
                            label: 'Routine Templates'),
                        _sidebarItem(
                            icon: Icons.calendar_month_outlined,
                            label: 'Workout Programs'),
                      ],
                    ),
                  ),
                  // User Profile Pill
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryTint,
                          child: const Text('AD',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ),
                        const SizedBox(width: 10),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Admin',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                            Text('admin@gainpath.com',
                                style: TextStyle(
                                    fontSize: 10.5, color: AppColors.inkSoft)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.hairline),

            // Main Content Area
            Expanded(
              child: Column(
                children: [
                  // Top Navbar (64px)
                  Container(
                    height: 64,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      children: [
                        Row(
                          children: const [
                            Text('Home',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.inkSoft)),
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.inkSoft),
                            Text('Content',
                                style: TextStyle(
                                    fontSize: 13, color: AppColors.inkSoft)),
                            Icon(Icons.chevron_right_rounded,
                                size: 16, color: AppColors.inkSoft),
                            Text('Exercise Catalog',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.ink)),
                          ],
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('GAINPATH / ADMIN',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.inkSoft)),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.notifications_none_rounded,
                            size: 20, color: AppColors.inkSoft),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.hairline),

                  // Content Pane
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final artifactDir = Directory('../../build/exercise-catalog-redesign');
    await artifactDir.create(recursive: true);

    for (final width in [1440.0, 1280.0, 1024.0]) {
      tester.view.physicalSize = Size(width, 920);
      tester.view.devicePixelRatio = 1;
      final key = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(),
            home: Scaffold(
              body: buildConsole(
                width: width,
                child: ExerciseCatalogList(
                  tutorials: exercises,
                  catalogOnly: true,
                  filter: null,
                  onFilter: (_) {},
                  onReload: () {},
                  onAdd: () {},
                  onEdit: (_) {},
                  onDelete: (_) {},
                  onStatusChange: (_, __) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.runAsync(() async {
        final renderObject =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await renderObject.toImage();
        final byteData =
            await image.toByteData(format: ui.ImageByteFormat.png);
        final bytes = byteData!.buffer.asUint8List();
        final file =
            File('\${artifactDir.path}/admin_exercise_catalog_${width.toInt()}.png');
        await file.writeAsBytes(bytes);
        image.dispose();
      });
    }
  });
}

Widget _sidebarItem(
    {required IconData icon, required String label, bool selected = false}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 2),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: selected ? AppColors.primaryTint : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon,
            size: 18, color: selected ? AppColors.primary : AppColors.inkSoft),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.primary : AppColors.ink,
          ),
        ),
      ],
    ),
  );
}
