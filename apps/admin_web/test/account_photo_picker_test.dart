import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_admin_web/infrastructure/local/account_photo_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('real decoder accepts a selected PNG and cancellation stays empty',
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
    final picker = LocalAccountPhotoPicker(
        selectFile: () async => XFile.fromData(bytes, name: 'fixture.png'));
    final image = await picker.pick();
    expect(image!.contentType, 'image/png');
    expect(image.bytes, bytes);
    expect(await LocalAccountPhotoPicker(selectFile: () async => null).pick(),
        isNull);
  });
  test('corrupt selected image is rejected with a sanitized validation error',
      () async {
    final picker = LocalAccountPhotoPicker(
        selectFile: () async => XFile.fromData(
            Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
            name: 'private-file.png'));
    await expectLater(
        picker.pick(),
        throwsA(isA<FormatException>().having((e) => e.message, 'message',
            'This image could not be opened. Choose another JPG, PNG or WebP.')));
  });
}
