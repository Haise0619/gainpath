@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_domain/workout.dart';

void main() {
  test('plain bytes retain browser payload length', () {
    final bytes = Uint8List.fromList([255, 216, 255, 1]);
    expect(bytes.toJS.toDart.length, 4);
  });
  test('selected image copy exposes a native browser image buffer', () {
    final image = EquipmentImage(Uint8List.fromList([255, 216, 255, 1]));
    expect(image.copyBytes().buffer.toJS.toDart.lengthInBytes, 4);
    expect(() => image.bytes[0] = 0, throwsUnsupportedError);
  });
}
