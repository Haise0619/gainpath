import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/routine_templates_screen.dart';

class _Catalog extends TutorialRepository {
  @override
  List<TutorialVideo> get tutorials => [];
}

class _Routines extends RoutineTemplateRepository
    implements RoutineCoverRepository {
  final entry = RoutineBlueprint(
      id: 'r',
      name: 'Strength A',
      level: 'Beginner',
      assignedMembers: 0,
      imageUrl: 'https://example.test/original.png',
      days: [
        const RoutineDay(1, [RoutineExerciseRef('Squat', 3, 8)])
      ]);
  EquipmentImage? received;
  RoutineBlueprint? saved;
  Object? failure;
  Completer<RoutineBlueprint>? pending;
  @override
  List<RoutineBlueprint> get routineTemplates => [entry];
  @override
  Future<RoutineBlueprint> save(RoutineBlueprint b) async {
    saved = b;
    return b;
  }

  @override
  Future<RoutineBlueprint> saveWithCover(
      RoutineBlueprint b, EquipmentImage cover) async {
    received = cover;
    if (failure != null) throw failure!;
    if (pending != null) return pending!.future;
    saved = b;
    return b;
  }
}

class _Picker implements EquipmentImagePicker {
  final image = EquipmentImage(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));
  bool cancel = false;
  Object? failure;
  @override
  Future<EquipmentImage?> pick() async {
    if (failure != null) throw failure!;
    return cancel ? null : image;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester t, _Routines r, _Picker p) async {
    t.view.physicalSize = const Size(1400, 1100);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(value: _Catalog()),
          RepositoryProvider<RoutineTemplateRepository>.value(value: r),
          RepositoryProvider<EquipmentImagePicker>.value(value: p)
        ],
        child: MaterialApp(
            theme: AppTheme.build(), home: const RoutineTemplatesScreen())));
    await t.pumpAndSettle();
    await t.tap(find.text('Strength A'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byIcon(Icons.edit_outlined));
    await t.tap(find.byIcon(Icons.edit_outlined));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).first;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('local cover preview survives cancel and uploads only on save',
      (t) async {
    final r = _Routines(), p = _Picker();
    await open(t, r, p);
    expect(find.text('Cover image URL'), findsNothing);
    await tap(t, 'Replace cover image');
    expect(
        find
            .byType(Image)
            .evaluate()
            .where((e) => (e.widget as Image).image is MemoryImage),
        isNotEmpty);
    expect(r.received, isNull);
    p.cancel = true;
    await tap(t, 'Replace cover image');
    expect(find.textContaining('New cover selected'), findsOneWidget);
    await tap(t, 'Save changes');
    expect(r.received, same(p.image));
  });
  testWidgets('remove cover saves empty reference without uploading',
      (t) async {
    final r = _Routines(), p = _Picker();
    await open(t, r, p);
    await tap(t, 'Remove cover');
    await tap(t, 'Save changes');
    expect(r.received, isNull);
    expect(r.saved!.imageUrl, isEmpty);
  });
  testWidgets('failed upload preserves selection and permits retry', (t) async {
    final r = _Routines()..failure = const RoutineCoverUploadFailed(),
        p = _Picker();
    await open(t, r, p);
    await tap(t, 'Replace cover image');
    await tap(t, 'Save changes');
    expect(find.textContaining('Could not upload the cover'), findsOneWidget);
    expect(find.textContaining('New cover selected'), findsOneWidget);
    r.failure = null;
    await tap(t, 'Save changes');
    expect(r.saved, isNotNull);
  });
  testWidgets('picker error preserves saved cover and hides private details',
      (t) async {
    final r = _Routines(), p = _Picker()..failure = StateError('private-path');
    await open(t, r, p);
    await tap(t, 'Replace cover image');
    expect(find.textContaining('Could not open'), findsOneWidget);
    expect(find.textContaining('private-path'), findsNothing);
    await tap(t, 'Save changes');
    expect(r.saved!.imageUrl, r.entry.imageUrl);
  });
  testWidgets('pending cover save shows feedback and blocks duplicate actions',
      (t) async {
    final r = _Routines()..pending = Completer<RoutineBlueprint>(),
        p = _Picker();
    await open(t, r, p);
    await tap(t, 'Replace cover image');
    final save = find.widgetWithText(FilledButton, 'Save changes');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pump();
    expect(find.text('Preparing cover and saving routine…'), findsOneWidget);
    expect(
        t
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Replace cover image'))
            .onPressed,
        isNull);
    expect(
        t
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull);
    r.pending!.complete(r.entry);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
