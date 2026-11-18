import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../platform/branch_qr_download_stub.dart'
    if (dart.library.js_interop) '../../platform/branch_qr_download_web.dart';

class BranchVisitQrDialog extends StatefulWidget {
  const BranchVisitQrDialog(
      {super.key, required this.first, required this.refresh});
  final Map<String, dynamic> first;
  final Future<Map<String, dynamic>> Function() refresh;

  @override
  State<BranchVisitQrDialog> createState() => _BranchVisitQrDialogState();
}

class _BranchVisitQrDialogState extends State<BranchVisitQrDialog> {
  late Map<String, dynamic> _code = widget.first;
  late final Timer _timer;
  bool _busy = false;
  bool _full = false;
  String? _error;

  int get _seconds {
    final expires = _code['expiresAtMillis'];
    if (expires is! num) return 0;
    return ((expires - DateTime.now().millisecondsSinceEpoch) / 1000)
        .ceil()
        .clamp(0, 300);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.refresh();
      if (mounted) setState(() => _code = result);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not refresh the code. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _download(String data) async {
    try {
      final image =
          await QrPainter(data: data, version: QrVersions.auto, gapless: true)
              .toImageData(512);
      if (image == null) throw StateError('QR image unavailable');
      final bytes =
          image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes);
      downloadBranchQr(Uint8List.fromList(bytes));
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not download this code.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _code['qr'] as String;
    final left = _seconds;
    final minutes = left ~/ 60;
    final seconds = (left % 60).toString().padLeft(2, '0');
    final qr = left == 0
        ? const Text('Code expired. Refresh to generate a new code.')
        : SizedBox.square(
            dimension: _full
                ? (MediaQuery.sizeOf(context).width - 48)
                    .clamp(140, 440)
                    .toDouble()
                : 210,
            child: QrImageView(data: data, backgroundColor: Colors.white),
          );
    final body = Column(mainAxisSize: MainAxisSize.min, children: [
      qr,
      if (left > 0) Text('Expires in $minutes:$seconds'),
      if (_error != null) Text(_error!),
    ]);
    final actions = [
      TextButton(
          onPressed: () => Navigator.pop(context), child: const Text('Close')),
      if (kIsWeb)
        TextButton(
            onPressed: left == 0 ? null : () => _download(data),
            child: const Text('Download PNG')),
      TextButton(
          onPressed: () => setState(() => _full = !_full),
          child: Text(_full ? 'Exit fullscreen' : 'Fullscreen')),
      FilledButton(
          onPressed: _busy ? null : _refresh,
          child: Text(_busy ? 'Refreshing…' : 'Refresh QR')),
    ];
    return _full
        ? Dialog.fullscreen(
            child: SafeArea(
                child: Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Gym check-in QR'),
                  body,
                  Wrap(children: actions),
                ])),
          )))
        : AlertDialog(
            title: const Text('Gym check-in QR'),
            content: body,
            actions: actions);
  }
}
