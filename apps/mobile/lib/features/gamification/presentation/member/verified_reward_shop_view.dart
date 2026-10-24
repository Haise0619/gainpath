import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'voucher_screen.dart';

class VerifiedRewardShopView extends StatefulWidget {
  const VerifiedRewardShopView({super.key, required this.repository});
  final VerifiedRewardsRepository repository;
  @override
  State<VerifiedRewardShopView> createState() => _VerifiedRewardShopViewState();
}

class _VerifiedRewardShopViewState extends State<VerifiedRewardShopView> {
  late Future<VerifiedRewardsSnapshot> _future;
  final _requests = <String, String>{};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.overview();
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.overview();
      _error = null;
    });
  }

  Future<void> _open(VerifiedRewardRedemption r) async {
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) =>
                VoucherScreen(redemption: r, repository: widget.repository)));
    if (mounted && widget.repository.current) _refresh();
  }

  Future<void> _redeem(VerifiedRewardItem item) async {
    if (_busy || !widget.repository.current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Retain this key after uncertain network results so retry cannot double spend.
    final request = _requests.putIfAbsent(
        item.itemId,
        () =>
            'reward_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}');
    try {
      final redemption = await widget.repository
          .redeem(itemId: item.itemId, requestId: request);
      if (!mounted || !widget.repository.current) return;
      _requests.remove(item.itemId);
      await _open(redemption);
    } catch (_) {
      if (mounted && widget.repository.current) {
        setState(() => _error =
            'Redemption could not be confirmed. Retry to check the same request, or refresh.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Redeem points'), actions: [
        IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh rewards')
      ]),
      body: FutureBuilder<VerifiedRewardsSnapshot>(
          future: _future,
          builder: (context, result) {
            if (!widget.repository.current) {
              return const Center(
                  child: Text('Rewards unavailable for this session.'));
            }
            if (result.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (result.hasError || !result.hasData) {
              return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Rewards unavailable'),
                TextButton(onPressed: _refresh, child: const Text('Retry'))
              ]));
            }
            final data = result.data!;
            return PageBody(children: [
              Panel(
                  child: Text(
                      data.balance == null
                          ? 'No verified balance yet.'
                          : '${data.balance} verified points',
                      style: Theme.of(context).textTheme.titleLarge)),
              const SizedBox(height: 12),
              if (!data.available)
                const Text('Rewards unavailable')
              else if (data.items.isEmpty)
                const Text('No rewards are configured.'),
              if (data.available && data.effectiveTier == 'free')
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        'Your points are retained. Basic or Premium membership is required to redeem physical rewards.')),
              if (data.available && data.effectiveTier == null)
                const Text(
                    'Membership eligibility is unavailable. Refresh before redeeming.'),
              if (_error != null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: AppColors.warning))),
              ...data.items.map((item) {
                final enabled = !_busy &&
                    data.canRedeem &&
                    (data.balance ?? 0) >= item.pointCost &&
                    item.stock > 0 &&
                    (!item.premiumOnly || data.effectiveTier == 'premium');
                return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(item.title,
                              style: Theme.of(context).textTheme.titleMedium),
                          Text(
                              '${item.pointCost} points · ${item.stock} available'),
                          if (item.premiumOnly) const Text('Premium exclusive'),
                          const SizedBox(height: 8),
                          FilledButton(
                              onPressed: enabled ? () => _redeem(item) : null,
                              child: Text(_busy ? 'Checking…' : 'Redeem')),
                        ])));
              }),
              const SizedBox(height: 12),
              Text('Recent reward vouchers',
                  style: Theme.of(context).textTheme.titleMedium),
              if (data.redemptions.isEmpty)
                const Text('No physical reward redemptions yet.'),
              ...data.redemptions.map((r) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.title),
                  subtitle:
                      Text(r.status == 'fulfilled' ? 'Fulfilled' : 'Issued'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _busy ? null : () => _open(r))),
            ]);
          }));
}
