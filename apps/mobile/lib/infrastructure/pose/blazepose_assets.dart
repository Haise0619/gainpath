import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'blazepose_contract.dart';

/// Only bundled model bytes are cached; camera frames never reach this store.
/// File-backed loading avoids the unowned calloc in tflite_flutter 0.12.1's
/// Model.fromBuffer. Hash-named assets also make model upgrades explicit.
Future<File> prepareBlazePoseAsset(BlazePoseModelContract contract,
    Directory directory, Future<Uint8List> Function() load) async {
  final bytes = await load();
  if (sha256.convert(bytes).toString() != contract.sha256) {
    throw StateError(
        'BlazePose model asset hash mismatch: ${contract.assetPath}');
  }
  await directory.create(recursive: true);
  final file = File('${directory.path}/${contract.sha256}.tflite');
  if (!await file.exists() ||
      sha256.convert(await file.readAsBytes()).toString() != contract.sha256) {
    await file.writeAsBytes(bytes, flush: true);
  }
  return file;
}
