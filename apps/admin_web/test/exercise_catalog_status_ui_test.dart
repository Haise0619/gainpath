import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_catalog_list.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';

class CatalogStatusFixture extends TutorialRepository
    implements TutorialArchivingRepository, TutorialCatalogStatusRepository {
  final entries = [
    TutorialVideo(
        id: 'active',
        title: 'Active row',
        category: 'Compound Upper-Body',
        status: TutorialStatus.active),
    TutorialVideo(
        id: 'inactive',
        title: 'Inactive row',
        category: 'Core',
        status: TutorialStatus.draft),
    TutorialVideo(
        id: 'archived',
        title: 'Archived row',
        category: 'Core',
        status: TutorialStatus.draft,
        archived: true),
  ];
  int changes = 0, loads = 0;
  Object? failure;
  @override
  List<TutorialVideo> get tutorials => entries;
  @override
  bool get requiresCatalogSelection => true;
  @override
  Future<List<TutorialVideo>> load() async {
    loads++;
    return List.of(entries);
  }

  @override
  Future<void> archive(TutorialVideo tutorial) async {
    changes++;
  }

  @override
  Future<TutorialVideo> setCatalogStatus(
      TutorialVideo tutorial, ExerciseCatalogStatus status) async {
    changes++;
    if (failure != null) throw failure!;
    final next = TutorialVideo(
        id: tutorial.id,
        title: tutorial.title,
        category: tutorial.category,
        status: status == ExerciseCatalogStatus.active
            ? TutorialStatus.active
            : TutorialStatus.draft,
        archived: status == ExerciseCatalogStatus.archived);
    entries[entries.indexWhere((t) => t.id == tutorial.id)] = next;
    return next;
  }
}

Future<void> openStatusCatalog(
    WidgetTester tester, CatalogStatusFixture catalog,
    {bool enabled = true}) async {
  await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
      value: catalog,
      child: MaterialApp(
          theme: AppTheme.build(),
          home: ExerciseTutorialsScreen(allowRemoval: enabled))));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'corrected calf candidate list and editor show provisional tracking',
      (tester) async {
    final repo = CatalogStatusFixture();
    repo.entries
      ..clear()
      ..add(TutorialVideo(
          id: 'standing-calf-raise-side-v1',
          title: 'Standing calf raise',
          category: 'Accessory',
          status: TutorialStatus.active,
          trackingCapability: ExerciseTrackingCapability.sideViewCalfRaise));
    await openStatusCatalog(tester, repo);
    expect(find.textContaining('AI tracking · Side view'), findsOneWidget);
    expect(find.textContaining('Tracking on hold'), findsNothing);
    await tester.tap(find.text('Standing calf raise'));
    await tester.pumpAndSettle();
    expect(find.text('AI tracking · Side view'), findsOneWidget);
    expect(
        find.textContaining('visible leg only · provisional'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('catalog labels registered shoulder press as front-view tracking',
      (tester) async {
    final repo = CatalogStatusFixture();
    repo.entries.clear();
    repo.entries.add(TutorialVideo(
        id: 'dumbbell-shoulder-press-front-v1',
        title: 'Dumbbell Shoulder Press',
        category: 'Compound Upper-Body',
        status: TutorialStatus.active,
        trackingCapability: ExerciseTrackingCapability.frontViewShoulderPress));
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: repo,
        child: const MaterialApp(home: ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI tracking · Front view'), findsOneWidget);
    expect(find.byTooltip('Delete exercise'), findsOneWidget);
  });
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets('inactive catalog editor uses the same status label as the list',
      (tester) async {
    await openStatusCatalog(tester, CatalogStatusFixture());
    await tester.ensureVisible(find.text('Inactive row'));
    await tester.tap(find.text('Inactive row'));
    await tester.pumpAndSettle();
    final status =
        find.widgetWithText(DropdownButtonFormField<String>, 'Status');
    await tester.ensureVisible(status);
    expect(find.descendant(of: status, matching: find.text('Inactive')),
        findsOneWidget);
  });
  testWidgets(
      'catalog exposes All Active Inactive Archived filters and retained archived rows',
      (tester) async {
    final catalog = CatalogStatusFixture();
    await openStatusCatalog(tester, catalog);
    expect(find.widgetWithText(ChoiceChip, 'All'), findsOneWidget);
    expect(find.text('Archived row'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ExerciseCatalogList>(find.byType(ExerciseCatalogList))
            .error,
        isNull);
    expect(find.text('Archived row'), findsOneWidget);
    expect(find.text('Active row'), findsNothing);
  });
  testWidgets(
      'Delete is visible and confirmation cancellation performs no write',
      (tester) async {
    final catalog = CatalogStatusFixture();
    await openStatusCatalog(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('exercise-delete-active')));
    await tester.pumpAndSettle();
    expect(find.textContaining('archives'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(catalog.changes, 0);
  });
  testWidgets(
      'confirmed Delete archives and Restore returns inactive before Activate',
      (tester) async {
    final catalog = CatalogStatusFixture();
    await openStatusCatalog(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('exercise-delete-active')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(catalog.entries.first.archived, true);
    expect(catalog.changes, 1);
    expect(catalog.entries.first.status, TutorialStatus.draft);
    expect(find.byKey(const ValueKey('exercise-delete-active')), findsNothing);
    expect(
        tester
            .widget<ExerciseCatalogList>(find.byType(ExerciseCatalogList))
            .error,
        isNull);
    expect(
        tester
            .widget<ExerciseCatalogList>(find.byType(ExerciseCatalogList))
            .busy,
        false);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Archived'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('exercise-status-active')))
            .onPressed,
        isNotNull);
    expect(find.textContaining('Status change was not verified'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('exercise-status-active')));
    await tester.pumpAndSettle();
    expect(catalog.changes, 2,
        reason: 'Restore callback must run exactly once');
    expect(catalog.entries.first.archived, false);
    expect(catalog.entries.first.status, TutorialStatus.draft);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Inactive'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('exercise-status-active')));
    await tester.pumpAndSettle();
    expect(catalog.entries.first.status, TutorialStatus.active);
    expect(catalog.changes, 3);
  });
  testWidgets(
      'uncertain status change locks actions until explicit Reload and hides errors',
      (tester) async {
    final catalog = CatalogStatusFixture()
      ..failure = StateError('private-credential-sentinel');
    await openStatusCatalog(tester, catalog);
    await tester.tap(find.byKey(const ValueKey('exercise-status-active')));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Status change was not verified. Reload the catalog before retrying.'),
        findsOneWidget);
    expect(find.textContaining('private-credential-sentinel'), findsNothing);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('exercise-status-active')))
            .onPressed,
        isNull);
    catalog.failure = null;
    await tester.tap(find.byTooltip('Reload catalog'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('exercise-status-active')))
            .onPressed,
        isNotNull);
  });
  testWidgets(
      'release hold hides lifecycle mutations while statuses remain readable',
      (tester) async {
    await openStatusCatalog(tester, CatalogStatusFixture(), enabled: false);
    expect(find.text('Archived row'), findsOneWidget);
    expect(find.byKey(const ValueKey('exercise-delete-active')), findsNothing);
    expect(find.byKey(const ValueKey('exercise-status-active')), findsNothing);
  });
  testWidgets('catalog actions and status filters fit 320px with double text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: CatalogStatusFixture(),
        child: MaterialApp(
            theme: AppTheme.build(),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('exercise-delete-active')), 250);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey('exercise-delete-active')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
