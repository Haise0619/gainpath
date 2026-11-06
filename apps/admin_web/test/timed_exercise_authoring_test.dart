import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'exercise_catalog_concurrency_test.dart' show MemoryStore;

class _Catalog extends TutorialRepository {
  TutorialVideo? saved;
  @override
  List<TutorialVideo> get tutorials => const [];
  @override
  bool get requiresCatalogSelection => true;
  @override
  Future<TutorialVideo> save(TutorialVideo entry) async {
    saved = entry;
    return entry;
  }
}

void main() {
  test('uncertain timed draft creation retries the same identity and request',
      () async {
    final store = MemoryStore()..record = null;
    final calls = <Map<String, Object?>>[];
    final repository = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: store,
        isSessionCurrent: () => true,
        activateTimed: (request) async {
          calls.add(request);
          if (calls.length == 1) throw StateError('response lost');
          store.record = {
            ...(request['exercise'] as Map<String, Object?>),
            'editRevision': 1
          };
          return {'exerciseId': request['exerciseId'], 'editRevision': 1};
        });
    final draft = TutorialVideo(
        title: 'Mobility',
        category: 'Core',
        status: TutorialStatus.draft,
        executionMode: ExerciseExecutionMode.videoGuidedTimed,
        defaultPrescription: const TimedPrescription(
            sets: 3, durationSeconds: 45, restSeconds: 30));
    await expectLater(
        repository.save(draft), throwsA(isA<TutorialCatalogSaveFailed>()));
    await repository.save(draft);
    expect(calls.length, 2);
    expect(calls[1], calls[0]);
  });
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'new catalog exercise offers timed targets and saves an inactive draft',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final catalog = _Catalog();
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
      value: catalog,
      child: MaterialApp(
          theme: AppTheme.build(), home: const ExerciseTutorialsScreen()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    expect(find.text('Video guided · timer completion'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Default sets'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Duration per set (seconds)'),
        findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Rest between sets (seconds)'),
        findsOneWidget);
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Title'), 'Mobility flow');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Duration per set (seconds)'), '45');
    final save = find.text('Create exercise');
    await tester.ensureVisible(save.last);
    await tester.tap(save.last);
    await tester.pumpAndSettle();
    expect(catalog.saved, isNotNull);
    expect(catalog.saved!.status, TutorialStatus.draft);
  });
}
