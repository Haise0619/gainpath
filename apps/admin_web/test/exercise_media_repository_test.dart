import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart';
import 'package:gainpath_domain/workout.dart';
import 'package:gainpath_admin_web/infrastructure/firebase/firebase_exercise_catalog_repository.dart';
import 'exercise_catalog_concurrency_test.dart' show MemoryStore;

class MediaStore implements TutorialMediaStore {
  int covers = 0, videos = 0;
  void Function()? afterCover;
  bool failVideo = false;
  @override
  Future<String> uploadCover(EquipmentImage image) async {
    covers++;
    afterCover?.call();
    return 'https://media.example.test/cover.png';
  }

  @override
  Future<String> uploadVideo(EquipmentVideo video,
      {void Function(double)? onProgress}) async {
    videos++;
    onProgress?.call(.5);
    if (failVideo) throw StateError('private-file-token-sentinel');
    return 'https://media.example.test/tutorial.mp4';
  }
}

void main() {
  final cover =
      EquipmentImage(Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]));
  final video = EquipmentVideo(
      Uint8List.fromList([0, 0, 0, 12, 102, 116, 121, 112, 109, 112, 52, 50]),
      name: 'fixture.mp4');
  late MemoryStore catalog;
  late MediaStore media;
  late bool current;
  late FirebaseExerciseCatalogRepository repository;
  setUp(() {
    catalog = MemoryStore();
    media = MediaStore();
    current = true;
    repository = FirebaseExerciseCatalogRepository(
        scope: SessionScope(userId: 'admin', organizationId: 'o'),
        store: catalog,
        mediaStore: media,
        isSessionCurrent: () => current);
  });
  test('files upload once before saving URLs into the original guarded edit',
      () async {
    final entry = (await repository.load()).single;
    final progress = <double>[];
    final saved = await repository.saveWithMedia(entry,
        cover: cover, video: video, onVideoProgress: progress.add);
    expect(media.covers, 1);
    expect(media.videos, 1);
    expect(saved.thumbnailUrl, 'https://media.example.test/cover.png');
    expect(saved.videoUrl, 'https://media.example.test/tutorial.mp4');
    expect(catalog.patch, {
      'coverImageUrl': 'https://media.example.test/cover.png',
      'videoUrl': 'https://media.example.test/tutorial.mp4'
    });
    expect(progress, [.5]);
    expect(
        entry.thumbnailUrl, isEmpty); // The editor snapshot remains unchanged.
  });
  test('stale baseline rejects before uploading any bytes', () async {
    final entry = (await repository.load()).single;
    catalog.record!['exerciseName'] = 'Concurrent edit';
    await expectLater(repository.saveWithMedia(entry, cover: cover),
        throwsA(isA<TutorialEditConflict>()));
    expect(media.covers, 0);
    expect(catalog.patch, isNull);
  });
  test(
      'session loss after cover upload prevents video upload and catalog write',
      () async {
    final entry = (await repository.load()).single;
    media.afterCover = () => current = false;
    await expectLater(
        repository.saveWithMedia(entry, cover: cover, video: video),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(media.videos, 0);
    expect(catalog.patch, isNull);
  });
  test('failed video upload preserves saved references and sanitizes failure',
      () async {
    final entry = (await repository.load()).single;
    media.failVideo = true;
    await expectLater(
        repository.saveWithMedia(entry, cover: cover, video: video),
        throwsA(isA<TutorialMediaUploadFailed>()));
    expect(catalog.patch, isNull);
    expect(catalog.record!['videoUrl'], 'https://example.test/original.mp4');
  });
  test('new exercise stores generated media references without a manual URL',
      () async {
    final entry = TutorialVideo(
        title: 'Cable row', category: 'Core', status: TutorialStatus.draft);
    final saved =
        await repository.saveWithMedia(entry, cover: cover, video: video);
    expect(saved.id, 'created');
    expect(catalog.creates, 1);
    expect(catalog.record!['coverImageUrl'],
        'https://media.example.test/cover.png');
    expect(
        catalog.record!['videoUrl'], 'https://media.example.test/tutorial.mp4');
  });
  test('concurrent edit during upload fails the original baseline transaction',
      () async {
    final entry = (await repository.load()).single;
    media.afterCover =
        () => catalog.record!['exerciseName'] = 'Concurrent edit';
    await expectLater(repository.saveWithMedia(entry, cover: cover),
        throwsA(isA<TutorialEditConflict>()));
    expect(catalog.patch, isNull);
    expect(catalog.record!['exerciseName'], 'Concurrent edit');
  });
  test(
      'organization reassignment during cover upload blocks further upload/write',
      () async {
    final entry = (await repository.load()).single;
    media.afterCover = () => catalog.assignment = {'organizationId': 'other'};
    await expectLater(
        repository.saveWithMedia(entry, cover: cover, video: video),
        throwsA(isA<TutorialEditAuthorizationChanged>()));
    expect(media.videos, 0);
    expect(catalog.patch, isNull);
  });
}
