import 'package:flutter/material.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../reward_fulfilment_repository.dart';

class RewardFulfilmentPanel extends StatefulWidget {
  const RewardFulfilmentPanel({super.key, required this.repository});
  final RewardFulfilmentRepository repository;
  @override
  State<RewardFulfilmentPanel> createState() => _RewardFulfilmentPanelState();
}

class _RewardFulfilmentPanelState extends State<RewardFulfilmentPanel> {
  final _id = TextEditingController();
  AdminRewardVoucher? _result;
  bool _busy = false, _failed = false;
  int _generation = 0;
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RewardFulfilmentPanel old) {
    super.didUpdateWidget(old);
    if (old.repository != widget.repository) {
      _generation++;
      _result = null;
      _busy = false;
      _failed = false;
    }
  }

  Future<void> _run({bool fulfil = false}) async {
    final id = _id.text.trim(), generation = ++_generation;
    if (_busy || !widget.repository.current) return;
    setState(() {
      _busy = true;
      _failed = false;
      _result = null;
    });
    try {
      final result = await (fulfil
          ? widget.repository.fulfil(id)
          : widget.repository.inspect(id));
      if (!mounted || generation != _generation || !widget.repository.current) {
        return;
      }
      setState(() {
        _result = result;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failed = true;
          _result = null;
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) {
      return const Text('Reward fulfilment unavailable for this session.');
    }
    final result = _result, voucher = result?.redemption;
    return Panel(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
          const Eyebrow('Verify issued reward'),
          const Text(
              'Check the current server record before handing over a reward. Screenshots are not verification.'),
          TextField(
              controller: _id,
              enabled: !_busy,
              decoration:
                  const InputDecoration(labelText: 'Reward voucher reference'),
              onChanged: (_) => setState(() {
                    _result = null;
                    _failed = false;
                  })),
          const SizedBox(height: 12),
          TextButton(
              onPressed: _busy ? null : () => _run(),
              child: const Text('Check reward voucher')),
          if (_busy) const LinearProgressIndicator(),
          if (_failed)
            const Text(
                'Reward status could not be verified. Check again before handing over an item.'),
          if (voucher != null) ...[
            Text(voucher.title, style: Theme.of(context).textTheme.titleMedium),
            Text('Member: ${result!.memberId} · ${voucher.points} points'),
            if (voucher.status == 'fulfilled')
              const Text('Already fulfilled · do not issue again')
            else ...[
              const Text(
                  'Issued reward. Record fulfilment only when the item is handed over.'),
              FilledButton(
                  onPressed: _busy ? null : () => _run(fulfil: true),
                  child: const Text('Record fulfilment')),
            ],
          ],
        ]));
  }
}
