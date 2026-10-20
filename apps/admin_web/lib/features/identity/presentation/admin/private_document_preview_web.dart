// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

Widget privatePdfPreview(Uint8List bytes) => _PrivatePdf(bytes);

class _PrivatePdf extends StatefulWidget {
  const _PrivatePdf(this.bytes);
  final Uint8List bytes;
  @override
  State<_PrivatePdf> createState() => _PrivatePdfState();
}

class _PrivatePdfState extends State<_PrivatePdf> {
  late final url = html.Url.createObjectUrlFromBlob(
      html.Blob([widget.bytes], 'application/pdf'));
  @override
  void dispose() {
    html.Url.revokeObjectUrl(url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: (element) {
        final frame = element as html.IFrameElement;
        frame.src = url;
        frame.title = 'Private certification PDF';
        frame.style.border = '0';
      });
}
