import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';
import '../../application/rewards_feature_host.dart';
import 'reward_details.dart';
import 'verified_reward_shop_view.dart';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/reward_goal.dart';
import 'locked_rewards_preview.dart';
import '../../../../navigation/feature_navigation.dart';

class RewardGoalCard extends StatefulWidget {
  const RewardGoalCard(
      {super.key,
      required this.repository,
      required this.scope,
      required this.store,
      required this.onShop,
      this.onViewPlans,
      this.onBalanceChanged});
  final VerifiedRewardsRepository repository;
  final SessionScope scope;
  final RewardGoalStore store;
  final FutureOr<void> Function() onShop;
  final Future<void> Function()? onViewPlans, onBalanceChanged;
  @override
  State<RewardGoalCard> createState() => _RewardGoalCardState();
}

class _RewardGoalCardState extends State<RewardGoalCard> {
  VerifiedRewardsSnapshot? _data;
  String? _selected, _error;
  bool _loading = true, _saving = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RewardGoalCard old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope ||
        !identical(old.repository, widget.repository) ||
        !identical(old.store, widget.store)) {
      _data = null;
      _selected = null;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });
    final repo = widget.repository, store = widget.store, scope = widget.scope;
    try {
      final values =
          await Future.wait<Object?>([repo.overview(), store.load(scope)]);
      if (!mounted || generation != _generation || !repo.current) return;
      setState(() {
        _data = values[0] as VerifiedRewardsSnapshot;
        _selected = values[1] as String?;
      });
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _error = 'Reward goal unavailable. Retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _choose() async {
    if (_saving || !widget.repository.current || _data?.available != true) {
      return;
    }
    final generation = _generation, repo = widget.repository;
    final items = _data!.items;
    final currentSelection = _selected;
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .72),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 8, 6),
                  child: Row(children: [
                    Expanded(
                        child: Text('Choose a reward goal',
                            style: Theme.of(context).textTheme.titleLarge)),
                    IconButton(
                      tooltip: 'Close goal selector',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                ),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: items.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      if (index == items.length) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (items.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('No published rewards available.'),
                              ),
                            if (currentSelection != null)
                              TextButton.icon(
                                onPressed: () => Navigator.pop(context, ''),
                                style: TextButton.styleFrom(
                                    foregroundColor: colors.error),
                                icon: const Icon(Icons.remove_circle_outline),
                                label: const Text('Remove goal'),
                              ),
                          ],
                        );
                      }
                      final item = items[index];
                      final selected = item.itemId == currentSelection;
                      return Material(
                        color:
                            selected ? AppColors.primaryTint : colors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                              color: selected
                                  ? colors.primary
                                  : AppColors.hairline),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          selected: selected,
                          leading: _goalImage(item, 48),
                          title: Text(item.title),
                          subtitle: Text(
                              '${item.pointCost} points · ${item.stock > 0 ? 'In stock' : 'Out of stock'}'),
                          trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.radio_button_unchecked,
                              color: selected
                                  ? colors.primary
                                  : colors.onSurfaceVariant),
                          onTap: () => Navigator.pop(context, item.itemId),
                        ),
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
    if (value == null ||
        !mounted ||
        generation != _generation ||
        !repo.current) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.store.save(widget.scope, value.isEmpty ? null : value,
          isCurrent: () =>
              mounted && generation == _generation && repo.current);
      if (mounted && generation == _generation && repo.current) {
        setState(() => _selected = value.isEmpty ? null : value);
      }
    } catch (_) {
      if (mounted && generation == _generation && repo.current) {
        setState(() => _error = 'Could not save your goal. Retry.');
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  Future<void> _shop() async {
    if (!widget.repository.current) return;
    final generation = _generation;
    await widget.onShop();
    if (mounted && generation == _generation && widget.repository.current) {
      await _load();
    }
  }

  Future<void> _plans() async {
    if (!widget.repository.current) return;
    if (widget.onViewPlans != null) {
      await widget.onViewPlans!();
    } else {
      await Navigator.pushNamed<void>(
          context, FeatureNavigation.membershipPlans);
    }
    if (mounted && widget.repository.current) await _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.repository.current) return const SizedBox.shrink();
    final matches = _data?.items.where((i) => i.itemId == _selected).toList() ??
        <VerifiedRewardItem>[];
    final item = matches.isEmpty ? null : matches.single,
        balance = _data?.balance;
    if (!_loading && _data?.effectiveTier == 'free') {
      final items = _data!.available ? _data!.items : <VerifiedRewardItem>[];
      final preview = _data!.available
          ? item ??
              items.where((i) => !i.premiumOnly).firstOrNull ??
              items.firstOrNull
          : null;
      return FreeRewardGoalPreview(
          item: preview, onViewPlans: _plans, onBrowse: _shop);
    }
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final available = _data?.available == true;
    final canChoose = available && !_saving;
    final enough = item != null && balance != null && balance >= item.pointCost;
    final inStock = item != null && item.stock > 0;
    final eligible = _data?.canRedeem == true &&
        (item?.premiumOnly != true || _data?.effectiveTier == 'premium');
    final reached = available && enough && inStock && eligible;
    final showProgress = item != null &&
        available &&
        balance != null &&
        item.pointCost > 0 &&
        balance < item.pointCost &&
        inStock &&
        eligible;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.track_changes, color: colors.primary, size: 19),
              const SizedBox(width: 6),
              Flexible(
                  child: Text('My Reward Goal',
                      style:
                          text.titleMedium?.copyWith(color: colors.onSurface))),
            ]),
            if (reached)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('Goal reached',
                      style:
                          text.bodySmall?.copyWith(color: AppColors.success)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_loading)
          const LinearProgressIndicator(semanticsLabel: 'Loading reward goal')
        else ...[
          if (item != null) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _goalImage(item, 94),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: text.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Row(children: [
                    SvgPicture.asset('assets/icons/reward_point.svg',
                        width: 17, height: 17, excludeFromSemantics: true),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text('${item.pointCost} points',
                            style: text.bodyMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700))),
                  ]),
                  if (item.stock <= 0)
                    const Text('Currently out of stock')
                  else if (!eligible)
                    Text(item.premiumOnly && _data?.effectiveTier == 'basic'
                        ? 'Premium membership required'
                        : 'Membership verification required')
                  else if (reached)
                    const Text('You have enough points'),
                  if (balance == null) const Text('Balance unavailable'),
                ],
              )),
            ]),
            if (showProgress) ...[
              const SizedBox(height: 12),
              Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text('$balance / ${item.pointCost} points'),
                    Text('${item.pointCost - balance} points to go',
                        style: text.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant)),
                  ]),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: (balance / item.pointCost).clamp(0.0, 1.0),
                semanticsLabel: 'Reward goal progress',
                backgroundColor: AppColors.primaryTint,
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ] else if (balance != null) ...[
              const SizedBox(height: 10),
              Text(
                  'Verified balance · ${MaterialLocalizations.of(context).formatDecimal(balance)} pts',
                  style:
                      text.bodySmall?.copyWith(color: colors.onSurfaceVariant)),
            ],
            const Divider(height: 20, color: AppColors.hairline),
          ] else if (available)
            Text(_selected == null
                ? 'Choose your reward goal'
                : 'Selected reward is no longer available'),
          if (_error != null)
            Text(_error!, style: TextStyle(color: colors.error)),
          if (!available && _error == null)
            const Text('Reward goal unavailable'),
          if (available)
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: canChoose ? _choose : null,
                  child: Text(_saving
                      ? 'Saving…'
                      : _selected == null
                          ? 'Browse rewards'
                          : 'Change goal'),
                ),
                if (item != null)
                  FilledButton.tonal(
                    onPressed: _saving ? null : () => _viewReward(item.itemId),
                    child: const Text('View reward'),
                  ),
              ],
            )
          else
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(onPressed: _load, child: const Text('Retry')),
            ),
        ],
      ]),
    );
  }

  Future<void> _viewReward(String id) async {
    final repo = widget.repository;
    if (!repo.current) return;
    final generation = _generation;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => RewardsRepositoryGuard(
        repository: repo,
        child: VerifiedRewardShopView(
          repository: repo,
          initialRewardId: id,
          onBalanceChanged: widget.onBalanceChanged,
        ),
      ),
    ));
    if (mounted && generation == _generation && repo.current) await _load();
  }
}

Widget _goalImage(VerifiedRewardItem item, double size) => SizedBox(
      width: size,
      child: RewardCover(
        url: item.imageUrl,
        height: size,
        fit: BoxFit.contain,
        placeholderSize: size * .38,
      ),
    );
