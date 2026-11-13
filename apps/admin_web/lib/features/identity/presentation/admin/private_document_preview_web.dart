import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget privatePdfPreview(Uint8List bytes) => _PrivatePdf(bytes);

class _PrivatePdf extends StatefulWidget {
  const _PrivatePdf(this.bytes);
  final Uint8List bytes;
  @override
  State<_PrivatePdf> createState() => _PrivatePdfState();
}

class _PrivatePdfState extends State<_PrivatePdf> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _createUrl();
  }

  void _createUrl() {
    try {
      final blob = web.Blob(
        [widget.bytes.toJS].toJS,
        web.BlobPropertyBag(type: 'application/pdf'),
      );
      _url = web.URL.createObjectURL(blob);
    } catch (_) {}
  }

  void _release() {
    if (_url != null) {
      try {
        web.URL.revokeObjectURL(_url!);
      } catch (_) {}
      _url = null;
    }
  }

  @override
  void dispose() {
    _release();
    super.dispose();
  }

  void _attach(Object element) {
    final frame = element as web.HTMLIFrameElement;
    if (_url != null) {
      frame.src = _url!;
    }
    frame.title = 'Private certification PDF';
    frame.style.border = '0';
    frame.style.width = '100%';
    frame.style.height = '100%';
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView.fromTagName(
      tagName: 'iframe',
      onElementCreated: _attach,
    );
  }
}
