import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadBranchQr(Uint8List bytes) {
  final blob =
      web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  web.HTMLAnchorElement()
    ..href = url
    ..download = 'gainpath-gym-check-in.png'
    ..click();
  web.URL.revokeObjectURL(url);
}
