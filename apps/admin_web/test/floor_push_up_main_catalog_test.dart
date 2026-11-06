import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'exercise_catalog_concurrency_test.dart' show MemoryStore;

class FloorStore extends MemoryStore {
  FloorStore(Map<String, dynamic> fields) {
    record = fields;
    assignment = {'organizationId': 'gainpath'};
    membership = {
      'organizationId': 'gainpath',
      'role': 'admin',
      'status': 'active',
      'branchIds': <String>[]
    };
  }
  @override
  Future<Map<String, Map<String, dynamic>>> load() async => {
        'standard-floor-push-up-side-v1': record!,
      };
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  testWidgets(
      'ordinary Firebase catalog decodes floor tracking and shows it in the main editor',
      (tester) async {
    final prepared = jsonDecode(
        File('../../tools/workouts/floor-main-content.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final fields = prepared['fields'] as Map<String, dynamic>;
    final repo = FirebaseExerciseCatalogRepository(
          scope: SessionScope(userId: 'admin', organizationId: 'gainpath'),
        store: FloorStore(fields),
        isSessionCurrent: () => true);
    final entries = await repo.load();
    expect(entries.single.trackingCapability,
        ExerciseTrackingCapability.sideViewFloorPushUp);
    expect(entries.single.catalogStatus, ExerciseCatalogStatus.active);
    expect(
        FirebaseExerciseCatalogRepository.encodeCatalogFields(entries.single),
        fields);
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: repo,
        child: const MaterialApp(home: ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Standard Floor Push-Up'), findsOneWidget);
    expect(find.textContaining('AI tracking · Side view'), findsOneWidget);
    await tester.tap(find.text('Standard Floor Push-Up'));
    await tester.pumpAndSettle();
    expect(find.text(entries.single.trackingCapability.description), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
