import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gainpath_admin_web/features/content/presentation/admin/mini_game_content_screen.dart';
import 'package:gainpath_admin_web/media/video_preview.dart';

EquipmentImage _image() => EquipmentImage(base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII='));

String _mediaUrl(String kind, {String gameId = MiniGameContent.supportedId}) =>
    'https://firebasestorage.googleapis.com/v0/b/'
    'gainpath-0619.firebasestorage.app/o/'
    'orgs%2Forg%2FminiGameMedia%2F$gameId%2F$kind%2Fadmin%2F'
    '0123456789abcdef0123456789abcdef?alt=media&token=12345678-1234-1234-1234-123456789abc';

class _Repository implements MiniGameContentRepository {
  @override
  final scope = SessionScope(userId: 'admin', organizationId: 'org');
  @override
  bool current = true;
  late MiniGameContent item = MiniGameContent.defaults('org');
  int loads = 0;
  final additionalItems = <String, MiniGameContent>{};
  final saves = <({String id, int revision, MiniGameContent content})>[];
  final uploads = <({
    String id,
    String gameId,
    String kind,
    Uint8List bytes,
    String type
  })>[];
  Object? saveError;
  Object? loadError;
  Object? uploadError;
  Completer<String>? pendingUpload;
  Completer<MiniGameContent>? pendingSave;
  @override
  Future<List<MiniGameContent>> load() async {
    loads++;
    if (loadError != null) throw loadError!;
    return [item, ...additionalItems.values];
  }

  @override
  Future<MiniGameContent> save(
      {required String requestId,
      required int baseRevision,
      required MiniGameContent content}) async {
    saves.add((id: requestId, revision: baseRevision, content: content));
    if (saveError != null) throw saveError!;
    if (pendingSave != null) return pendingSave!.future;
    final saved = MiniGameContent(
        organizationId: content.organizationId,
        gameId: content.gameId,
        revision: baseRevision + 1,
        title: content.title,
        introduction: content.introduction,
        instructions: content.instructions,
        coverUrl: content.coverUrl,
        previewVideoUrl: content.previewVideoUrl,
        updatedAtMillis: 123);
    if (content.gameId == MiniGameContent.supportedId) {
      item = saved;
    } else {
      additionalItems[content.gameId] = saved;
    }
    return saved;
  }

  @override
  Future<String> upload(
      {required String gameId,
      required String kind,
      required String uploadId,
      required Uint8List bytes,
      required String contentType}) async {
    expect(MiniGameContent.supportedIds, contains(gameId));
    uploads.add((
      id: uploadId,
      gameId: gameId,
      kind: kind,
      bytes: bytes,
      type: contentType
    ));
    if (uploadError != null) throw uploadError!;
    if (pendingUpload != null) return pendingUpload!.future;
    return _mediaUrl(kind, gameId: gameId);
  }
}

class _LegacyRepository extends _Repository
    implements MiniGameContentRegistryStatus {
  @override
  bool expandedRegistryAvailable = false;
}

class _Images implements EquipmentImagePicker {
  EquipmentImage? image;
  Object? error;
  Completer<EquipmentImage?>? pending;
  @override
  Future<EquipmentImage?> pick() async {
    if (error != null) throw error!;
    return pending != null ? pending!.future : image;
  }
}

class _Videos implements EquipmentVideoPicker {
  EquipmentVideo? video;
  Object? error;
  @override
  Future<EquipmentVideo?> pick() async {
    if (error != null) throw error!;
    return video;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  final snapshot = GlobalKey();
  Future<void> open(WidgetTester tester, _Repository repository,
      {_Images? images,
      _Videos? videos,
      Size size = const Size(1200, 1400),
      bool edit = true,
      double textScale = 1,
      String gameId = MiniGameContent.supportedId}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
        theme: const bool.fromEnvironment('GAINPATH_EXPORT_ADMIN_UI')
            ? ThemeData(
                useMaterial3: true,
                fontFamily: 'GainPathUiPreview',
                colorScheme: const ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.surface,
                    onSurface: AppColors.ink))
            : AppTheme.build(),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!),
        home: RepaintBoundary(
            key: snapshot,
            child: ColoredBox(
                color: AppColors.bg,
                child: MiniGameContentScreen(
                    repository: repository,
                    imagePicker: images ?? _Images(),
                    videoPicker: videos ?? _Videos())))));
    await tester.pumpAndSettle();
    if (edit) {
      await tester.tap(find.byKey(Key('edit-$gameId')));
      await tester.pumpAndSettle();
    }
  }

  Future<void> tap(WidgetTester tester, String label) async {
    final target = label == 'Edit content'
        ? find.byKey(const Key('edit-move-catch-v1'))
        : find.text(label);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  if (const bool.fromEnvironment('GAINPATH_EXPORT_ADMIN_UI')) {
    testWidgets('export desktop mini-game visual fixtures', (tester) async {
      // Preview only: readable local font instead of Flutter test Ahem glyphs.
      // Functional runs keep the normal theme; this is not a font golden.
      final loader = FontLoader('GainPathUiPreview')
        ..addFont(Future.value(ByteData.sublistView(
            File('C:/Windows/Fonts/segoeui.ttf').readAsBytesSync())));
      await loader.load();
      final icons = FontLoader('MaterialIcons')
        ..addFont(Future.value(ByteData.sublistView(File(
                'C:/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
            .readAsBytesSync())));
      await icons.load();
      Future<void> capture(String name) async {
        final boundary = snapshot.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
              '../../build/reach-tap-admin-content-20261029/admin/$name.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await open(tester, _Repository(),
          edit: false, size: const Size(1440, 1000));
      await capture('registry-desktop');
      await tester.tap(find.byKey(const Key('edit-reach-tap-v1')));
      await tester.pumpAndSettle();
      await capture('reach-editor-desktop');
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [900.0, 1024.0, 1920.0]) {
    testWidgets('desktop registry remains usable at width $width',
        (tester) async {
      await open(tester, _Repository(), edit: false, size: Size(width, 1000));
      expect(find.byKey(const Key('edit-reach-tap-v1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'registry shows both implemented games with built-in status and edit actions',
      (tester) async {
    await open(tester, _Repository(), edit: false);
    expect(find.text('Mini-games'), findsOneWidget);
    expect(find.text('Move & Catch'), findsWidgets);
    expect(find.text('Reach & Tap'), findsWidgets);
    expect(find.byKey(const Key('mini-game-registry-table')), findsOneWidget);
    expect(find.text('Built-in guide'), findsNWidgets(2));
    expect(find.text('Edit content'), findsNWidgets(2));
    for (final label in [
      'Add game',
      'Create game',
      'Delete',
      'Settings',
      'Rewards'
    ]) {
      expect(find.text(label), findsNothing);
    }
  });

  testWidgets('desktop registry search is functional', (tester) async {
    await open(tester, _Repository(),
        edit: false, size: const Size(1920, 1080));
    expect(
        tester.getSize(find.byKey(const Key('mini-game-registry-table'))).width,
        greaterThan(1200));
    await tester.enterText(find.byKey(const Key('mini-game-search')), 'reach');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-reach-tap-v1')), findsOneWidget);
    expect(find.byKey(const Key('edit-move-catch-v1')), findsNothing);
    await tester.enterText(
        find.byKey(const Key('mini-game-search')), 'unknown');
    await tester.pumpAndSettle();
    expect(find.text('No games match these filters.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reach & Tap saves and uploads only its selected game',
      (tester) async {
    final repository = _Repository();
    final moveBefore = repository.item;
    await open(tester, repository,
        gameId: MiniGameContent.reachTapId,
        images: _Images()..image = _image());
    expect(find.text('Reach & Tap · Member introduction and how to play'),
        findsOneWidget);
    await tester.enterText(
        find.byKey(const Key('mini-game-title')), 'Reach your next target');
    await tap(tester, 'Choose cover image');
    await tap(tester, 'Save changes');
    expect(repository.saves.single.content.gameId, MiniGameContent.reachTapId);
    expect(repository.uploads.single.gameId, MiniGameContent.reachTapId);
    expect(repository.saves.single.content.coverUrl,
        _mediaUrl('cover', gameId: MiniGameContent.reachTapId));
    expect(identical(repository.item, moveBefore), isTrue);
    expect(find.text('Revision 1'), findsOneWidget);
    expect(find.text('Reach your next target'), findsOneWidget);
    expect(find.text('Reach & Tap reward points are inactive.'), findsNothing);
    expect(find.textContaining('Reach & Tap reward points are inactive.'),
        findsOneWidget);
  });

  testWidgets(
      'legacy registry shows honest built-in Reach & Tap and disables editing until reload',
      (tester) async {
    final repository = _LegacyRepository();
    await open(tester, repository, edit: false);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-reach-tap-v1')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-move-catch-v1')))
            .onPressed,
        isNotNull);
    expect(
        find.textContaining('Editing is unavailable on the connected server.'),
        findsOneWidget);
    expect(find.text('Built-in guide'), findsNWidgets(2));
    repository.expandedRegistryAvailable = true;
    await tap(tester, 'Reload');
    expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('edit-reach-tap-v1')))
            .onPressed,
        isNotNull);
  });

  testWidgets(
      'registry media filter matches saved media without changing content',
      (tester) async {
    final repository = _Repository()
      ..item = MiniGameContent.defaults('org')
          .copyWith(coverUrl: _mediaUrl('cover'));
    await open(tester, repository, edit: false);
    await tester.tap(find.byKey(const Key('mini-game-media-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('With media').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('edit-move-catch-v1')), findsOneWidget);
    expect(find.byKey(const Key('edit-reach-tap-v1')), findsNothing);
    expect(repository.saves, isEmpty);
  });

  testWidgets(
      'registry and selected editor remain usable at constrained width and large text',
      (tester) async {
    await open(tester, _Repository(),
        edit: false, size: const Size(360, 900), textScale: 2);
    expect(tester.takeException(), isNull);
    final edit = find.byKey(const Key('edit-reach-tap-v1'));
    await tester.ensureVisible(edit);
    await tester.tap(edit);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tap(tester, 'Save changes');
    expect(tester.takeException(), isNull);
  });

  testWidgets('save persists edited content and reloads the authoritative list',
      (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await tester.enterText(
        find.byKey(const Key('mini-game-title')), 'My movement game');
    await tester.enterText(
        find.byKey(const Key('mini-game-introduction')), 'A new introduction.');
    await tap(tester, 'Save changes');
    expect(repository.saves.single.content.title, 'My movement game');
    expect(repository.saves.single.content.introduction, 'A new introduction.');
    expect(repository.saves.single.revision, 0);
    expect(repository.saves.single.id, matches(RegExp(r'^[a-f0-9]{32}$')));
    expect(repository.loads, 2);
    await tap(tester, 'Edit content');
    expect(find.text('My movement game'), findsWidgets);
  });

  testWidgets('unchanged saved media are retained without uploads',
      (tester) async {
    final repository = _Repository()
      ..item = MiniGameContent.defaults('org').copyWith(
          coverUrl: _mediaUrl('cover'), previewVideoUrl: _mediaUrl('preview'));
    await open(tester, repository);
    final image = tester.widget<Image>(find.byType(Image).last);
    expect(image.fit, BoxFit.contain);
    expect((image.image as NetworkImage).webHtmlElementStrategy,
        WebHtmlElementStrategy.prefer);
    expect(
        tester
            .widget<ContentVideoPreview>(find.byType(ContentVideoPreview))
            .url,
        repository.item.previewVideoUrl);
    expect(
        tester
            .widget<ContentVideoPreview>(find.byType(ContentVideoPreview))
            .semanticsLabel,
        'Mini-game preview video');
    await tap(tester, 'Save changes');
    expect(repository.uploads, isEmpty);
    expect(repository.saves.single.content.coverUrl, _mediaUrl('cover'));
    expect(
        repository.saves.single.content.previewVideoUrl, _mediaUrl('preview'));
  });

  testWidgets('local cover and video preview upload only on save',
      (tester) async {
    final repository = _Repository();
    final images = _Images()..image = _image();
    final videos = _Videos()
      ..video = EquipmentVideo(
          Uint8List.fromList(
              [0, 0, 0, 12, 102, 116, 121, 112, 109, 112, 52, 50]),
          name: 'private.mp4');
    await open(tester, repository, images: images, videos: videos);
    await tap(tester, 'Choose cover image');
    await tap(tester, 'Choose preview video');
    expect(repository.uploads, isEmpty);
    expect(tester.widget<Image>(find.byType(Image).last).image,
        isA<MemoryImage>());
    expect(
        tester
            .widget<ContentVideoPreview>(find.byType(ContentVideoPreview))
            .bytes,
        videos.video!.bytes);
    expect(find.textContaining('private.mp4'), findsNothing);
    expect(find.textContaining('URL'), findsNothing);
    await tap(tester, 'Save changes');
    expect(repository.uploads.map((u) => u.kind), ['cover', 'preview']);
    expect(repository.uploads.map((u) => u.type), ['image/png', 'video/mp4']);
    expect(repository.saves.single.content.coverUrl, _mediaUrl('cover'));
    expect(
        repository.saves.single.content.previewVideoUrl, _mediaUrl('preview'));
  });

  testWidgets('instruction validation prevents save and keeps at least one row',
      (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    await tester.enterText(
        find.byKey(const Key('mini-game-instruction-0')), '');
    await tap(tester, 'Save changes');
    expect(find.text('Enter an instruction.'), findsOneWidget);
    expect(repository.saves, isEmpty);
    while (find.byTooltip('Remove instruction').evaluate().length > 1) {
      final remove = find.byTooltip('Remove instruction').last;
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
    }
    expect(
        tester
            .widget<IconButton>(find.byWidgetPredicate((widget) =>
                widget is IconButton && widget.tooltip == 'Remove instruction'))
            .onPressed,
        isNull);
  });

  testWidgets('invalid image and oversized preview do not upload',
      (tester) async {
    final repository = _Repository();
    final images = _Images()
      ..error = const FormatException('Choose a JPG, PNG or WebP image.');
    final data = Uint8List(20 * 1024 * 1024 + 1);
    data.setRange(4, 8, [102, 116, 121, 112]);
    final videos = _Videos()..video = EquipmentVideo(data, name: 'private.mp4');
    await open(tester, repository, images: images, videos: videos);
    await tap(tester, 'Choose cover image');
    expect(find.text('Choose a JPG, PNG or WebP image.'), findsOneWidget);
    await tap(tester, 'Choose preview video');
    expect(find.text('Choose an MP4 preview no larger than 20 MB.'),
        findsOneWidget);
    expect(find.byType(ContentVideoPreview), findsNothing);
    expect(repository.uploads, isEmpty);
  });

  testWidgets('unchanged retry keeps save ID and cached uploads',
      (tester) async {
    final repository = _Repository()..saveError = StateError('unavailable');
    final images = _Images()..image = _image();
    await open(tester, repository, images: images);
    await tap(tester, 'Choose cover image');
    await tap(tester, 'Save changes');
    expect(find.text('Retry save'), findsOneWidget);
    await tap(tester, 'Retry save');
    expect(repository.uploads, hasLength(1));
    expect(repository.saves[1].id, repository.saves[0].id);
    await tester.enterText(
        find.byKey(const Key('mini-game-title')), 'Changed after failure');
    await tap(tester, 'Retry save');
    expect(repository.saves[2].id, isNot(repository.saves[1].id));
    expect(repository.saves[2].revision, 0);
  });

  testWidgets('stale session during upload blocks save and hides editor',
      (tester) async {
    final repository = _Repository()..pendingUpload = Completer<String>();
    final images = _Images()..image = _image();
    await open(tester, repository, images: images);
    await tap(tester, 'Choose cover image');
    final save = find.text('Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Cancel'))
            .onPressed,
        isNull);
    repository.current = false;
    repository.pendingUpload!.complete(_mediaUrl('cover'));
    await tester.pumpAndSettle();
    expect(repository.saves, isEmpty);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Mini-game content unavailable for this session.'),
        findsOneWidget);
  });

  testWidgets('narrow and wide editors contain no overflow', (tester) async {
    await open(tester, _Repository(), size: const Size(360, 800));
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 1100);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('conflict disables further saves until explicit reload',
      (tester) async {
    final repository = _Repository()
      ..saveError = const MiniGameContentConflict();
    await open(tester, repository);
    await tester.enterText(
        find.byKey(const Key('mini-game-title')), 'Conflicting draft');
    await tap(tester, 'Save changes');
    expect(
        find.text(
            'This content changed elsewhere. Reload before editing again.'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Save changes'))
            .onPressed,
        isNull);
    expect(repository.saves.single.revision, 0);
    repository.item =
        MiniGameContent.defaults('org').copyWith(title: 'Authoritative title');
    await tap(tester, 'Discard edits and reload');
    expect(find.text('Authoritative title'), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
    expect(repository.loads, 2);
  });

  testWidgets('uncertain upload retries the same upload and save IDs',
      (tester) async {
    final repository = _Repository()
      ..uploadError = const MiniGameContentUploadFailed();
    await open(tester, repository, images: _Images()..image = _image());
    await tap(tester, 'Choose cover image');
    await tap(tester, 'Save changes');
    expect(repository.saves, isEmpty);
    expect(
        find.text(
            'Could not upload mini-game media. Check the file and retry.'),
        findsOneWidget);
    await tap(tester, 'Retry save');
    expect(repository.uploads[1].id, repository.uploads[0].id);
    expect(repository.uploads[0].id, matches(RegExp(r'^[a-f0-9]{32}$')));
    repository.uploadError = null;
    await tap(tester, 'Retry save');
    expect(repository.uploads[2].id, repository.uploads[0].id);
    expect(repository.saves, hasLength(1));
  });

  testWidgets(
      'successful save with failed readback preserves draft for verified retry',
      (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    repository.loadError = const MiniGameContentUnavailable();
    await tester.enterText(
        find.byKey(const Key('mini-game-title')), 'Saved draft');
    await tap(tester, 'Save changes');
    expect(find.byKey(const Key('mini-game-title')), findsOneWidget);
    expect(find.text('Retry save'), findsOneWidget);
    repository.loadError = null;
    await tap(tester, 'Retry save');
    expect(repository.saves[1].id, repository.saves[0].id);
    expect(repository.saves[1].revision, 0);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Saved draft'), findsOneWidget);
  });

  testWidgets('clear saved media writes empty fields without uploading',
      (tester) async {
    final repository = _Repository()
      ..item = MiniGameContent.defaults('org').copyWith(
          coverUrl: _mediaUrl('cover'), previewVideoUrl: _mediaUrl('preview'));
    await open(tester, repository);
    await tap(tester, 'Remove cover');
    await tap(tester, 'Remove video');
    await tap(tester, 'Save changes');
    expect(repository.saves.single.content.coverUrl, '');
    expect(repository.saves.single.content.previewVideoUrl, '');
    expect(repository.uploads, isEmpty);
  });

  testWidgets('late local picker result is discarded after session loss',
      (tester) async {
    final repository = _Repository();
    final images = _Images()..pending = Completer<EquipmentImage?>();
    await open(tester, repository, images: images);
    await tester.ensureVisible(find.text('Choose cover image'));
    await tester.tap(find.text('Choose cover image'));
    await tester.pump();
    repository.current = false;
    images.pending!.complete(_image());
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(repository.saves, isEmpty);
    expect(repository.uploads, isEmpty);
  });

  testWidgets('initial load failure has a working retry', (tester) async {
    final repository = _Repository()
      ..loadError = const MiniGameContentUnavailable();
    await open(tester, repository, edit: false);
    expect(find.text('Edit content'), findsNothing);
    repository.loadError = null;
    await tap(tester, 'Retry');
    expect(find.text('Edit content'), findsNWidgets(2));
  });

  testWidgets('session rejection immediately hides the draft', (tester) async {
    final repository = _Repository()
      ..saveError = const MiniGameContentSessionChanged();
    await open(tester, repository);
    await tap(tester, 'Save changes');
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Mini-game content unavailable for this session.'),
        findsOneWidget);
    expect(repository.loads, 1);
  });

  testWidgets('session loss while saving suppresses authoritative reload',
      (tester) async {
    final repository = _Repository()
      ..pendingSave = Completer<MiniGameContent>();
    await open(tester, repository);
    final save = find.text('Save changes');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pump();
    repository.current = false;
    repository.pendingSave!.complete(repository.item);
    await tester.pumpAndSettle();
    expect(repository.loads, 1);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Edit content'), findsNothing);
  });

  testWidgets('initial stale session never loads or exposes content',
      (tester) async {
    final repository = _Repository()..current = false;
    await open(tester, repository, edit: false);
    expect(repository.loads, 0);
    expect(find.text('Move & Catch'), findsNothing);
    expect(find.text('Edit content'), findsNothing);
  });

  testWidgets('instruction count stops at eight and title is required',
      (tester) async {
    final repository = _Repository();
    await open(tester, repository);
    while (find.byTooltip('Remove instruction').evaluate().length < 8) {
      await tap(tester, 'Add instruction');
    }
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Add instruction'))
            .onPressed,
        isNull);
    await tester.enterText(find.byKey(const Key('mini-game-title')), '');
    await tap(tester, 'Save changes');
    expect(find.text('Enter a display title.'), findsOneWidget);
    expect(repository.saves, isEmpty);
  });
}
