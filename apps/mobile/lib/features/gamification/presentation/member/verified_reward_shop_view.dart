import 'dart:async';
import 'points_history_screen.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../application/rewards_feature_host.dart';
import 'my_rewards_screen.dart';
import 'reward_details.dart';
import 'voucher_screen.dart';

class VerifiedRewardShopView extends StatefulWidget {
  const VerifiedRewardShopView(
      {super.key, required this.repository, this.onBalanceChanged});
  final VerifiedRewardsRepository repository;
  final Future<void> Function()? onBalanceChanged;
  @override
  State<VerifiedRewardShopView> createState() => _VerifiedRewardShopViewState();
}

class _VerifiedRewardShopViewState extends State<VerifiedRewardShopView>
    with WidgetsBindingObserver {
  late Future<VerifiedRewardsSnapshot> _future;
  final _requests = <String, String>{};
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = widget.repository.overview();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        widget.repository.current &&
        !_busy) {
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _future = widget.repository.overview();
      _error = null;
    });
  }

  Future<void> _saved() async {
    if (!widget.repository.current) return;
    await Navigator.push(
        context,
        MaterialPageRoute<void>(
            builder: (_) => MyRewardsScreen(repository: widget.repository)));
    if (mounted && widget.repository.current) _refresh();
  }

  Future<void> _review(
      VerifiedRewardItem item, bool enabled, String reason) async {
    if (_busy || !widget.repository.current) return;
    final confirmed = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
            builder: (_) => RewardsRepositoryGuard(
                repository: widget.repository,
                child: RewardDetailsScreen(
                    item: item,
                    enabled: enabled,
                    isCurrent: () => widget.repository.current,
                    disabledReason: reason))));
    if (confirmed == true && mounted && widget.repository.current) {
      await _redeem(item);
    }
  }

  Future<void> _redeem(VerifiedRewardItem item) async {
    if (_busy || !widget.repository.current) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    // Retain this key after uncertain results; the Firebase repository also persists it.
    final request = _requests.putIfAbsent(
        item.itemId,
        () =>
            'reward_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}');
    try {
      final redemption = await widget.repository.redeem(
          itemId: item.itemId,
          requestId: request,
          expectedPointCost: item.pointCost,
          expectedItemRevision: item.revision);
      if (!mounted || !widget.repository.current) return;
      _requests.remove(item.itemId);
      // Refresh the existing server-backed check-in wallet without creating earning events.
      unawaited(_balanceChanged());
      await Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => VoucherScreen(
                  redemption: redemption, repository: widget.repository)));
      if (mounted && widget.repository.current) _refresh();
    } catch (_) {
      if (mounted && widget.repository.current) {
        setState(() => _error =
            'Redemption could not be confirmed. Retry to check the same request, or refresh.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _balanceChanged() async {
    try {
      await widget.onBalanceChanged?.call();
    } catch (_) {
      // A wallet refresh failure cannot turn a confirmed voucher into a failed redemption.
    }
  }

  String _reason(VerifiedRewardsSnapshot data, VerifiedRewardItem item) {
    if (!data.canRedeem) {
      return 'Basic or Premium membership is required to redeem physical rewards.';
    }
    if (item.premiumOnly && data.effectiveTier != 'premium') {
      return 'Premium membership is required for this reward.';
    }
    if (item.stock <= 0) return 'This reward is out of stock.';
    if ((data.balance ?? 0) < item.pointCost) {
      return 'You need ${item.pointCost - (data.balance ?? 0)} more points.';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Reward shop'), actions: [
        IconButton(
            onPressed: _busy ? null : _refresh,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh rewards')
      ]),
      body: !widget.repository.current
          ? const Center(child: Text('Rewards unavailable for this session.'))
          : SafeArea(
              child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                          onPressed: _busy ? null : _saved,
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: const Text('My Rewards')))),
              Expanded(
                  child: FutureBuilder<VerifiedRewardsSnapshot>(
                      future: _future,
                      builder: (context, result) {
                        if (!widget.repository.current) {
                          return const Center(
                              child: Text(
                                  'Rewards unavailable for this session.'));
                        }
                        if (result.connectionState != ConnectionState.done) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (result.hasError || !result.hasData) {
                          return Center(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                const Text('Rewards unavailable'),
                                TextButton(
                                    onPressed: _refresh,
                                    child: const Text('Retry'))
                              ]));
                        }
                        final data = result.data!;
                        return RefreshIndicator(
                            onRefresh: () async {
                              _refresh();
                              try {
                                await _future;
                              } catch (_) {
                                // The FutureBuilder presents the unavailable state.
                              }
                            },
                            child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding:
                                    const EdgeInsets.fromLTRB(16, 4, 16, 32),
                                children: [
                                  Panel(
                                      background: AppColors.primary,
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text('YOUR POINTS',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                            const SizedBox(height: 8),
                                            InkWell(
                                                onTap: () => Navigator.push(
                                                    context,
                                                    MaterialPageRoute<void>(
                                                        builder: (_) => PointsHistoryScreen(
                                                            repository: widget
                                                                .repository))),
                                                child: Semantics(
                                                    button: true,
                                                    label:
                                                        "View points history",
                                                    child: Text(
                                                        data.balance == null
                                                            ? 'No verified balance yet.'
                                                            : '${data.balance} verified points',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineSmall
                                                            ?.copyWith(
                                                                color: Colors
                                                                    .white,
                                                                fontWeight:
                                                                    FontWeight.w800)))),
                                            const SizedBox(height: 8),
                                            const Text(
                                                'Turn your check-in points into something rewarding.',
                                                style: TextStyle(
                                                    color: Colors.white)),
                                          ])),
                                  const SizedBox(height: 20),
                                  if (!data.available)
                                    const Text('Rewards unavailable')
                                  else if (data.items.isEmpty)
                                    const Text('No rewards are configured.'),
                                  if (data.available &&
                                      data.effectiveTier == 'free')
                                    const Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: Text(
                                            'Your points are retained. Basic or Premium membership is required to redeem physical rewards.')),
                                  if (data.available &&
                                      data.effectiveTier == null)
                                    const Text(
                                        'Membership eligibility is unavailable. Refresh before redeeming.'),
                                  if (_error != null)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: Text(_error!,
                                            style: const TextStyle(
                                                color: AppColors.warning))),
                                  ...data.items.map((item) {
                                    final reason = _reason(data, item),
                                        enabled = !_busy && reason.isEmpty;
                                    return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: Panel(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              RewardCover(url: item.imageUrl),
                                              const SizedBox(height: 14),
                                              Text(item.title,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleLarge),
                                              const SizedBox(height: 6),
                                              Text(
                                                  '${item.pointCost} points · ${item.stock} available',
                                                  style: const TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w700)),
                                              if (item.validityDays != null)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        'Valid for ${item.validityDays} days')),
                                              if (item.premiumOnly)
                                                const Text('Premium exclusive'),
                                              if (reason.isNotEmpty)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 8),
                                                    child: Text(reason)),
                                              const SizedBox(height: 12),
                                              Wrap(
                                                  spacing: 12,
                                                  runSpacing: 8,
                                                  children: [
                                                    TextButton(
                                                        onPressed: _busy
                                                            ? null
                                                            : () => _review(
                                                                item,
                                                                enabled,
                                                                reason),
                                                        child: const Text(
                                                            'View details')),
                                                    FilledButton(
                                                        onPressed: enabled
                                                            ? () => _review(
                                                                item, true, '')
                                                            : null,
                                                        child: Text(_busy
                                                            ? 'Checking…'
                                                            : 'Redeem'))
                                                  ]),
                                            ])));
                                  }),
                                  const Text(
                                      'Points are spent only after server confirmation. Your vouchers are saved in My Rewards.'),
                                ]));
                      }))
            ])));
}
