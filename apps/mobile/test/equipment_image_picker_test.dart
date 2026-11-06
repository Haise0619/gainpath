import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/local/equipment_image_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('real decoder accepts a selected PNG and cancellation returns null',
      () async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawColor(const ui.Color(0xff8844cc), ui.BlendMode.src);
    final picture = recorder.endRecording();
    final generated = await picture.toImage(2, 2);
    final bytes = (await generated.toByteData(format: ui.ImageByteFormat.png))!
        .buffer
        .asUint8List();
    generated.dispose();
    picture.dispose();

    final picker = LocalEquipmentImagePicker(
        selectFile: () async => XFile.fromData(bytes, name: 'bench.png'));
    final image = await picker.pick();
    expect(image, isNotNull);
    expect(image!.contentType, 'image/png');
    expect(image.bytes, bytes);

    expect(await LocalEquipmentImagePicker(selectFile: () async => null).pick(),
        isNull);
  });

  test('corrupt selected image is rejected with a sanitized validation error',
      () async {
    final picker = LocalEquipmentImagePicker(
        selectFile: () async => XFile.fromData(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
            name: 'corrupt.png'));
    await expectLater(
        picker.pick(),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'This image could not be opened. Choose another JPG, PNG or WebP.')));
  });

  test('oversized image > 5MB is rejected', () async {
    final picker = LocalEquipmentImagePicker(
        selectFile: () async => XFile.fromData(
            Uint8List(5 * 1024 * 1024 + 1),
            name: 'too_large.jpg'));
    await expectLater(
        picker.pick(),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'Choose an image no larger than 5 MB.')));
  });
}
