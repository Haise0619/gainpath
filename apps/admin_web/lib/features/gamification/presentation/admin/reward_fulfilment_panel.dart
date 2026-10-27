import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../reward_fulfilment_repository.dart';

typedef RewardScannerBuilder = Widget Function(
    BuildContext context, ValueChanged<String> onDetect);

class RewardFulfilmentPanel extends StatefulWidget {
  const RewardFulfilmentPanel(
      {super.key, required this.repository, this.scannerBuilder});
  final RewardFulfilmentRepository repository;
  final RewardScannerBuilder? scannerBuilder;
  @override
  State<RewardFulfilmentPanel> createState() => _RewardFulfilmentPanelState();
}

class _RewardFulfilmentPanelState extends State<RewardFulfilmentPanel>
    with WidgetsBindingObserver {
  final _id = TextEditingController();
  AdminRewardVoucher? _result;
  bool _busy = false, _failed = false, _scanning = false;
  int _generation = 0;
  Timer? _expiryTimer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _expiryTimer?.cancel();
    _id.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _scanning = false);
    }
  }

  @override
  void didUpdateWidget(RewardFulfilmentPanel old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository || !widget.repository.current) {
      _generation++;
      _expiryTimer?.cancel();
      _id.clear();
      _result = null;
      _busy = false;
      _failed = false;
      _scanning = false;
    }
  }

  void _detected(String raw) {
    if (!_scanning || _busy || !widget.repository.current) return;
    setState(() {
      _scanning = false;
      _id.text = raw;
    });
    unawaited(_run());
  }

  Future<void> _run({bool fulfil = false}) async {
    if (_busy || !widget.repository.current) return;
    final voucher = _result?.redemption;
    if (fulfil &&
        (voucher == null ||
            voucher.status != 'issued' ||
            _expired(voucher.expiresAtMillis))) {
      return;
    }
    // Confirm the inspected server reference, never text changed after inspection.
    final id = fulfil ? voucher!.redemptionId : _id.text.trim();
    if (id.isEmpty) return;
    final generation = ++_generation;
    _expiryTimer?.cancel();
    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
      _scanning = false;
    });
    try {
      final result = await (fulfil
          ? widget.repository.fulfil(id)
          : widget.repository.inspect(id));
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() => _result = result);
      final expiry = result.redemption.expiresAtMillis;
      if (expiry != null && !_expired(expiry)) {
        _expiryTimer = Timer(
            Duration(
                milliseconds:
                    expiry - DateTime.now().millisecondsSinceEpoch + 1), () {
          if (mounted && generation == _generation) setState(() {});
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _result = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  bool _expired(int? millis) =>
      millis != null && millis <= DateTime.now().millisecondsSinceEpoch;
  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Text('Reward fulfilment unavailable for this session.');
    }
    final result = _result, voucher = result?.redemption;
    final expired = voucher != null &&
        (voucher.status == 'expired' || _expired(voucher.expiresAtMillis));
    return SingleChildScrollView(
        child: Panel(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
          const Eyebrow('Verify issued reward'),
          const Text(
              'Scan or enter a reference to inspect its current server record, then confirm when handing over the item.'),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _scanning = !_scanning;
                          _result = null;
                        }),
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(_scanning ? 'Close camera' : 'Scan reward QR')),
            TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Close')),
          ]),
          if (_scanning)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: widget.scannerBuilder?.call(context, _detected) ??
                    RewardQrCamera(onDetect: _detected)),
          TextField(
              controller: _id,
              enabled: !_busy && !_scanning,
              decoration: const InputDecoration(
                  labelText: 'Reward voucher reference',
                  helperText:
                      'Manual entry is available when the camera cannot be used.'),
              onChanged: (_) => setState(() {
                    _result = null;
                    _failed = false;
                    _expiryTimer?.cancel();
                  })),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _busy || _scanning ? null : () => _run(),
              child: const Text('Check reward voucher')),
          if (_busy) const LinearProgressIndicator(),
          if (_failed)
            const Text(
                'Reward status could not be verified. Check again before handing over an item.'),
          if (voucher != null) ...[
            if (voucher.imageUrl.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(voucher.imageUrl,
                          height: 160,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) =>
                              const Text('Reward cover unavailable')))),
            Text(voucher.title, style: Theme.of(context).textTheme.titleMedium),
            Text('Member: ${result!.memberId} · ${voucher.points} points'),
            SelectableText('Reference: ${voucher.redemptionId}'),
            if (voucher.description.isNotEmpty) Text(voucher.description),
            const SizedBox(height: 8),
            Text(voucher.expiresAtMillis == null
                ? 'Expiry unknown for this legacy voucher. Verify the server status.'
                : 'Expires: ${DateTime.fromMillisecondsSinceEpoch(voucher.expiresAtMillis!, isUtc: true).toIso8601String()} (UTC)'),
            const Text(
                'Points remain spent if an unused reward expires. No automatic refund.'),
            if (voucher.conditions.isNotEmpty) ...[
              const Eyebrow('Conditions'),
              Text(voucher.conditions)
            ],
            if (voucher.collectionInstructions.isNotEmpty) ...[
              const Eyebrow('Collection instructions'),
              Text(voucher.collectionInstructions)
            ],
            const SizedBox(height: 12),
            if (voucher.status == 'fulfilled')
              const Text('Already fulfilled · do not issue again')
            else if (expired)
              const Text('Expired · collection unavailable')
            else if (voucher.status == 'issued') ...[
              const Text(
                  'Issued reward. Confirm collection only when the item is handed over.'),
              FilledButton(
                  onPressed: _busy ? null : () => _run(fulfil: true),
                  child: const Text('Confirm collection')),
            ],
          ],
        ])));
  }
}

/// Created only after the Admin chooses Scan. Removing this widget releases the camera.
class RewardQrCamera extends StatefulWidget {
  const RewardQrCamera({super.key, required this.onDetect});
  final ValueChanged<String> onDetect;
  @override
  State<RewardQrCamera> createState() => _RewardQrCameraState();
}

class _RewardQrCameraState extends State<RewardQrCamera> {
  final _controller = MobileScannerController(
      autoStart: false, formats: [BarcodeFormat.qrCode]);
  bool _detected = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await _controller.start();
      } catch (_) {
        if (mounted) {
          setState(() => _error =
              'Camera unavailable. Close the camera and enter the reference manually.');
        }
      }
    });
  }

  @override
  void dispose() {
    unawaited(_releaseCamera());
    super.dispose();
  }

  Future<void> _releaseCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // A platform session may already have stopped on backgrounding.
    } finally {
      try {
        await _controller.dispose();
      } catch (_) {
        // The view is closed; manual reference entry remains available.
      }
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
      height: 260,
      child: _error != null
          ? Center(child: Text(_error!))
          : MobileScanner(
              controller: _controller,
              errorBuilder: (_, error) => const Center(
                  child: Text(
                      'Camera unavailable. Enter the reference manually.')),
              onDetect: (capture) {
                if (_detected) return;
                final values = capture.barcodes
                    .map((b) => b.rawValue)
                    .whereType<String>()
                    .where((s) => s.isNotEmpty);
                if (values.isEmpty) return;
                _detected = true;
                unawaited(_controller.stop().catchError((Object _) {}));
                widget.onDetect(values.first);
              },
            ));
}
