import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_assets.dart';
import 'package:gainpath_mobile/infrastructure/pose/blazepose_contract.dart';

void main() {
  test(
      'file-backed model cache verifies asset and repairs a modified cached file',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('gainpath_model_test');
    try {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final contract = BlazePoseModelContract(
          'fixture.tflite',
          sha256.convert(bytes).toString(),
          const PoseTensorSpec('in', [1], 'float32'), const []);
      final file =
          await prepareBlazePoseAsset(contract, directory, () async => bytes);
      expect(await file.readAsBytes(), bytes);
      await file.writeAsBytes([9]);
      expect(
          await (await prepareBlazePoseAsset(
                  contract, directory, () async => bytes))
              .readAsBytes(),
          bytes);
      await expectLater(
          prepareBlazePoseAsset(contract, directory, () async => Uint8List(2)),
          throwsStateError);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
