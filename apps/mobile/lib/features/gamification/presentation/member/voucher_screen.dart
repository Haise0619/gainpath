import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import 'package:gainpath_domain/gamification.dart';
import 'widgets/game_media.dart';
import '../../application/rewards_feature_host.dart';
import 'reward_details.dart';

class VoucherScreen extends StatefulWidget {
  final RewardItem? item;
  final VerifiedRewardRedemption? redemption;
  final VerifiedRewardsRepository? repository;
  const VoucherScreen({super.key, this.item, this.redemption, this.repository})
      : assert(item != null || (redemption != null && repository != null));

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entrance;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.7, end: 1.05), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.05, end: 1.0), weight: 45),
    ]).animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOut));
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.redemption != null) {
      return RewardsRepositoryGuard(
          repository: widget.repository!,
          child: _VerifiedVoucherView(
              redemptionId: widget.redemption!.redemptionId,
              repository: widget.repository!));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Your voucher')),
      body: PageBody(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Panel(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: SizedBox(
                        height: 110,
                        width: double.infinity,
                        child: gameHero(widget.item!.imageUrl)),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.item!.title,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: const Text('GP-4K7M-92XA',
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3)),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.ink,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        size: 90, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text('Show this at the front desk to claim your reward.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _VerifiedVoucherView extends StatefulWidget {
  const _VerifiedVoucherView(
      {required this.redemptionId, required this.repository});
  final String redemptionId;
  final VerifiedRewardsRepository repository;
  @override
  State<_VerifiedVoucherView> createState() => _VerifiedVoucherViewState();
}

class _VerifiedVoucherViewState extends State<_VerifiedVoucherView>
    with WidgetsBindingObserver {
  VerifiedRewardRedemption? _voucher;
  bool _loading = true, _foreground = true;
  String? _error;
  Timer? _refreshTimer;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    _refreshTimer?.cancel();
    setState(() {
      _voucher = null;
      _loading = true;
      _error = null;
    });
    if (!widget.repository.current) {
      setState(() => _loading = false);
      return;
    }
    try {
      final value = await widget.repository.voucher(widget.redemptionId);
      if (!mounted ||
          generation != _generation ||
          !_foreground ||
          !widget.repository.current) {
        return;
      }
      setState(() => _voucher = value);
      _refreshTimer = Timer(const Duration(seconds: 30), _refresh);
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'Current voucher status could not be confirmed. Refresh before collection.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _refresh();
    } else {
      ++_generation;
      _refreshTimer?.cancel();
      setState(() {
        _voucher = null;
        _loading = true;
      });
    }
  }

  @override
  void dispose() {
    ++_generation;
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _voucher;
    return Scaffold(
      appBar: AppBar(title: const Text('Your reward voucher'), actions: [
        IconButton(
            tooltip: 'Refresh voucher',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded))
      ]),
      body: !widget.repository.current
          ? const Center(child: Text('Rewards unavailable for this session.'))
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : r == null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_error ?? 'Voucher unavailable.'),
                            TextButton(
                                onPressed: _refresh, child: const Text('Retry'))
                          ])))
                  : SafeArea(
                      child: PageBody(children: [
                      Panel(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            RewardCover(url: r.imageUrl),
                            const SizedBox(height: 20),
                            Text(r.title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Chip(
                                label: Text(r.statusLabel),
                                avatar: Icon(
                                    r.status == 'issued'
                                        ? Icons.confirmation_number_outlined
                                        : r.status == 'fulfilled'
                                            ? Icons.check_circle_outline
                                            : Icons.schedule,
                                    size: 18)),
                            const SizedBox(height: 8),
                            Text('${r.points} points redeemed',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            Text('Issued ${rewardDate(r.issuedAtMillis)}'),
                            const SizedBox(height: 8),
                            Text(r.expiresAtMillis == null
                                ? 'Expiry not recorded. Ask reception to verify this legacy voucher.'
                                : 'Expires ${rewardDate(r.expiresAtMillis!)}'),
                            if (r.fulfilledAtMillis != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                  'Collected ${rewardDate(r.fulfilledAtMillis!)}')
                            ],
                            const SizedBox(height: 20),
                            if (r.status == 'issued' &&
                                r.qrPayload.isNotEmpty) ...[
                              const Text('Show this QR at reception',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 12),
                              Center(
                                  child: ConstrainedBox(
                                      constraints:
                                          const BoxConstraints(maxWidth: 260),
                                      child: QrImageView(
                                          key: ValueKey(r.qrPayload),
                                          data: r.qrPayload,
                                          backgroundColor: Colors.white,
                                          padding: const EdgeInsets.all(20),
                                          semanticsLabel:
                                              'Reward collection QR. Manual reference ${r.redemptionId}',
                                          eyeStyle: const QrEyeStyle(
                                              eyeShape: QrEyeShape.square,
                                              color: Colors.black),
                                          dataModuleStyle:
                                              const QrDataModuleStyle(
                                                  dataModuleShape:
                                                      QrDataModuleShape.square,
                                                  color: Colors.black)))),
                              const SizedBox(height: 12),
                              const Text(
                                  'Staff verify the current status before confirming collection.'),
                            ],
                            if (r.status == 'fulfilled')
                              const Text(
                                  'This reward has been collected. It cannot be used again.'),
                            if (r.status == 'expired')
                              const Text(
                                  'This voucher has expired. Points remain spent. No automatic refund.'),
                            const SizedBox(height: 16),
                            const Text('Voucher reference',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                            SelectableText(r.redemptionId),
                            TextButton.icon(
                                onPressed: () async {
                                  if (!widget.repository.current) return;
                                  await Clipboard.setData(
                                      ClipboardData(text: r.redemptionId));
                                  if (context.mounted &&
                                      widget.repository.current) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Voucher reference copied')));
                                  }
                                },
                                icon: const Icon(Icons.copy_outlined),
                                label: const Text('Copy reference')),
                            const SizedBox(height: 20),
                            RewardTerms(
                                description: r.description,
                                conditions: r.conditions,
                                instructions: r.collectionInstructions),
                          ])),
                      const SizedBox(height: 16),
                      if (r.status == 'issued')
                        const Text(
                            'This issued voucher keeps its saved terms even if your membership expires. Use it before the voucher expiry.'),
                      const SizedBox(height: 16),
                      FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Done')),
                    ])),
    );
  }
}
