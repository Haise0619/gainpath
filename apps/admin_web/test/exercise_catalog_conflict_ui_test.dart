import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class _Baseline extends TutorialEditBaseline {}

class _Catalog implements TutorialRepository {
  final baseline = _Baseline();
  Object failure = const TutorialEditConflict();
  TutorialVideo? received;
  int loads = 0;
  @override
  bool get requiresCatalogSelection => true;
  @override
  List<TutorialVideo> get tutorials => [
        TutorialVideo(
            id: 'stable',
            title: 'Squat',
            category: 'Compound Lower-Body',
            status: TutorialStatus.active,
            videoUrl: 'https://example.test/video.mp4',
            editBaseline: baseline)
      ];
  @override
  Future<List<TutorialVideo>> load() async {
    loads++;
    return tutorials;
  }

  @override
  Future<TutorialVideo> save(TutorialVideo tutorial) async {
    received = tutorial;
    throw failure;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<_Catalog> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = _Catalog();
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.build(), home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Squat'));
    await tester.pumpAndSettle();
    return catalog;
  }

  Future<void> save(WidgetTester tester) async {
    final button = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'conflict preserves baseline, blocks retry and explicitly reloads',
      (tester) async {
    final catalog = await open(tester);
    await save(tester);
    expect(catalog.received!.id, 'stable');
    expect(identical(catalog.received!.editBaseline, catalog.baseline), isTrue);
    expect(find.text(const TutorialEditConflict().toString()), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNull);
    await tester.tap(find.text('Discard edits and reload catalog'));
    await tester.pumpAndSettle();
    expect(catalog.loads, 2);
    expect(find.text('Edit exercise'), findsNothing);
  });
  testWidgets('session rejection blocks saves with safe message',
      (tester) async {
    final catalog = await open(tester);
    catalog.failure = const TutorialEditAuthorizationChanged();
    await save(tester);
    expect(find.text(const TutorialEditAuthorizationChanged().toString()),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNull);
  });
  testWidgets('transport errors never render raw private detail',
      (tester) async {
    final catalog = await open(tester);
    // Deliberately avoid real or token-bearing media URLs even in fixtures.
    catalog.failure = StateError('private-media-credential-sentinel');
    await save(tester);
    expect(
        find.textContaining('private-media-credential-sentinel'), findsNothing);
    expect(find.text('Could not save exercise. Please try again.'),
        findsOneWidget);
  });
}
