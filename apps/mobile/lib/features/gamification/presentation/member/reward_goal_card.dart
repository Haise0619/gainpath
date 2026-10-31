import 'dart:async';
import 'package:flutter/material.dart';
import 'package:gainpath_domain/gainpath_domain.dart' show SessionScope;
import 'package:gainpath_domain/gamification.dart';
import 'package:gainpath_ui/gainpath_ui.dart';
import '../../domain/reward_goal.dart';

class RewardGoalCard extends StatefulWidget {
  const RewardGoalCard(
      {super.key,
      required this.repository,
      required this.scope,
      required this.store,
      required this.onShop});
  final VerifiedRewardsRepository repository;
  final SessionScope scope;
  final RewardGoalStore store;
  final FutureOr<void> Function() onShop;
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
    final value = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
            child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .7),
                child: ListView(shrinkWrap: true, children: [
                  const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Choose a reward goal',
                          style: TextStyle(
                              color: AppColors.ink,
                              fontSize: 20,
                              fontWeight: FontWeight.w700))),
                  for (final item in _data!.items)
                    ListTile(
                        title: Text(item.title),
                        subtitle: Text(
                            '${item.pointCost} points · ${item.stock > 0 ? 'In stock' : 'Out of stock'}'),
                        onTap: () => Navigator.pop(context, item.itemId)),
                  if (_selected != null)
                    ListTile(
                        leading: const Icon(Icons.close),
                        title: const Text('Remove goal'),
                        onTap: () => Navigator.pop(context, '')),
                  if (_data!.items.isEmpty)
                    const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No published rewards available.')),
                ]))));
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
    return Panel(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            const Text('My Reward Goal',
                style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
            TextButton(
                onPressed: () async {
                  final generation = _generation;
                  await widget.onShop();
                  if (mounted &&
                      generation == _generation &&
                      widget.repository.current) {
                    await _load();
                  }
                },
                child: const Text('Shop'))
          ]),
      if (_loading)
        const Text('Loading goal…')
      else ...[
        if (item != null) ...[
          Text(item.title,
              style: const TextStyle(
                  color: AppColors.ink, fontWeight: FontWeight.w600)),
          if (balance != null && _data?.available == true) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
                value: item.pointCost <= 0
                    ? 1
                    : (balance / item.pointCost).clamp(0.0, 1.0),
                semanticsLabel: 'Reward goal progress'),
            const SizedBox(height: 8),
            Text('$balance / ${item.pointCost} points'),
          ] else
            const Text('Balance unavailable · refresh to check progress'),
          if (item.stock <= 0) const Text('Currently out of stock'),
          const Text('No stock or price reservation',
              style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ] else
          Text(_selected == null
              ? 'Pick a reward to work towards.'
              : 'Selected reward is no longer available'),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
        if (_data?.available == true)
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                  onPressed: _saving ? null : _choose,
                  child: Text(_saving
                      ? 'Saving…'
                      : _selected == null
                          ? 'Choose goal'
                          : 'Change goal')))
        else
          Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: _load, child: const Text('Retry'))),
      ],
    ]));
  }
}
