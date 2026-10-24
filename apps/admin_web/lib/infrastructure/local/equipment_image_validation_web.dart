import 'dart:convert';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:gainpath_domain/workout.dart';

Future<void> validateEquipmentImage(EquipmentImage image) async {
  // Match the HTML preview's decoder rather than Flutter's canvas codec.
  final element = web.HTMLImageElement()
    ..src = 'data:${image.contentType};base64,${base64Encode(image.bytes)}';
  try {
    await element.decode().toDart.timeout(const Duration(seconds: 10));
    if (element.naturalWidth == 0 || element.naturalHeight == 0) {
      throw const FormatException(
          'This image could not be opened. Choose another JPG, PNG or WebP.');
    }
    if (element.naturalWidth * element.naturalHeight > 24000000) {
      throw const FormatException(
          'Choose an image smaller than 24 megapixels.');
    }
  } finally {
    element.removeAttribute('src');
  }
}
