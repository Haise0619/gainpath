import 'dart:ui' as ui;
import 'package:file_selector/file_selector.dart';
import 'package:gainpath_domain/identity.dart';

Future<CoachCertificationFile?> pickCoachCertification() async {
  final file = await openFile(acceptedTypeGroups: const [
    XTypeGroup(
        label: 'Certification evidence',
        extensions: ['pdf', 'jpg', 'jpeg', 'png'],
        mimeTypes: ['application/pdf', 'image/jpeg', 'image/png'])
  ]);
  if (file == null) return null;
  if (!['pdf', 'jpg', 'jpeg', 'png']
      .contains(file.name.split('.').last.toLowerCase())) {
    throw const FormatException('Choose a PDF, JPEG or PNG file.');
  }
  if (await file.length() > CoachCertificationFile.maxBytes) {
    throw const FormatException('Choose a file no larger than 5 MB.');
  }
  final evidence = CoachCertificationFile(await file.readAsBytes());
  if (evidence.contentType != 'application/pdf') {
    final buffer = await ui.ImmutableBuffer.fromUint8List(evidence.bytes);
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodecWithSize(buffer,
          getTargetSize: (width, height) {
        if (width <= 0 || height <= 0 || width * height > 24000000) {
          throw const FormatException(
              'Choose an image smaller than 24 megapixels.');
        }
        return ui.TargetImageSize(width: width, height: height);
      });
      final frame = await codec.getNextFrame();
      frame.image.dispose();
    } catch (_) {
      throw const FormatException(
          'Choose a valid JPEG or PNG image smaller than 24 megapixels.');
    } finally {
      codec?.dispose();
    }
  }
  return evidence;
}
