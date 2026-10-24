import 'dart:typed_data';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/local/equipment_video_picker.dart';

void main() {
  test('video selection handles cancellation and rejects spoofed MP4',
      () async {
    expect(await LocalEquipmentVideoPicker(selectFile: () async => null).pick(),
        isNull);
    final picker = LocalEquipmentVideoPicker(
        selectFile: () async => XFile.fromData(Uint8List.fromList([1, 2, 3]),
            name: 'fake.mp4', path: 'fake.mp4'));
    await expectLater(picker.pick(), throwsFormatException);
  });
  test('selected MP4 bytes are retained for save', () async {
    final data =
        Uint8List.fromList([0, 0, 0, 20, 102, 116, 121, 112, 109, 112, 52, 50]);
    final video = await LocalEquipmentVideoPicker(
        selectFile: () async => XFile.fromData(data,
            name: 'tutorial.mp4', path: 'tutorial.mp4')).pick();
    expect(video!.name, 'tutorial.mp4');
    expect(video.bytes, data);
  });
}
