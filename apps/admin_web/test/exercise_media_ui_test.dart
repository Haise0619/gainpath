import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/workout/presentation/admin/exercise_tutorials_screen.dart';

class _Catalog extends TutorialRepository implements TutorialMediaRepository {
  @override
  final tutorials = <TutorialVideo>[];
  @override
  bool get requiresCatalogSelection => true;
  TutorialVideo? received;
  EquipmentImage? cover;
  EquipmentVideo? video;
  void Function(double)? progress;
  Completer<TutorialVideo>? pending;
  @override
  Future<TutorialVideo> saveWithMedia(TutorialVideo entry,
      {EquipmentImage? cover,
      EquipmentVideo? video,
      void Function(double)? onVideoProgress}) async {
    received = entry;
    this.cover = cover;
    this.video = video;
    progress = onVideoProgress;
    if (pending != null) return pending!.future;
    tutorials.removeWhere((item) => item.id == entry.id);
    tutorials.add(entry);
    return entry;
  }
}

class _Images implements EquipmentImagePicker {
  int calls = 0;
  final image =
      EquipmentImage(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]));
  @override
  Future<EquipmentImage?> pick() async => calls++ == 0 ? image : null;
}

class _Videos implements EquipmentVideoPicker {
  final video = EquipmentVideo(
      Uint8List.fromList([0, 0, 0, 12, 102, 116, 121, 112, 109, 112, 52, 50]),
      name: 'private-filename.mp4');
  @override
  Future<EquipmentVideo?> pick() async => video;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  Future<void> open(WidgetTester tester, _Catalog catalog, _Images images,
      _Videos videos) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiRepositoryProvider(
        providers: [
          RepositoryProvider<TutorialRepository>.value(value: catalog),
          RepositoryProvider<EquipmentImagePicker>.value(value: images),
          RepositoryProvider<EquipmentVideoPicker>.value(value: videos),
        ],
        child: MaterialApp(
            theme: AppTheme.build(), home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add exercise'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cable row');
  }

  testWidgets(
      'saved cover and video previews survive catalog return and reopening',
      (tester) async {
    final catalog = _Catalog();
    catalog.tutorials.add(TutorialVideo(
        id: 'saved',
        title: 'Saved exercise',
        category: 'Core',
        status: TutorialStatus.active,
        thumbnailUrl: 'https://media.example.test/cover.jpg',
        videoUrl: 'https://media.example.test/tutorial.mp4'));
    tester.view.physicalSize = const Size(1200, 1300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepositoryProvider<TutorialRepository>.value(
        value: catalog,
        child: MaterialApp(
            theme: AppTheme.build(), home: const ExerciseTutorialsScreen())));
    await tester.pumpAndSettle();
    final thumbnail = tester.widget<Image>(find.byType(Image).first);
    expect((thumbnail.image as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.prefer);
    await tester.tap(find.byTooltip('Preview tutorial video'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Exercise tutorial video preview'),
        findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved exercise'));
    await tester.pumpAndSettle();
    expect(tester.widget<Image>(find.byType(Image).last).fit, BoxFit.contain,
        reason:
            'The editor must show the entire saved cover without cropping.');
    expect(find.bySemanticsLabel('Exercise tutorial video preview'),
        findsOneWidget);
    expect(find.text('Saved tutorial video'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved exercise'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Exercise tutorial video preview'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Remove video'));
    await tester.tap(find.text('Remove video'));
    await tester.pumpAndSettle();
    expect(
        find.bySemanticsLabel('Exercise tutorial video preview'), findsNothing);
    final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
    await tester.ensureVisible(cancel);
    await tester.tap(cancel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved exercise'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Exercise tutorial video preview'),
        findsOneWidget);
  });
  testWidgets(
      'local cover/video selection replaces URL entry and cancelling preserves chosen file',
      (tester) async {
    final catalog = _Catalog(), images = _Images(), videos = _Videos();
    await open(tester, catalog, images, videos);
    expect(find.text('Video URL (optional)'), findsNothing);
    expect(find.text('Cover image URL (optional)'), findsNothing);
    await tester.ensureVisible(find.text('Choose cover image'));
    await tester.tap(find.text('Choose cover image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Replace cover image'));
    await tester.pumpAndSettle();
    expect(find.textContaining('New cover selected'), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image).last).fit, BoxFit.contain,
        reason: 'Selected covers must use the same uncropped preview.');
    final preview =
        tester.widget<Image>(find.byType(Image).last).image as MemoryImage;
    // The renderer must receive an independent buffer, not the frozen selection.
    expect(identical(preview.bytes, images.image.bytes), false);
    preview.bytes[0] = preview.bytes[0];
    await tester.ensureVisible(find.text('Choose tutorial video'));
    await tester.tap(find.text('Choose tutorial video'));
    await tester.pumpAndSettle();
    expect(find.textContaining('New video selected'), findsOneWidget);
    expect(find.bySemanticsLabel('Exercise tutorial video preview'),
        findsOneWidget);
    expect(find.textContaining('private-filename'), findsNothing);
    final save = find.widgetWithText(FilledButton, 'Create exercise');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(identical(catalog.cover, images.image), true);
    expect(identical(catalog.video, videos.video), true);
    expect(catalog.received!.title, 'Cable row');
  });
  testWidgets(
      'upload progress locks save/cancel and failure preserves editor with a safe reload action',
      (tester) async {
    final catalog = _Catalog()..pending = Completer<TutorialVideo>();
    await open(tester, catalog, _Images(), _Videos());
    await tester.ensureVisible(find.text('Choose tutorial video'));
    await tester.tap(find.text('Choose tutorial video'));
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Create exercise');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    catalog.progress!(.4);
    await tester.pump();
    expect(find.text('Uploading video · 40%'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cancel'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Saving…'))
            .onPressed,
        isNull);
    catalog.pending!.completeError(const TutorialMediaUploadFailed());
    await tester.pumpAndSettle();
    expect(find.text(const TutorialMediaUploadFailed().toString()),
        findsOneWidget);
    expect(find.textContaining('New video selected'), findsOneWidget);
    expect(find.text('Discard edits and reload catalog'), findsOneWidget);
  });
}
