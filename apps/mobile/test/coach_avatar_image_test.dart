import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/identity.dart';
import 'package:gainpath_mobile/infrastructure/firebase/firebase_coach_account_repository.dart';
import 'package:gainpath_mobile/infrastructure/local/coach_avatar_image.dart';

class PhotoAccount extends FirebaseCoachAccountRepository {
  PhotoAccount(this.bytes)
      : super(
            scope: SessionScope(userId: 'coach', organizationId: 'gym'),
            isCurrent: () => true);
  final Uint8List bytes;
  int reads = 0;
  bool active = true;
  @override
  void check() {
    if (!active) throw const CoachRepositoryException('unauthenticated');
  }

  @override
  Future<Uint8List> read(String path) async {
    reads++;
    return bytes;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('avatar decoder produces a bounded still PNG', () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff7744cc), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(512, 320);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final result = await decodeStaticCoachAvatar(png!.buffer.asUint8List());
    final codec = await ui.instantiateImageCodec(result);
    final frame = await codec.getNextFrame();
    expect(codec.frameCount, 1);
    expect(frame.image.width, 256);
    expect(frame.image.height, 160);
    frame.image.dispose();
    codec.dispose();
  });
  test('video, PDF and image-labelled junk never decode as avatars', () async {
    for (final bytes in [
      Uint8List.fromList('%PDF-1.7'.codeUnits),
      Uint8List.fromList([0, 0, 0, 20, ...'ftypmp42'.codeUnits]),
      Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
    ]) {
      await expectLater(decodeStaticCoachAvatar(bytes), throwsFormatException);
    }
  });
  test(
      'avatar loader rejects foreign, document and public URL references before reading',
      () async {
    final repo = PhotoAccount(Uint8List(0));
    expect(await repo.loadProfilePhoto(null), isNull);
    for (final path in [
      'orgs/gym/coachCertifications/coach/${'a' * 32}',
      'orgs/gym/coachProfilePhotos/other/${'a' * 32}',
      'orgs/other/coachProfilePhotos/coach/${'a' * 32}',
      'https://example.invalid/video.mp4',
    ]) {
      await expectLater(repo.loadProfilePhoto(path),
          throwsA(isA<CoachRepositoryException>()));
    }
    expect(repo.reads, 0);
    repo.active = false;
    await expectLater(
        repo.loadProfilePhoto(null), throwsA(isA<CoachRepositoryException>()));
  });
}
