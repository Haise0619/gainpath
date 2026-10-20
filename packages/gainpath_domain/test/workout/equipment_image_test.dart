import 'dart:typed_data';
import 'package:gainpath_domain/workout.dart';
import 'package:test/test.dart';

void main() {
  test('equipment images validate bytes, type and bounded size', () {
    final bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1]);
    final image = EquipmentImage(bytes);
    expect(image.contentType, 'image/png');
    bytes[0] = 0;
    expect(image.bytes.first, 137);
    expect(() => EquipmentImage(Uint8List(0)), throwsFormatException);
    expect(() => EquipmentImage(Uint8List.fromList('not an image'.codeUnits)),
        throwsFormatException);
    expect(() => EquipmentImage(Uint8List(5 * 1024 * 1024 + 1)),
        throwsFormatException);
    expect(EquipmentImage(Uint8List.fromList([255, 216, 255, 224])).contentType,
        'image/jpeg');
    expect(
        EquipmentImage(Uint8List.fromList(
            [82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80])).contentType,
        'image/webp');
  });
}
