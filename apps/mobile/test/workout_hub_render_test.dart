import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/features/workout/application/published_routine_catalog_cubit.dart';
import 'package:gainpath_mobile/features/workout/domain/published_routine_view.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/published_routine_catalog_controls.dart';
import 'package:gainpath_mobile/features/workout/presentation/member/workout_prep_screen.dart';

void main() {
  for (final variant in [
    (name: '', size: const Size(390, 844), scale: 1.0, dark: false),
    (name: 'large-', size: const Size(320, 640), scale: 2.0, dark: false),
    (name: 'large390-', size: const Size(390, 844), scale: 2.0, dark: false),
    (name: 'dark-', size: const Size(390, 844), scale: 1.0, dark: true),
  ]) {
    testWidgets('render workout hub preview ${variant.name}', (tester) async {
      Future<void> loadFont(String family, List<String> paths) async {
        final loader = FontLoader(family);
        for (final path in paths) {
          loader.addFont(
              File(path).readAsBytes().then((b) => ByteData.sublistView(b)));
        }
        await loader.load();
      }

      await tester.runAsync(() async {
        await loadFont('MaterialIcons', [
          'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'
        ]);
        await loadFont('Barlow', [
          'assets/fonts/Barlow-Regular.ttf',
          'assets/fonts/Barlow-SemiBold.ttf',
          'assets/fonts/Barlow-Bold.ttf'
        ]);
        await loadFont('BarlowCondensed', [
          'assets/fonts/BarlowCondensed-Regular.ttf',
          'assets/fonts/BarlowCondensed-SemiBold.ttf',
          'assets/fonts/BarlowCondensed-Bold.ttf'
        ]);
      });
      tester.view.physicalSize = variant.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final routine = PublishedRoutine.fromDocument('preview', {
        'schemaVersion': 1,
        'kind': 'routine',
        'status': 'published',
        'sourceBlueprintId': 'preview',
        'title': 'Full Body Strength',
        'estimatedMinutes': 25,
        'exercises': [
          {'exerciseId': 'squat', 'name': 'Squat', 'sets': 3, 'reps': 10},
          {
            'exerciseId': 'press',
            'name': 'Dumbbell Shoulder Press',
            'sets': 3,
            'reps': 10
          },
          {
            'exerciseId': 'calf',
            'name': 'Standing Calf Raise',
            'sets': 2,
            'reps': 15
          },
          {'exerciseId': 'plank', 'name': 'Plank', 'sets': 2, 'reps': 10},
        ],
      });
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Barlow',
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xff5c19d9),
              brightness: variant.dark ? Brightness.dark : Brightness.light),
          textTheme: const TextTheme(
              titleLarge: TextStyle(
                  fontFamily: 'BarlowCondensed',
                  fontWeight: FontWeight.bold,
                  fontSize: 22)),
        ),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(variant.scale)),
            child: child!),
        home: RepaintBoundary(
            key: key,
            child: Scaffold(
              body: WorkoutPrepScreen(
                  live: true,
                  publishedRoutine: routine,
                  onOpenPrograms: () {},
                  onOpenEquipment: () {},
                  onBrowseEquipment: () {},
                  onOpenProgress: () {},
                  onOpenRoutineHistory: () {},
                  onOpenSettings: () {},
                  routineCatalogControls: PublishedRoutineCatalogControls(
                      state: PublishedRoutineCatalogState(
                          status: CatalogStatus.ready,
                          items: [routine],
                          selected: routine),
                      onRefresh: () async {},
                      onSelect: (_) {},
                      onLoadMore: () async {})),
              bottomNavigationBar:
                  NavigationBar(selectedIndex: 1, destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.home_outlined), label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.fitness_center), label: 'Workout'),
                NavigationDestination(
                    icon: Icon(Icons.emoji_events_outlined), label: 'Rewards'),
                NavigationDestination(
                    icon: Icon(Icons.people_outline), label: 'Coaches'),
                NavigationDestination(
                    icon: Icon(Icons.person_outline), label: 'Profile'),
              ]),
            )),
      ));
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/images/workout_hub_fallback.png'),
          key.currentContext!));
      await tester.pumpAndSettle();
      final directory = Directory('build/member-workout-hub-preview');
      directory.createSync(recursive: true);
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${directory.path}/${variant.name}$name.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('top');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -170));
      await tester.pumpAndSettle();
      await capture('middle');
      await tester.scrollUntilVisible(find.text('Browse equipment'), 400,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      await capture('bottom');
      expect(tester.takeException(), isNull);
    }, skip: !const bool.fromEnvironment('GAINPATH_RENDER_WORKOUT_HUB'));
  }
}
