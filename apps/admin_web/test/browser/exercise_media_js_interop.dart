import 'dart:js_interop';
import 'dart:typed_data';
import 'package:gainpath_domain/workout.dart';

@JS('ArrayBuffer.isView')
external bool isNativeArray(JSAny? value);
@JS('Object.prototype.toString.call')
external JSString tag(JSAny? value);
@JS('console.log')
external void report(JSString message);
void main() {
  final raw = Uint8List.fromList([255, 216, 255, 1]);
  final image = EquipmentImage(raw);
  if (!isNativeArray(raw.toJS)) throw StateError('Raw bytes are not native');
  final copied = image.copyBytes();
  if (tag(copied.buffer.toJS).toDart != '[object ArrayBuffer]') {
    throw StateError('Image buffer is not native');
  }
  copied[0] = 0;
  if (image.bytes[0] != 255) {
    throw StateError('Image copy changed the selection');
  }
  final video = EquipmentVideo(
      Uint8List.fromList([0, 0, 0, 12, 102, 116, 121, 112, 109, 112, 52, 50]),
      name: 'fixture.mp4');
  if (tag(video.copyBytes().buffer.toJS).toDart != '[object ArrayBuffer]') {
    throw StateError('Video buffer is not native');
  }
  report('imageAndVideoNativeBuffers=PASS'.toJS);
  var immutable = false;
  try {
    image.bytes[0] = 0;
  } on UnsupportedError {
    immutable = true;
  }
  if (!immutable) throw StateError('Selected image bytes became mutable');
}
